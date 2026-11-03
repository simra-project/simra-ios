//
//  Trip.swift
//  SimRa
//
//  Swift port of the legacy Trip and Trips model layer.
//

import Foundation
import CoreLocation
import CoreMotion
import UIKit

// MARK: - Trip Annotation Source

/// Canonical origin of an incident annotation.
///
/// The raw value remains compatible with the legacy persistence format.
enum TripAnnotationSource: String {
    case manual = "Manual"
    case automatic = "Automatic"
    case widget = "Widget"
    case shortcut = "Shortcut"
    case watch = "Watch"
    case siri = "Siri"
    case unknown = "Unknown"

    init(rawSource: String?) {
        let normalized = (rawSource ?? Self.manual.rawValue)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        switch normalized {
        case "",
             "manual",
             "button",
             "user",
             "hand":
            self = .manual

        case "automatic",
             "automatic detection",
             "ai",
             "online ai",
             "onlineai",
             "offline",
             "offline ai",
             "device",
             "device detection",
             "sensor",
             "open bike sensor",
             "openbikesensor":
            self = .automatic

        case "widget",
             "widgetkit",
             "live activity":
            self = .widget

           case "shortcut",
               "shortcuts":
              self = .shortcut

           case "watch",
               "apple watch":
              self = .watch

        case "siri":
            self = .siri

        default:
            self = .unknown
        }
    }

    var displayTitle: String? {
        switch self {
        case .manual, .unknown:
            return nil

        case .automatic:
            return NSLocalizedString(
                "Automatische Erkennung",
                comment: "Source badge for automatically detected incidents"
            )

        case .widget:
            return NSLocalizedString(
                "Widget",
                comment: "Source badge for widget or Live Activity incidents"
            )

        case .shortcut:
            return NSLocalizedString(
                "Kurzbefehle",
                comment: "Source badge for Shortcuts incidents"
            )

        case .watch:
            return NSLocalizedString(
                "Apple Watch",
                comment: "Source badge for Apple Watch incidents"
            )

        case .siri:
            return NSLocalizedString(
                "Siri",
                comment: "Source badge for Siri incidents"
            )
        }
    }

    var symbolName: String {
        switch self {
        case .manual, .unknown:
            return "hand.point.up.left.fill"

        case .automatic:
            return "brain.head.profile"

        case .widget:
            return "rectangle.on.rectangle"

        case .shortcut:
            return "command"

        case .watch:
            return "applewatch"

        case .siri:
            return "waveform"
        }
    }
}

// MARK: - Trip

@objcMembers
public final class Trip: UploaderObject, CLLocationManagerDelegate {

    // MARK: Public state

    public private(set) var identifier: Int = 0
    public private(set) var startLocation: CLLocation?
    public private(set) var lastLocation: CLLocation?
    public private(set) var lastTripMotion: TripMotion?

    /// Kept as NSMutableArray for compatibility with the legacy model layer.
    public var tripLocations: NSMutableArray = NSMutableArray()

    public private(set) var deferredSecs: Int = 0
    public private(set) var deferredMeters: Int = 0

    public var bikeTypeId: Int = 0
    public var positionId: Int = 0
    public var AIVersion: Int = 0

    public var childseat: Bool = false
    public var trailer: Bool = false

    public var statisticsAdded: Bool = false
    public var reUploaded: Bool = false

    // MARK: Private state

    private weak var appDelegate: AppDelegate?

    private var locationsFile: FileHandle?
    private var motionsFile: FileHandle?

    private var largestXMotion: TripLocation?
    private var secondLargestXMotion: TripLocation?

    private var largestYMotion: TripLocation?
    private var secondLargestYMotion: TripLocation?

    private var largestZMotion: TripLocation?
    private var secondLargestZMotion: TripLocation?

    public private(set) var recordingStartDate: Date?

    private var accumulatedLength: Double = 0

    private var locationsSinceCheckpoint = 0
    private var lastCheckpointFlushDate: Date?

    private var isRecording = false

    // Serializes access to the in-memory model.
    private let stateQueue = DispatchQueue(
        label: "de.tu-berlin.mcc.simra.trip.state",
        qos: .userInitiated
    )

    // Serializes all raw recording file access.
    private let recordingIOQueue = DispatchQueue(
        label: "de.tu-berlin.mcc.simra.trip.recording-io",
        qos: .utility
    )

    // Serializes automatic post-processing.
    private let processingQueue = DispatchQueue(
        label: "de.tu-berlin.mcc.simra.trip.processing",
        qos: .utility
    )

    // Single serial queue for Core Motion callbacks.
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "de.tu-berlin.mcc.simra.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .utility
        return queue
    }()

    // MARK: Length cache

    private var cachedLength: Int = 0
    private var cachedLengthLocationCount: Int = -1
    private var cachedLengthLastTimestamp: TimeInterval = -1

    // MARK: Accelerometer buffer

    private final class AccelerometerBuffer {
        let capacity: Int
        let step: Int

        var xa: [Double]
        var ya: [Double]
        var za: [Double]

        var xla: [Double]
        var yla: [Double]
        var zla: [Double]

        var xra: [Double]
        var yra: [Double]
        var zra: [Double]
        var cra: [Double]

        var index = 0
        var fill = 0

        init(
            capacity: Int = 30,
            step: Int = 5
        ) {
            self.capacity = max(1, capacity)
            self.step = max(1, min(step, capacity))

            xa = Array(repeating: 0, count: self.capacity)
            ya = Array(repeating: 0, count: self.capacity)
            za = Array(repeating: 0, count: self.capacity)

            xla = Array(repeating: 0, count: self.capacity)
            yla = Array(repeating: 0, count: self.capacity)
            zla = Array(repeating: 0, count: self.capacity)

            xra = Array(repeating: 0, count: self.capacity)
            yra = Array(repeating: 0, count: self.capacity)
            zra = Array(repeating: 0, count: self.capacity)
            cra = Array(repeating: 0, count: self.capacity)
        }

        func reset() {
            index = 0
            fill = 0
        }
    }

    private var accelerometerBuffer: AccelerometerBuffer?

    // MARK: Streaming CSV reader

    private final class CSVLineReader {
        private let handle: FileHandle

        private var buffer = Data()
        private var reachedEOF = false

        init(handle: FileHandle) {
            self.handle = handle
        }

        func readLine() -> String? {
            while true {
                if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[
                        buffer.startIndex..<newlineIndex
                    ]

                    buffer.removeSubrange(
                        buffer.startIndex...newlineIndex
                    )

                    var line = String(
                        decoding: lineData,
                        as: UTF8.self
                    )

                    if line.last == "\r" {
                        line.removeLast()
                    }

                    return line
                }

                if reachedEOF {
                    guard !buffer.isEmpty else {
                        return nil
                    }

                    let line = String(
                        decoding: buffer,
                        as: UTF8.self
                    )

                    buffer.removeAll(
                        keepingCapacity: false
                    )

                    return line
                }

                let chunk = handle.readData(
                    ofLength: 64 * 1024
                )

                if chunk.isEmpty {
                    reachedEOF = true
                } else {
                    buffer.append(chunk)
                }
            }
        }
    }

    // MARK: Init

    public override init() {
        let defaults = UserDefaults.standard

        let nextIdentifier =
            defaults.integer(
                forKey: "lastTripId"
            ) + 1

        Utility.saveInt(
            key: "lastTripId",
            value: nextIdentifier
        )

        identifier = nextIdentifier

        super.init()
    }

    public init(identifier: Int) {
        self.identifier = identifier

        super.init()

        tripLocations = NSMutableArray()
    }

    public convenience init?(
        fromStorage identifier: Int
    ) {
        guard let dictionary = Trip.loadFromStorage(
            identifier: identifier
        ) else {
            return nil
        }

        self.init(
            identifier: identifier
        )

        apply(
            dictionary: dictionary
        )
    }

    // MARK: Storage

    /// Loads a trip first from UserDefaults for legacy compatibility
    /// and then from the current JSON file representation.
    static func loadFromStorage(
        identifier: Int
    ) -> [String: Any]? {
        let defaults = UserDefaults.standard
        let key = "Trip-\(identifier)"

        if let dictionary = defaults.dictionary(
            forKey: key
        ) {
            return dictionary
        }

        let url = tripURL(
            forIdentifier: identifier
        )

        guard
            let data = try? Data(
                contentsOf: url
            ),
            let object = try? JSONSerialization.jsonObject(
                with: data,
                options: []
            ),
            let dictionary = object as? [String: Any]
        else {
            return nil
        }

        return dictionary
    }

    private func apply(
        dictionary: [String: Any]
    ) {
        identifier =
            Self.intValue(
                dictionary["identifier"]
            ) ?? identifier

        version =
            Self.intValue(
                dictionary["version"]
            ) ?? version

        edited =
            Self.boolValue(
                dictionary["edited"]
            ) ?? false

        uploaded =
            Self.boolValue(
                dictionary["uploaded"]
            ) ?? false

        fileHash =
            dictionary["fileHash"] as? String

        filePasswd =
            dictionary["filePasswd"] as? String

        deferredSecs =
            Self.intValue(
                dictionary["deferredSecs"]
            ) ?? 0

        deferredMeters =
            Self.intValue(
                dictionary["deferredMeters"]
            ) ?? 0

        bikeTypeId =
            Self.intValue(
                dictionary["bikeTypeId"]
            ) ?? 0

        positionId =
            Self.intValue(
                dictionary["positionId"]
            ) ?? 0

        AIVersion =
            Self.intValue(
                dictionary["AIVersion"]
            ) ?? 0

        childseat =
            Self.boolValue(
                dictionary["childseat"]
            ) ?? false

        trailer =
            Self.boolValue(
                dictionary["trailer"]
            ) ?? false

        statisticsAdded =
            Self.boolValue(
                dictionary["statisticsAdded"]
            ) ?? false

        reUploaded =
            Self.boolValue(
                dictionary["reUploaded"]
            ) ?? false

        tripLocations.removeAllObjects()

        if let locations =
            dictionary["tripLocations"] as? [[String: Any]]
        {
            for locationDictionary in locations {
                guard let location =
                    Self.tripLocation(
                        fromDictionary: locationDictionary
                    )
                else {
                    continue
                }

                tripLocations.add(
                    location
                )
            }
        }

        startLocation =
            (tripLocations.firstObject as? TripLocation)?
                .location

        lastLocation =
            (tripLocations.lastObject as? TripLocation)?
                .location

        lastTripMotion =
            (tripLocations.lastObject as? TripLocation)?
                .tripMotions.lastObject as? TripMotion

        accumulatedLength = 0
        invalidateLengthCache()

        largestXMotion = nil
        secondLargestXMotion = nil

        largestYMotion = nil
        secondLargestYMotion = nil

        largestZMotion = nil
        secondLargestZMotion = nil

        if tripAnnotationsLocked() == 0,
           let firstLocation =
               tripLocations.firstObject as? TripLocation
        {
            let placeholder =
                TripAnnotation()

            placeholder.incidentId = -5

            firstLocation.tripAnnotation =
                placeholder
        }
    }

    // MARK: Export

    public override func csvFile() -> URL? {
        csvFile(
            withHeader: true
        )
    }

    public func csvFile(
        withHeader: Bool
    ) -> URL? {
        let fileManager = FileManager.default

        let outputURL =
            fileManager.temporaryDirectory
                .appendingPathComponent(
                    "trip.csv"
                )

        try? fileManager.removeItem(
            at: outputURL
        )

        guard
            fileManager.createFile(
                atPath: outputURL.path,
                contents: nil
            ),
            let output = try? FileHandle(
                forWritingTo: outputURL
            )
        else {
            return nil
        }

        defer {
            try? output.close()
        }

        // MARK: Incident header

        if withHeader {
            let bundleVersion =
                Bundle.main.infoDictionary?[
                    "CFBundleVersion"
                ] as? String ?? "0"

            let majorVersion =
                bundleVersion
                    .split(
                        separator: ".",
                        maxSplits: 1
                    )
                    .first
                    .map(String.init)
                    ?? bundleVersion

            let incidentHeader =
                "i\(majorVersion)#\(version)#\(AIVersion)\n" +
                "key,lat,lon,ts,bike,childCheckBox,trailerCheckBox,pLoc,incident,i1,i2,i3,i4,i5,i6,i7,i8,i9,scary,desc,i10\n"

            output.write(
                Data(
                    incidentHeader.utf8
                )
            )
        }

        // MARK: Incident records

        stateQueue.sync {
            var key = 0

            for case let tripLocation as TripLocation
                in tripLocations
            {
                guard let annotation =
                    tripLocation.tripAnnotation
                else {
                    continue
                }

                let comment =
                    Self.escapeLegacyCSVComment(
                        annotation.comment ?? ""
                    )

                let line = String(
                    format:
                        "%ld,%f,%f,%.0f,%ld,%d,%d,%ld,%ld,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%@,%d\n",
                    key,
                    tripLocation.location.coordinate.latitude,
                    tripLocation.location.coordinate.longitude,
                    round(
                        tripLocation.location.timestamp
                            .timeIntervalSince1970
                        * 1000.0
                    ),
                    bikeTypeId,
                    childseat ? 1 : 0,
                    trailer ? 1 : 0,
                    positionId,
                    annotation.incidentId,
                    annotation.bus ? 1 : 0,
                    annotation.bicycle ? 1 : 0,
                    annotation.pedestrian ? 1 : 0,
                    annotation.delivery ? 1 : 0,
                    annotation.commercial ? 1 : 0,
                    annotation.motorcycle ? 1 : 0,
                    annotation.car ? 1 : 0,
                    annotation.taxi ? 1 : 0,
                    annotation.other ? 1 : 0,
                    annotation.frightening ? 1 : 0,
                    comment,
                    annotation.escooter ? 1 : 0
                )

                output.write(
                    Data(line.utf8)
                )

                key += 1
            }
        }

        output.write(
            Data(
                "\n===================\n".utf8
            )
        )

        let bundleVersion =
            Bundle.main.infoDictionary?[
                "CFBundleVersion"
            ] as? String ?? "0"

        let rawHeader =
            "i\(bundleVersion)#\(version)\n" +
            "lat,lon,X,Y,Z,timeStamp,acc,a,b,c,obsDistanceLeft1,obsDistanceLeft2,obsDistanceRight1,obsDistanceRight2,obsClosePassEvent,XL,YL,ZL,RX,RY,RZ,RC\n"

        output.write(
            Data(
                rawHeader.utf8
            )
        )

        let locationsURL =
            Self.locationsURL(
                forIdentifier: identifier
            )

        let motionsURL =
            Self.motionsURL(
                forIdentifier: identifier
            )

        guard
            let locationsHandle = try? FileHandle(
                forReadingFrom: locationsURL
            ),
            let motionsHandle = try? FileHandle(
                forReadingFrom: motionsURL
            )
        else {
            writeFallbackCSV(
                to: output
            )

            return outputURL
        }

        defer {
            try? locationsHandle.close()
            try? motionsHandle.close()
        }

        let locationReader =
            CSVLineReader(
                handle: locationsHandle
            )

        let motionReader =
            CSVLineReader(
                handle: motionsHandle
            )

        var locationLine =
            locationReader.readLine()

        var motionLine =
            motionReader.readLine()

        while
            locationLine != nil ||
            motionLine != nil
        {
            switch (
                locationLine,
                motionLine
            ) {
            case let (location?, motion?):
                let locationTime =
                    Self.csvTimestamp(
                        in: location,
                        index: 5
                    )

                let motionTime =
                    Self.csvTimestamp(
                        in: motion,
                        index: 5
                    )

                if locationTime <= motionTime {
                    output.write(
                        Data(
                            "\(location)\n".utf8
                        )
                    )

                    locationLine =
                        locationReader.readLine()
                } else {
                    output.write(
                        Data(
                            "\(motion)\n".utf8
                        )
                    )

                    motionLine =
                        motionReader.readLine()
                }

            case let (location?, nil):
                output.write(
                    Data(
                        "\(location)\n".utf8
                    )
                )

                locationLine =
                    locationReader.readLine()

            case let (nil, motion?):
                output.write(
                    Data(
                        "\(motion)\n".utf8
                    )
                )

                motionLine =
                    motionReader.readLine()

            case (nil, nil):
                break
            }
        }

        return outputURL
    }

    private func writeFallbackCSV(
        to output: FileHandle
    ) {
        stateQueue.sync {
            var locations:
                [(timestamp: Double, line: String)] = []

            locations.reserveCapacity(
                tripLocations.count
            )

            for case let tripLocation as TripLocation
                in tripLocations
            {
                let line =
                    locationString(
                        from: tripLocation,
                        gyro: tripLocation.gyro,
                        closePassInfo: tripLocation.closePassInfo
                    )
                    .trimmingCharacters(
                        in: .newlines
                    )

                let timestamp =
                    round(
                        tripLocation.location.timestamp
                            .timeIntervalSince1970
                        * 1000.0
                    )

                locations.append(
                    (
                        timestamp: timestamp,
                        line: line
                    )
                )
            }

            var motions:
                [(timestamp: Double, line: String)] = []

            for case let tripLocation as TripLocation
                in tripLocations
            {
                for case let tripMotion as TripMotion
                    in tripLocation.tripMotions
                {
                    let line =
                        motionString(
                            from: tripMotion
                        )
                        .trimmingCharacters(
                            in: .newlines
                        )

                    motions.append(
                        (
                            timestamp:
                                tripMotion.timestamp
                                * 1000.0,
                            line: line
                        )
                    )
                }
            }

            var locationIndex = 0
            var motionIndex = 0

            while
                locationIndex < locations.count ||
                motionIndex < motions.count
            {
                if motionIndex >= motions.count {
                    output.write(
                        Data(
                            "\(locations[locationIndex].line)\n".utf8
                        )
                    )

                    locationIndex += 1
                    continue
                }

                if locationIndex >= locations.count {
                    output.write(
                        Data(
                            "\(motions[motionIndex].line)\n".utf8
                        )
                    )

                    motionIndex += 1
                    continue
                }

                if
                    locations[locationIndex].timestamp
                    <= motions[motionIndex].timestamp
                {
                    output.write(
                        Data(
                            "\(locations[locationIndex].line)\n".utf8
                        )
                    )

                    locationIndex += 1
                } else {
                    output.write(
                        Data(
                            "\(motions[motionIndex].line)\n".utf8
                        )
                    )

                    motionIndex += 1
                }
            }
        }
    }

    // MARK: Save

    public override func save() {
        let dictionary =
            asDictionary()

        guard JSONSerialization.isValidJSONObject(
            dictionary
        ) else {
            print(
                "[Trip] save skipped: invalid JSON for trip \(identifier)"
            )

            return
        }

        guard
            let tripData = try? JSONSerialization.data(
                withJSONObject: dictionary,
                options: []
            )
        else {
            print(
                "[Trip] save skipped: JSON serialization failed for trip \(identifier)"
            )

            return
        }

        let infoDictionary = tripInfoDictionary()

        guard
            JSONSerialization.isValidJSONObject(
                infoDictionary
            ),
            let infoData = try? JSONSerialization.data(
                withJSONObject: infoDictionary,
                options: []
            )
        else {
            print(
                "[Trip] save skipped: TripInfo serialization failed for trip \(identifier)"
            )

            return
        }

        let tripURL =
            Self.tripURL(
                forIdentifier: identifier
            )

        let tripInfoURL =
            Self.tripInfoURL(
                forIdentifier: identifier
            )

        do {
            try tripData.write(
                to: tripURL,
                options: .atomic
            )

            try infoData.write(
                to: tripInfoURL,
                options: .atomic
            )
        } catch {
            saveRecordingCheckpoint()

            print(
                "[Trip] save failed for trip \(identifier): \(error)"
            )

            return
        }

        removeRecordingCheckpoint()

        if edited {
            removeLegacyCSVFiles()
        }

        Utility.remove(
            key: "Trip-\(identifier)"
        )

        Utility.remove(
            key: "TripInfo-\(identifier)"
        )

        updateTripsController()

        print(
            "[Trip] saved trip \(identifier)"
        )
    }

    private func updateTripsController() {
        guard let delegate = currentAppDelegate() else {
            return
        }

        let update = { [weak self, weak delegate] in
            guard
                let self,
                let delegate
            else {
                return
            }

            delegate.trips.updateTrip(
                self
            )
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(
                execute: update
            )
        }
    }

    // MARK: Trip Info

    public func tripInfo() -> TripInfo {
        stateQueue.sync {
            tripInfoLocked()
        }
    }

    private func tripInfoLocked() -> TripInfo {
        let info =
            TripInfo(
                identifier: identifier
            )

        info.version = version
        info.edited = edited
        info.uploaded = uploaded
        info.fileHash = fileHash
        info.filePasswd = filePasswd

        if
            let first = tripLocations.firstObject as? TripLocation,
            let last = tripLocations.lastObject as? TripLocation
        {
            info.duration =
                NSDateInterval(
                    start: first.location.timestamp,
                    end: last.location.timestamp
                )
        } else {
            info.duration =
                NSDateInterval(
                    start: Date(),
                    end: Date()
                )
        }

        info.length =
            lengthLocked()

        info.statisticsAdded =
            statisticsAdded

        info.reUploaded =
            reUploaded

        info.annotationsCount =
            tripAnnotationsLocked()

        info.validAnnotationsCount =
            tripValidAnnotationsLocked()

        return info
    }

    private func tripInfoDictionary()
        -> [String: Any]
    {
        stateQueue.sync {
            let info =
                tripInfoLocked()

            return [
                "identifier": info.identifier,
                "version": info.version,
                "edited": info.edited,
                "uploaded": info.uploaded,
                "fileHash": info.fileHash ?? "",
                "filePasswd": info.filePasswd ?? "",
                "length": info.length,
                "statisticsAdded":
                    info.statisticsAdded,
                "reUploaded":
                    info.reUploaded,
                "annotationsCount":
                    info.annotationsCount,
                "validAnnotationsCount":
                    info.validAnnotationsCount,
                "durationStart":
                    info.duration.startDate.timeIntervalSince1970,
                "durationEnd":
                    info.duration.endDate.timeIntervalSince1970
            ]
        }
    }

    // MARK: Dictionary / JSON

    public func asDictionary()
        -> [String: Any]
    {
        stateQueue.sync {
            asDictionaryLocked()
        }
    }

    private func asDictionaryLocked()
        -> [String: Any]
    {
        var dictionary:
            [String: Any] = [
                "identifier": identifier,
                "version": version,
                "edited": edited,
                "uploaded": uploaded,
                "deferredSecs": deferredSecs,
                "deferredMeters": deferredMeters,
                "bikeTypeId": bikeTypeId,
                "positionId": positionId,
                "AIVersion": AIVersion,
                "childseat": childseat,
                "trailer": trailer,
                "statisticsAdded": statisticsAdded,
                "reUploaded": reUploaded
            ]

        if let fileHash {
            dictionary["fileHash"] =
                fileHash
        }

        if let filePasswd {
            dictionary["filePasswd"] =
                filePasswd
        }

        var locationArray:
            [[String: Any]] = []

        locationArray.reserveCapacity(
            tripLocations.count
        )

        for case let tripLocation as TripLocation
            in tripLocations
        {
            locationArray.append(
                convertTripLocationToDictionary(
                    tripLocation
                )
            )
        }

        dictionary["tripLocations"] =
            locationArray

        return dictionary
    }

    public func asJSONData() -> Data? {
        let dictionary =
            asDictionary()

        guard JSONSerialization.isValidJSONObject(
            dictionary
        ) else {
            return nil
        }

        return try? JSONSerialization.data(
            withJSONObject: dictionary,
            options: []
        )
    }

    // MARK: Upload

    public override func uploadFile(
        _ name: String,
        withController controller: NSObject,
        error errorSelector: Selector,
        completion completionSelector: Selector
    ) {
        var saveNecessary = false

        stateQueue.sync {
            for case let location as TripLocation
                in tripLocations
            {
                guard let annotation =
                    location.tripAnnotation
                else {
                    continue
                }

                if annotation.incidentId == 0 {
                    location.tripAnnotation =
                        nil

                    saveNecessary = true
                }
            }

            if tripAnnotationsLocked() == 0,
               let firstLocation =
                    tripLocations.firstObject as? TripLocation
            {
                let annotation =
                    TripAnnotation()

                annotation.incidentId = -5

                firstLocation.tripAnnotation =
                    annotation

                saveNecessary = true
            }
        }

        if saveNecessary {
            save()
        }

        if !statisticsAdded {
            if let delegate =
                currentAppDelegate()
            {
                delegate.trips.addTripToStatistics(
                    self
                )

                stateQueue.sync {
                    statisticsAdded = true
                }

                save()
            }
        }

        super.uploadFile(
            name,
            withController: controller,
            error: errorSelector,
            completion: completionSelector
        )
    }

    public func successfullyReUploaded() {
        stateQueue.sync {
            reUploaded = true
        }
    }

    // MARK: Annotation statistics

    public func tripAnnotations() -> Int {
        stateQueue.sync {
            tripAnnotationsLocked()
        }
    }

    private func tripAnnotationsLocked() -> Int {
        var count = 0

        for case let location as TripLocation
            in tripLocations
        {
            if location.tripAnnotation != nil {
                count += 1
            }
        }

        return count
    }

    public func tripValidAnnotations() -> Int {
        stateQueue.sync {
            tripValidAnnotationsLocked()
        }
    }

    private func tripValidAnnotationsLocked() -> Int {
        var count = 0

        for case let location as TripLocation
            in tripLocations
        {
            if
                let annotation =
                    location.tripAnnotation,
                annotation.incidentId != 0
            {
                count += 1
            }
        }

        return count
    }

    public func numberOfScary() -> Int {
        stateQueue.sync {
            var count = 0

            for case let location as TripLocation
                in tripLocations
            {
                if
                    let annotation =
                        location.tripAnnotation,
                    annotation.frightening
                {
                    count += 1
                }
            }

            return count
        }
    }

    // MARK: Duration / distance

    public func duration() -> NSDateInterval? {
        stateQueue.sync {
            guard
                let first =
                    tripLocations.firstObject as? TripLocation,
                let last =
                    tripLocations.lastObject as? TripLocation
            else {
                return nil
            }

            let start =
                first.location.timestamp

            let end =
                max(
                    first.location.timestamp,
                    last.location.timestamp
                )

            return NSDateInterval(
                start: start,
                end: end
            )
        }
    }

    public func durationStartDate() -> Date? {
        duration()?.startDate
    }

    public func durationEndDate() -> Date? {
        duration()?.endDate
    }

    public func length() -> Int {
        stateQueue.sync {
            lengthLocked()
        }
    }

    private func lengthLocked() -> Int {
        let count =
            tripLocations.count

        let lastTimestamp =
            (
                tripLocations.lastObject
                    as? TripLocation
            )?
            .location.timestamp.timeIntervalSince1970
            ?? -1

        if
            cachedLengthLocationCount == count,
            cachedLengthLastTimestamp == lastTimestamp
        {
            return cachedLength
        }

        guard count >= 2 else {
            cachedLength = 0
            cachedLengthLocationCount = count
            cachedLengthLastTimestamp =
                lastTimestamp

            return 0
        }

        var total:
            CLLocationDistance = 0

        var previousLocation:
            CLLocation?

        for case let tripLocation as TripLocation
            in tripLocations
        {
            if let previousLocation {
                let distance =
                    tripLocation.location.distance(
                        from: previousLocation
                    )

                // Ignore physically implausible jumps.
                if distance.isFinite,
                   distance >= 0,
                   distance < 10_000
                {
                    total += distance
                }
            }

            previousLocation =
                tripLocation.location
        }

        let result =
            Int(
                max(
                    0,
                    total
                )
            )

        cachedLength = result
        cachedLengthLocationCount = count
        cachedLengthLastTimestamp =
            lastTimestamp

        return result
    }

    private func invalidateLengthCache() {
        cachedLength = 0
        cachedLengthLocationCount = -1
        cachedLengthLastTimestamp = -1
    }

    public func idle() -> Int {
        stateQueue.sync {
            guard tripLocations.count >= 2 else {
                return 0
            }

            var total: TimeInterval = 0

            var previousLocation:
                CLLocation?

            for case let tripLocation as TripLocation
                in tripLocations
            {
                let current =
                    tripLocation.location

                if
                    let previousLocation,
                    current.speed >= 0,
                    current.speed < (3.0 / 3.6)
                {
                    let delta =
                        current.timestamp.timeIntervalSince(
                            previousLocation.timestamp
                        )

                    if delta.isFinite,
                       delta > 0,
                       delta < 120
                    {
                        total += delta
                    }
                }

                previousLocation =
                    current
            }

            return max(
                0,
                Int(total)
            )
        }
    }

    // MARK: GPX

    public func gpxFile() -> URL? {
        let fileURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "trip.gpx"
                )

        try? FileManager.default.removeItem(
            at: fileURL
        )

        guard
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: nil
            ),
            let handle = try? FileHandle(
                forWritingTo: fileURL
            )
        else {
            return nil
        }

        defer {
            try? handle.close()
        }

        handle.write(
            Data(
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <gpx version="1.1"
                     creator="SimRa iOS"
                     xmlns="http://www.topografix.com/GPX/1/1">
                <trk>
                <name>SimRa</name>
                <trkseg>
                """.utf8
            )
        )

        stateQueue.sync {
            for case let tripLocation as TripLocation
                in tripLocations
            {
                let coordinate =
                    tripLocation.location.coordinate

                let timestamp =
                    ISO8601DateFormatter().string(
                        from:
                            tripLocation.location.timestamp
                    )

                let line = String(
                    format:
                        "<trkpt lat=\"%.8f\" lon=\"%.8f\"><time>%@</time></trkpt>\n",
                    coordinate.latitude,
                    coordinate.longitude,
                    timestamp
                )

                handle.write(
                    Data(
                        line.utf8
                    )
                )
            }
        }

        handle.write(
            Data(
                """
                </trkseg>
                </trk>
                </gpx>
                """.utf8
            )
        )

        return fileURL
    }

    // MARK: GeoJSON

    public func geoJSONFile() -> URL? {
        let fileURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "trip.geojson"
                )

        try? FileManager.default.removeItem(
            at: fileURL
        )

        guard
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: nil
            ),
            let handle = try? FileHandle(
                forWritingTo: fileURL
            )
        else {
            return nil
        }

        defer {
            try? handle.close()
        }

        handle.write(
            Data(
                "{\"type\":\"LineString\",\"coordinates\":["
                    .utf8
            )
        )

        stateQueue.sync {
            var firstCoordinate = true

            for case let tripLocation as TripLocation
                in tripLocations
            {
                let coordinate =
                    tripLocation.location.coordinate

                let prefix =
                    firstCoordinate ? "" : ","

                firstCoordinate = false

                let line = String(
                    format:
                        "%@[%0.8f,%0.8f]",
                    prefix,
                    coordinate.longitude,
                    coordinate.latitude
                )

                handle.write(
                    Data(
                        line.utf8
                    )
                )
            }
        }

        handle.write(
            Data(
                "]}\n".utf8
            )
        )

        return fileURL
    }

    // MARK: KML

    public func kmlFile() -> URL? {
        let fileURL =
            FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "trip.kml"
                )

        try? FileManager.default.removeItem(
            at: fileURL
        )

        guard
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: nil
            ),
            let handle = try? FileHandle(
                forWritingTo: fileURL
            )
        else {
            return nil
        }

        defer {
            try? handle.close()
        }

        handle.write(
            Data(
                """
                <?xml version="1.0" encoding="UTF-8"?>
                <kml xmlns="http://www.opengis.net/kml/2.2">
                <Document>
                <Placemark id="SimRa">
                <name>SimRa</name>
                <LineString id="SimRa">
                <tessellate>1</tessellate>
                <coordinates>
                """.utf8
            )
        )

        stateQueue.sync {
            for case let tripLocation as TripLocation
                in tripLocations
            {
                let coordinate =
                    tripLocation.location.coordinate

                let line = String(
                    format:
                        "%.8f,%.8f\n",
                    coordinate.longitude,
                    coordinate.latitude
                )

                handle.write(
                    Data(
                        line.utf8
                    )
                )
            }
        }

        handle.write(
            Data(
                """
                </coordinates>
                </LineString>
                </Placemark>
                </Document>
                </kml>
                """.utf8
            )
        )

        return fileURL
    }

    // MARK: Recording

    public func startRecording() {
        let delegate =
            AppDelegate.shared()

        appDelegate =
            delegate

        // Prevent accidental duplicate starts.
        stateQueue.sync {
            guard !isRecording else {
                return
            }

            isRecording = true

            deferredSecs =
                delegate.defaults.integer(
                    forKey: "deferredSecs"
                )

            deferredMeters =
                delegate.defaults.integer(
                    forKey: "deferredMeters"
                )

            bikeTypeId =
                delegate.defaults.integer(
                    forKey: "bikeTypeId"
                )

            positionId =
                delegate.defaults.integer(
                    forKey: "positionId"
                )

            childseat =
                delegate.defaults.bool(
                    forKey: "childSeat"
                )

            trailer =
                delegate.defaults.bool(
                    forKey: "trailer"
                )

            recordingStartDate =
                Date()

            accumulatedLength = 0

            invalidateLengthCache()

            locationsSinceCheckpoint = 0

            lastCheckpointFlushDate =
                Date()

            largestXMotion = nil
            secondLargestXMotion = nil

            largestYMotion = nil
            secondLargestYMotion = nil

            largestZMotion = nil
            secondLargestZMotion = nil

            startLocation = nil
            lastLocation = nil
            lastTripMotion = nil

            accelerometerBuffer = nil
        }

        let fileManager =
            FileManager.default

        let locationsURL =
            Self.locationsURL(
                forIdentifier: identifier
            )

        let motionsURL =
            Self.motionsURL(
                forIdentifier: identifier
            )

        let filesOpened =
            recordingIOQueue.sync { () -> Bool in
                try? fileManager.removeItem(
                    at: locationsURL
                )

                try? fileManager.removeItem(
                    at: motionsURL
                )

                guard
                    fileManager.createFile(
                        atPath: locationsURL.path,
                        contents: nil
                    ),
                    fileManager.createFile(
                        atPath: motionsURL.path,
                        contents: nil
                    )
                else {
                    return false
                }

                guard
                    let locationFile =
                        try? FileHandle(
                            forWritingTo: locationsURL
                        ),
                    let motionFile =
                        try? FileHandle(
                            forWritingTo: motionsURL
                        )
                else {
                    return false
                }

                locationsFile =
                    locationFile

                motionsFile =
                    motionFile

                return true
            }

        guard filesOpened else {
            stateQueue.sync {
                isRecording = false
            }

            print(
                "[Trip] Could not open recording files for trip \(identifier)"
            )

            return
        }

        saveRecordingCheckpoint()

        startSensorsAndLocationUpdates()
    }

    private func startSensorsAndLocationUpdates() {
        guard isCurrentlyRecording() else {
            return
        }

        let delegate =
            appDelegate ?? AppDelegate.shared()

        appDelegate =
            delegate

        if delegate.mm.isGyroAvailable {
            delegate.mm.startGyroUpdates()
        }

        delegate.lm.delegate =
            self

        configureLocationManagerIfAuthorized()

        if accelerometerBuffer == nil {
            accelerometerBuffer =
                AccelerometerBuffer()
        }

        if delegate.mm.isDeviceMotionAvailable {
            startDeviceMotion(
                using: delegate.mm
            )
        } else if delegate.mm.isAccelerometerAvailable {
            startAccelerometer(
                using: delegate.mm
            )
        }
    }

    private func configureLocationManagerIfAuthorized() {
        guard
            let delegate = appDelegate,
            isCurrentlyRecording()
        else {
            return
        }

        let status =
            delegate.lm.authorizationStatus

        switch status {
        case .notDetermined:
            delegate.lm.requestWhenInUseAuthorization()

        case .authorizedAlways,
             .authorizedWhenInUse:

            delegate.lm.allowsBackgroundLocationUpdates = true
            delegate.lm.pausesLocationUpdatesAutomatically = false
            delegate.lm.desiredAccuracy =
                kCLLocationAccuracyNearestTenMeters
            delegate.lm.distanceFilter = 10
            delegate.lm.activityType =
                .fitness

            delegate.lm.startUpdatingLocation()

        case .denied,
             .restricted:

            print(
                "[Trip] Location authorization denied/restricted"
            )

        @unknown default:
            print(
                "[Trip] Unknown location authorization status"
            )
        }
    }

    private func startDeviceMotion(
        using motionManager: CMMotionManager
    ) {
        guard
            isCurrentlyRecording(),
            motionManager.isDeviceMotionAvailable
        else {
            return
        }

        if accelerometerBuffer == nil {
            accelerometerBuffer =
                AccelerometerBuffer()
        }

        motionManager.deviceMotionUpdateInterval =
            1.0 / 50.0

        motionManager.startDeviceMotionUpdates(
            to: motionQueue
        ) { [weak self] deviceMotion, _ in
            guard
                let self,
                let deviceMotion,
                self.isCurrentlyRecording()
            else {
                return
            }

            guard let buffer =
                self.accelerometerBuffer
            else {
                return
            }

            let acceleration =
                self.appDelegate?
                    .mm
                    .accelerometerData?
                    .acceleration

            buffer.xa[buffer.index] =
                acceleration?.x
                ?? (
                    deviceMotion.userAcceleration.x
                    + deviceMotion.gravity.x
                )

            buffer.ya[buffer.index] =
                acceleration?.y
                ?? (
                    deviceMotion.userAcceleration.y
                    + deviceMotion.gravity.y
                )

            buffer.za[buffer.index] =
                acceleration?.z
                ?? (
                    deviceMotion.userAcceleration.z
                    + deviceMotion.gravity.z
                )

            buffer.xla[buffer.index] =
                deviceMotion.userAcceleration.x

            buffer.yla[buffer.index] =
                deviceMotion.userAcceleration.y

            buffer.zla[buffer.index] =
                deviceMotion.userAcceleration.z

            buffer.xra[buffer.index] =
                deviceMotion.attitude.quaternion.x

            buffer.yra[buffer.index] =
                deviceMotion.attitude.quaternion.y

            buffer.zra[buffer.index] =
                deviceMotion.attitude.quaternion.z

            buffer.cra[buffer.index] =
                deviceMotion.attitude.quaternion.w

            buffer.index =
                (buffer.index + 1) % buffer.capacity

            buffer.fill += 1

            guard buffer.fill >= buffer.capacity else {
                return
            }

            var x = 0.0
            var y = 0.0
            var z = 0.0

            var xl = 0.0
            var yl = 0.0
            var zl = 0.0

            var xr = 0.0
            var yr = 0.0
            var zr = 0.0
            var cr = 0.0

            for index in 0..<buffer.capacity {
                x += buffer.xa[index]
                y += buffer.ya[index]
                z += buffer.za[index]

                xl += buffer.xla[index]
                yl += buffer.yla[index]
                zl += buffer.zla[index]

                xr += buffer.xra[index]
                yr += buffer.yra[index]
                zr += buffer.zra[index]
                cr += buffer.cra[index]
            }

            let count =
                Double(buffer.capacity)

            self.addAcceleration(
                x: x / count,
                y: y / count,
                z: z / count,
                xl: xl / count,
                yl: yl / count,
                zl: zl / count,
                xr: xr / count,
                yr: yr / count,
                zr: zr / count,
                cr: cr / count
            )

            buffer.fill =
                buffer.capacity - buffer.step
        }
    }

    private func startAccelerometer(
        using motionManager: CMMotionManager
    ) {
        guard
            isCurrentlyRecording(),
            motionManager.isAccelerometerAvailable
        else {
            return
        }

        if accelerometerBuffer == nil {
            accelerometerBuffer =
                AccelerometerBuffer()
        }

        motionManager.accelerometerUpdateInterval =
            1.0 / 50.0

        motionManager.startAccelerometerUpdates(
            to: motionQueue
        ) { [weak self] accelerometerData, _ in
            guard
                let self,
                let accelerometerData,
                self.isCurrentlyRecording()
            else {
                return
            }

            guard let buffer =
                self.accelerometerBuffer
            else {
                return
            }

            buffer.xa[buffer.index] =
                accelerometerData.acceleration.x

            buffer.ya[buffer.index] =
                accelerometerData.acceleration.y

            buffer.za[buffer.index] =
                accelerometerData.acceleration.z

            buffer.index =
                (buffer.index + 1) % buffer.capacity

            buffer.fill += 1

            guard buffer.fill >= buffer.capacity else {
                return
            }

            var x = 0.0
            var y = 0.0
            var z = 0.0

            for index in 0..<buffer.capacity {
                x += buffer.xa[index]
                y += buffer.ya[index]
                z += buffer.za[index]
            }

            let count =
                Double(buffer.capacity)

            self.addAcceleration(
                x: x / count,
                y: y / count,
                z: z / count,
                xl: 0,
                yl: 0,
                zl: 0,
                xr: 0,
                yr: 0,
                zr: 0,
                cr: 0
            )

            buffer.fill =
                buffer.capacity - buffer.step
        }
    }

    public func stopRecording() {
        let delegate =
            appDelegate ?? AppDelegate.shared()

        // First invalidate recording state.
        stateQueue.sync {
            guard isRecording else {
                return
            }

            isRecording = false
        }

        // Stop producing new samples.
        delegate.lm.stopUpdatingLocation()
        delegate.lm.delegate = nil

        if delegate.mm.isGyroActive {
            delegate.mm.stopGyroUpdates()
        }

        if delegate.mm.isAccelerometerActive {
            delegate.mm.stopAccelerometerUpdates()
        }

        if delegate.mm.isDeviceMotionActive {
            delegate.mm.stopDeviceMotionUpdates()
        }

        // Let already queued motion callbacks finish,
        // then clear the buffer on the same queue.
        motionQueue.cancelAllOperations()
        motionQueue.waitUntilAllOperationsAreFinished()
        accelerometerBuffer = nil

        // All file operations are serialized and fully flushed
        // before handles are closed.
        recordingIOQueue.sync {
            try? locationsFile?.synchronize()
            try? motionsFile?.synchronize()

            try? locationsFile?.close()
            try? motionsFile?.close()

            locationsFile = nil
            motionsFile = nil
        }

        // Persist the raw trip immediately.
        save()

        stateQueue.sync {
            locationsSinceCheckpoint = 0
            lastCheckpointFlushDate = nil
        }

        // Post-processing is deliberately decoupled from persistence.
        let tripReference =
            self

        let useAI =
            delegate.defaults.bool(
                forKey: "AI"
            )

        processingQueue.async { [weak tripReference] in
            guard let trip =
                tripReference
            else {
                return
            }

            if useAI {
                trip.AIIncidentDetection()
            } else {
                trip.offlineIncidentDectection()
            }

            trip.save()
        }
    }

    private func isCurrentlyRecording()
        -> Bool
    {
        stateQueue.sync {
            isRecording
        }
    }

    // MARK: CLLocationManagerDelegate

    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard isCurrentlyRecording() else {
            return
        }

        let gyroData =
            appDelegate?.mm.gyroData

        for location in locations {
            addLocation(
                location,
                withGyroData: gyroData
            )
        }
    }

    public func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        guard isCurrentlyRecording() else {
            return
        }

        configureLocationManagerIfAuthorized()
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        guard isCurrentlyRecording() else {
            return
        }

        configureLocationManagerIfAuthorized()
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        print(
            "[Trip] CLLocationManager error: \(error.localizedDescription)"
        )
    }

    // MARK: Close Pass

    public func storeClosePassValueForTripWithLeftSensorVal(
        _ leftSensorVal: NSNumber,
        rightSensorVal: NSNumber,
        leftSensor1Val: NSNumber,
        leftSensor2Val: NSNumber,
        rightSensor1Val: NSNumber,
        rightSensor2Val: NSNumber
    ) {
        var didStore =
            false

        stateQueue.sync {
            guard
                let tripLocation =
                    tripLocations.lastObject as? TripLocation
            else {
                return
            }

            let closePass =
                ClosePassInfo()

            let validLeft =
                checkIncidentMinimumDistance(
                    leftSensorVal
                )

            let validRight =
                checkIncidentMinimumDistance(
                    rightSensorVal
                )

            if validLeft {
                closePass.leftSensorValue =
                    leftSensorVal
            }

            if validRight {
                closePass.rightSensorValue =
                    rightSensorVal
            }

            if checkIncidentMinimumDistance(
                leftSensor1Val
            ) {
                closePass.leftSensor1Value =
                    leftSensor1Val
            }

            if checkIncidentMinimumDistance(
                leftSensor2Val
            ) {
                closePass.leftSensor2Value =
                    leftSensor2Val
            }

            if checkIncidentMinimumDistance(
                rightSensor1Val
            ) {
                closePass.rightSensor1Value =
                    rightSensor1Val
            }

            if checkIncidentMinimumDistance(
                rightSensor2Val
            ) {
                closePass.rightSensor2Value =
                    rightSensor2Val
            }

            guard
                validLeft || validRight
            else {
                return
            }

            closePass.location =
                tripLocation.location

            // Critical: actually attach the sensor data
            // to the location object.
            tripLocation.closePassInfo =
                closePass

            let annotation =
                TripAnnotation()

            annotation.incidentId = 1

            annotation.source =
                TripAnnotationSource.automatic.rawValue

            annotation.comment =
                """
                Open Bike Sensor Close Pass incident reading
                Left Sensor: \(leftSensorVal)
                Right Sensor: \(rightSensorVal)
                """

            tripLocation.tripAnnotation =
                annotation

            let csvLine =
                locationString(
                    from: tripLocation,
                    gyro: tripLocation.gyro,
                    closePassInfo: closePass
                )

            writeLocationRecord(
                csvLine
            )

            didStore = true
        }

        // Close-pass incidents should survive an immediate termination.
        if didStore {
            synchronizeRecordingFiles()
            save()
        }
    }

    public func checkIncidentMinimumDistance(
        _ sensorValue: NSNumber
    ) -> Bool {
        sensorValue.intValue < 150
    }

    // MARK: Incident detection

    public func offlineIncidentDectection() {
        stateQueue.sync {
            addAutomaticAnnotationIfNeededLocked(
                to: largestXMotion
            )

            addAutomaticAnnotationIfNeededLocked(
                to: secondLargestXMotion
            )

            addAutomaticAnnotationIfNeededLocked(
                to: largestYMotion
            )

            addAutomaticAnnotationIfNeededLocked(
                to: secondLargestYMotion
            )

            addAutomaticAnnotationIfNeededLocked(
                to: largestZMotion
            )

            addAutomaticAnnotationIfNeededLocked(
                to: secondLargestZMotion
            )
        }
    }

    public func AIIncidentDetection() {
        // Local pipeline remains the fallback used for the AI mode.
        offlineIncidentDectection()
    }

    private func addAutomaticAnnotationIfNeededLocked(
        to tripLocation: TripLocation?
    ) {
        guard
            let tripLocation,
            tripLocation.tripAnnotation == nil
        else {
            return
        }

        let annotation =
            TripAnnotation()

        annotation.source =
            TripAnnotationSource.automatic.rawValue

        tripLocation.tripAnnotation =
            annotation
    }

    // MARK: Location

    public func addLocation(
        _ location: CLLocation,
        withGyroData gyroData: CMGyroData?
    ) {
        stateQueue.sync {
            addLocationLocked(
                location,
                withGyroData: gyroData
            )
        }
    }

    private func addLocationLocked(
        _ location: CLLocation,
        withGyroData gyroData: CMGyroData?
    ) {
        guard isRecording else {
            return
        }

        // Invalid accuracy values are not usable.
        guard location.horizontalAccuracy >= 0 else {
            return
        }

        let age =
            location.timestamp.timeIntervalSinceNow

        // Reject stale samples and implausible future samples.
        guard
            age >= -2,
            age <= 15
        else {
            return
        }

        if
            let lastLocation,
            location.timestamp <= lastLocation.timestamp
        {
            return
        }

        if startLocation == nil {
            startLocation =
                location
        }

        let previousTripLocation =
            tripLocations.lastObject as? TripLocation

        let delegate =
            appDelegate ?? AppDelegate.shared()

        let configuredDeferredSecs =
            delegate.defaults.integer(
                forKey: "deferredSecs"
            )

        let configuredDeferredMeters =
            delegate.defaults.integer(
                forKey: "deferredMeters"
            )

        guard let startLocation else {
            return
        }

        let referenceDate =
            recordingStartDate
            ?? startLocation.timestamp

        let elapsed =
            location.timestamp.timeIntervalSince(
                referenceDate
            )

        let distanceFromStart =
            location.distance(
                from: startLocation
            )

        let timeRequirementSatisfied =
            configuredDeferredSecs <= 0
            || elapsed > Double(
                configuredDeferredSecs
            )

        let distanceRequirementSatisfied =
            configuredDeferredMeters <= 0
            || distanceFromStart > Double(
                configuredDeferredMeters
            )

        guard
            timeRequirementSatisfied,
            distanceRequirementSatisfied
        else {
            return
        }

        let newLocation =
            TripLocation()

        newLocation.location =
            location

        let gyro =
            TripGyro()

        gyro.x =
            gyroData?.rotationRate.x ?? 0

        gyro.y =
            gyroData?.rotationRate.y ?? 0

        gyro.z =
            gyroData?.rotationRate.z ?? 0

        newLocation.gyro =
            gyro

        if let previousLocation =
            previousTripLocation?.location
        {
            let distance =
                location.distance(
                    from: previousLocation
                )

            if distance.isFinite,
               distance >= 0,
               distance < 10_000
            {
                accumulatedLength +=
                    distance
            }
        }

        tripLocations.add(
            newLocation
        )

        lastLocation =
            location

        invalidateLengthCache()

        let csvLine =
            locationString(
                from: newLocation,
                gyro: gyro,
                closePassInfo: nil
            )

        writeLocationRecord(
            csvLine
        )

        locationsSinceCheckpoint += 1

        let now =
            Date()

        let checkpointDue =
            locationsSinceCheckpoint >= 5
            || (
                lastCheckpointFlushDate == nil
                || now.timeIntervalSince(
                    lastCheckpointFlushDate ?? now
                ) >= 10
            )

        if checkpointDue {
            synchronizeRecordingFiles()

            saveRecordingCheckpointLocked()

            locationsSinceCheckpoint = 0
            lastCheckpointFlushDate = now
        }

        guard let previousTripLocation else {
            return
        }

        updateLargestMotionCandidatesLocked(
            with: previousTripLocation
        )
    }

    // MARK: Motion candidate detection

    private func updateLargestMotionCandidatesLocked(
        with location: TripLocation
    ) {
        updateLargestXMotionLocked(
            with: location
        )

        updateLargestYMotionLocked(
            with: location
        )

        updateLargestZMotionLocked(
            with: location
        )
    }

    private func updateLargestXMotionLocked(
        with location: TripLocation
    ) {
        let value =
            motionRangeX(
                for: location
            )

        if let largestXMotion {
            let largestValue =
                motionRangeX(
                    for: largestXMotion
                )

            if value > largestValue {
                secondLargestXMotion =
                    largestXMotion

                self.largestXMotion =
                    location
            } else if let secondLargestXMotion {
                let secondValue =
                    motionRangeX(
                        for: secondLargestXMotion
                    )

                if value > secondValue {
                    self.secondLargestXMotion =
                        location
                }
            } else {
                secondLargestXMotion =
                    location
            }
        } else {
            largestXMotion =
                location
        }
    }

    private func updateLargestYMotionLocked(
        with location: TripLocation
    ) {
        let value =
            motionRangeY(
                for: location
            )

        if let largestYMotion {
            let largestValue =
                motionRangeY(
                    for: largestYMotion
                )

            if value > largestValue {
                secondLargestYMotion =
                    largestYMotion

                self.largestYMotion =
                    location
            } else if let secondLargestYMotion {
                let secondValue =
                    motionRangeY(
                        for: secondLargestYMotion
                    )

                if value > secondValue {
                    self.secondLargestYMotion =
                        location
                }
            } else {
                secondLargestYMotion =
                    location
            }
        } else {
            largestYMotion =
                location
        }
    }

    private func updateLargestZMotionLocked(
        with location: TripLocation
    ) {
        let value =
            motionRangeZ(
                for: location
            )

        if let largestZMotion {
            let largestValue =
                motionRangeZ(
                    for: largestZMotion
                )

            if value > largestValue {
                secondLargestZMotion =
                    largestZMotion

                self.largestZMotion =
                    location
            } else if let secondLargestZMotion {
                let secondValue =
                    motionRangeZ(
                        for: secondLargestZMotion
                    )

                if value > secondValue {
                    self.secondLargestZMotion =
                        location
                }
            } else {
                secondLargestZMotion =
                    location
            }
        } else {
            largestZMotion =
                location
        }
    }

    private func motionRangeX(
        for location: TripLocation
    ) -> Double {
        max(
            0,
            location.maxOfMotionsX
                - location.minOfMotionsX
        )
    }

    private func motionRangeY(
        for location: TripLocation
    ) -> Double {
        max(
            0,
            location.maxOfMotionsY
                - location.minOfMotionsY
        )
    }

    private func motionRangeZ(
        for location: TripLocation
    ) -> Double {
        max(
            0,
            location.maxOfMotionsZ
                - location.minOfMotionsZ
        )
    }

    // MARK: Motion

    public func addAcceleration(
        x: Double,
        y: Double,
        z: Double,
        xl: Double,
        yl: Double,
        zl: Double,
        xr: Double,
        yr: Double,
        zr: Double,
        cr: Double
    ) {
        stateQueue.sync {
            guard isRecording else {
                return
            }

            guard
                let tripLocation =
                    tripLocations.lastObject as? TripLocation
            else {
                return
            }

            let motion =
                TripMotion()

            motion.x = x
            motion.y = y
            motion.z = z

            motion.xl = xl
            motion.yl = yl
            motion.zl = zl

            motion.xr = xr
            motion.yr = yr
            motion.zr = zr
            motion.cr = cr

            motion.timestamp =
                Date().timeIntervalSince1970

            lastTripMotion =
                motion

            tripLocation.tripMotions.add(
                motion
            )

            tripLocation.minOfMotionsX =
                min(
                    tripLocation.minOfMotionsX,
                    motion.x
                )

            tripLocation.minOfMotionsY =
                min(
                    tripLocation.minOfMotionsY,
                    motion.y
                )

            tripLocation.minOfMotionsZ =
                min(
                    tripLocation.minOfMotionsZ,
                    motion.z
                )

            tripLocation.maxOfMotionsX =
                max(
                    tripLocation.maxOfMotionsX,
                    motion.x
                )

            tripLocation.maxOfMotionsY =
                max(
                    tripLocation.maxOfMotionsY,
                    motion.y
                )

            tripLocation.maxOfMotionsZ =
                max(
                    tripLocation.maxOfMotionsZ,
                    motion.z
                )

            writeMotionRecord(
                motionString(
                    from: motion
                )
            )
        }
    }

    // MARK: Recording IO

    private func writeLocationRecord(
        _ string: String
    ) {
        let data =
            Data(
                string.utf8
            )

        recordingIOQueue.sync {
            locationsFile?.write(
                data
            )
        }
    }

    private func writeMotionRecord(
        _ string: String
    ) {
        let data =
            Data(
                string.utf8
            )

        recordingIOQueue.sync {
            motionsFile?.write(
                data
            )
        }
    }

    private func synchronizeRecordingFiles() {
        recordingIOQueue.sync {
            try? locationsFile?.synchronize()
            try? motionsFile?.synchronize()
        }
    }

    // MARK: Checkpoint

    private func removeRecordingCheckpoint() {
        try? FileManager.default.removeItem(
            at: Self.checkpointURL(
                forIdentifier: identifier
            )
        )
    }

    private func saveRecordingCheckpoint() {
        let checkpoint =
            stateQueue.sync {
                recordingCheckpointDictionaryLocked()
            }

        writeCheckpoint(
            checkpoint
        )
    }

    private func saveRecordingCheckpointLocked() {
        writeCheckpoint(
            recordingCheckpointDictionaryLocked()
        )
    }

    private func writeCheckpoint(
        _ checkpoint: [String: Any]
    ) {
        let url =
            Self.checkpointURL(
                forIdentifier: identifier
            )

        guard JSONSerialization.isValidJSONObject(
            checkpoint
        ) else {
            return
        }

        guard let data =
            try? JSONSerialization.data(
                withJSONObject: checkpoint,
                options: []
            )
        else {
            return
        }

        try? data.write(
            to: url,
            options: .atomic
        )
    }

    private func recordingCheckpointDictionaryLocked()
        -> [String: Any]
    {
        [
            "identifier": identifier,
            "version": version,
            "AIVersion": AIVersion,
            "deferredSecs": deferredSecs,
            "deferredMeters": deferredMeters,
            "bikeTypeId": bikeTypeId,
            "positionId": positionId,
            "childseat": childseat,
            "trailer": trailer,
            "recordingStartDate":
                recordingStartDate?.timeIntervalSince1970
                ?? 0
        ]
    }

    // MARK: Resume

    public func resumeRecording(
        from startDate: Date
    ) {
        appDelegate =
            AppDelegate.shared()

        stateQueue.sync {
            recordingStartDate =
                startDate

            startLocation =
                (
                    tripLocations.firstObject
                        as? TripLocation
                )?.location

            lastLocation =
                (
                    tripLocations.lastObject
                        as? TripLocation
                )?.location

            lastTripMotion =
                (
                    tripLocations.lastObject
                        as? TripLocation
                )?
                .tripMotions
                .lastObject as? TripMotion

            isRecording =
                true

            locationsSinceCheckpoint = 0

            lastCheckpointFlushDate =
                Date()

            invalidateLengthCache()
        }

        let locationsURL =
            Self.locationsURL(
                forIdentifier: identifier
            )

        let motionsURL =
            Self.motionsURL(
                forIdentifier: identifier
            )

        let reopened =
            recordingIOQueue.sync { () -> Bool in
                guard
                    let locationFile =
                        try? FileHandle(
                            forUpdating: locationsURL
                        ),
                    let motionFile =
                        try? FileHandle(
                            forUpdating: motionsURL
                        )
                else {
                    return false
                }

                locationsFile =
                    locationFile

                motionsFile =
                    motionFile

                _ = try? locationsFile?.seekToEnd()
                _ = try? motionsFile?.seekToEnd()

                return true
            }

        guard reopened else {
            stateQueue.sync {
                isRecording = false
            }

            print(
                "[Trip] Could not reopen recording files for trip \(identifier)"
            )

            return
        }

        saveRecordingCheckpoint()

        startSensorsAndLocationUpdates()
    }

    // MARK: Recovery

    public static func loadIncompleteTrip()
        -> Trip?
    {
        guard
            let identifier =
                recoverableIdentifiers().first
        else {
            return nil
        }

        return tripFromCheckpoint(
            at:
                checkpointURL(
                    forIdentifier:
                        identifier.intValue
                )
        )
    }

    public static func recoverIncompleteTrips() {
        let fileManager =
            FileManager.default

        for identifierNumber
            in recoverableIdentifiers()
        {
            let identifier =
                identifierNumber.intValue

            let tripURL =
                Self.tripURL(
                    forIdentifier: identifier
                )

            let tripInfoURL =
                Self.tripInfoURL(
                    forIdentifier: identifier
                )

            let checkpointURL =
                Self.checkpointURL(
                    forIdentifier: identifier
                )

            let locationsURL =
                Self.locationsURL(
                    forIdentifier: identifier
                )

            let motionsURL =
                Self.motionsURL(
                    forIdentifier: identifier
                )

            if
                fileManager.fileExists(
                    atPath: tripURL.path
                )
                || fileManager.fileExists(
                    atPath: tripInfoURL.path
                )
            {
                try? fileManager.removeItem(
                    at: checkpointURL
                )

                continue
            }

            if let trip =
                tripFromCheckpoint(
                    at: checkpointURL
                )
            {
                print(
                    "[Trip] recovering unfinished trip \(identifier)"
                )

                trip.save()
            } else {
                print(
                    "[Trip] removing stale checkpoint for trip \(identifier)"
                )

                try? fileManager.removeItem(
                    at: checkpointURL
                )

                try? fileManager.removeItem(
                    at: locationsURL
                )

                try? fileManager.removeItem(
                    at: motionsURL
                )
            }
        }
    }

    private static func tripFromCheckpoint(
        at checkpointURL: URL
    ) -> Trip?
    {
        guard
            let data =
                try? Data(
                    contentsOf: checkpointURL
                ),
            let object =
                try? JSONSerialization.jsonObject(
                    with: data,
                    options: []
                ),
            let checkpoint =
                object as? [String: Any],
            let identifier =
                intValue(
                    checkpoint["identifier"]
                ),
            identifier > 0
        else {
            return nil
        }

        let locationsURL =
            Self.locationsURL(
                forIdentifier: identifier
            )

        let motionsURL =
            Self.motionsURL(
                forIdentifier: identifier
            )

        guard
            let locationsString =
                try? String(
                    contentsOf: locationsURL,
                    encoding: .utf8
                ),
            !locationsString.isEmpty
        else {
            return nil
        }

        let motionsString =
            (try? String(
                contentsOf: motionsURL,
                encoding: .utf8
            )) ?? ""

        let trip =
            Trip(
                identifier: identifier
            )

        trip.version =
            intValue(
                checkpoint["version"]
            ) ?? 0

        trip.AIVersion =
            intValue(
                checkpoint["AIVersion"]
            ) ?? 0

        trip.deferredSecs =
            intValue(
                checkpoint["deferredSecs"]
            ) ?? 0

        trip.deferredMeters =
            intValue(
                checkpoint["deferredMeters"]
            ) ?? 0

        trip.bikeTypeId =
            intValue(
                checkpoint["bikeTypeId"]
            ) ?? 0

        trip.positionId =
            intValue(
                checkpoint["positionId"]
            ) ?? 0

        trip.childseat =
            boolValue(
                checkpoint["childseat"]
            ) ?? false

        trip.trailer =
            boolValue(
                checkpoint["trailer"]
            ) ?? false

        if
            let timestamp =
                doubleValue(
                    checkpoint["recordingStartDate"]
                ),
            timestamp > 0
        {
            trip.recordingStartDate =
                Date(
                    timeIntervalSince1970:
                        timestamp
                )
        }

        struct LocationEntry {
            let timestamp: Double
            let location: TripLocation
        }

        struct MotionEntry {
            let timestamp: Double
            let motion: TripMotion
        }

        var locations: [LocationEntry] = []
        var motions: [MotionEntry] = []

        locationsString.enumerateLines { line, _ in
            guard
                let location =
                    tripLocation(
                        fromCSVLine:
                            line
                    )
            else {
                return
            }

            locations.append(
                LocationEntry(
                    timestamp:
                        location.location.timestamp
                            .timeIntervalSince1970,
                    location:
                        location
                )
            )
        }

        motionsString.enumerateLines { line, _ in
            guard
                let motion =
                    tripMotion(
                        fromCSVLine:
                            line
                    )
            else {
                return
            }

            motions.append(
                MotionEntry(
                    timestamp:
                        motion.timestamp,
                    motion:
                        motion
                )
            )
        }

        var locationIndex = 0
        var motionIndex = 0
        var currentLocation: TripLocation?

        while locationIndex < locations.count || motionIndex < motions.count {
            let takeLocation: Bool

            if locationIndex >= locations.count {
                takeLocation = false
            } else if motionIndex >= motions.count {
                takeLocation = true
            } else {
                takeLocation =
                    locations[locationIndex].timestamp
                    <= motions[motionIndex].timestamp
            }

            if takeLocation {
                let location =
                    locations[locationIndex].location

                if trip.startLocation == nil {
                    trip.startLocation =
                        location.location
                }

                if let previous =
                    trip.tripLocations.lastObject
                    as? TripLocation
                {
                    let distance =
                        location.location.distance(
                            from: previous.location
                        )

                    if distance.isFinite,
                       distance >= 0,
                       distance < 10_000
                    {
                        trip.accumulatedLength +=
                            distance
                    }
                }

                trip.lastLocation =
                    location.location

                trip.tripLocations.add(
                    location
                )

                currentLocation =
                    location

                locationIndex += 1
            } else {
                let motion =
                    motions[motionIndex].motion

                if let currentLocation {
                    currentLocation.tripMotions.add(
                        motion
                    )

                    currentLocation.minOfMotionsX =
                        min(
                            currentLocation.minOfMotionsX,
                            motion.x
                        )

                    currentLocation.minOfMotionsY =
                        min(
                            currentLocation.minOfMotionsY,
                            motion.y
                        )

                    currentLocation.minOfMotionsZ =
                        min(
                            currentLocation.minOfMotionsZ,
                            motion.z
                        )

                    currentLocation.maxOfMotionsX =
                        max(
                            currentLocation.maxOfMotionsX,
                            motion.x
                        )

                    currentLocation.maxOfMotionsY =
                        max(
                            currentLocation.maxOfMotionsY,
                            motion.y
                        )

                    currentLocation.maxOfMotionsZ =
                        max(
                            currentLocation.maxOfMotionsZ,
                            motion.z
                        )

                    trip.lastTripMotion =
                        motion
                }

                motionIndex += 1
            }
        }

        guard trip.tripLocations.count > 0 else {
            return nil
        }

        if trip.tripAnnotationsLocked() == 0,
           let firstLocation =
               trip.tripLocations.firstObject as? TripLocation
        {
            let placeholder =
                TripAnnotation()

            placeholder.incidentId = -5

            firstLocation.tripAnnotation =
                placeholder
        }

        trip.invalidateLengthCache()

        return trip
    }

    // MARK: Legacy CSV recovery

    private static func tripLocation(
        fromCSVLine line: String
    ) -> TripLocation?
    {
        let fields =
            line.components(
                separatedBy: ","
            )

        guard
            fields.count >= 7,
            let latitude =
                Double(fields[0]),
            let longitude =
                Double(fields[1]),
            let timestampMilliseconds =
                Double(fields[5]),
            let horizontalAccuracy =
                Double(fields[6])
        else {
            return nil
        }

        let location =
            CLLocation(
                coordinate:
                    CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    ),
                altitude: 0,
                horizontalAccuracy:
                    horizontalAccuracy,
                verticalAccuracy: 0,
                course: 0,
                speed: 0,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            timestampMilliseconds
                            / 1000.0
                    )
            )

        let tripLocation =
            TripLocation()

        tripLocation.location =
            location

        if fields.count >= 10 {
            let gyro =
                TripGyro()

            gyro.x =
                Double(fields[7]) ?? 0

            gyro.y =
                Double(fields[8]) ?? 0

            gyro.z =
                Double(fields[9]) ?? 0

            tripLocation.gyro =
                gyro
        }

        // Restore close-pass data directly from the raw CSV.
        if
            fields.count > 14,
            (Int(fields[14]) ?? 0) == 1
        {
            let closePass =
                ClosePassInfo()

            closePass.leftSensor1Value =
                NSNumber(
                    value:
                        Int(fields[10]) ?? -1
                )

            closePass.leftSensor2Value =
                NSNumber(
                    value:
                        Int(fields[11]) ?? -1
                )

            closePass.rightSensor1Value =
                NSNumber(
                    value:
                        Int(fields[12]) ?? -1
                )

            closePass.rightSensor2Value =
                NSNumber(
                    value:
                        Int(fields[13]) ?? -1
                )

            closePass.location =
                location

            tripLocation.closePassInfo =
                closePass

            let annotation =
                TripAnnotation()

            annotation.incidentId = 1

            annotation.source =
                TripAnnotationSource.automatic.rawValue

            tripLocation.tripAnnotation =
                annotation
        }

        return tripLocation
    }

    private static func tripMotion(
        fromCSVLine line: String
    ) -> TripMotion?
    {
        let fields =
            line.components(
                separatedBy: ","
            )

        guard
            fields.count >= 6,
            let x =
                Double(fields[2]),
            let y =
                Double(fields[3]),
            let z =
                Double(fields[4]),
            let timestampMilliseconds =
                Double(fields[5])
        else {
            return nil
        }

        let motion =
            TripMotion()

        motion.x = x
        motion.y = y
        motion.z = z

        motion.timestamp =
            timestampMilliseconds / 1000.0

        if fields.count >= 22 {
            motion.xl =
                Double(fields[15]) ?? 0

            motion.yl =
                Double(fields[16]) ?? 0

            motion.zl =
                Double(fields[17]) ?? 0

            motion.xr =
                Double(fields[18]) ?? 0

            motion.yr =
                Double(fields[19]) ?? 0

            motion.zr =
                Double(fields[20]) ?? 0

            motion.cr =
                Double(fields[21]) ?? 0
        }

        return motion
    }

    // MARK: JSON conversion

    private func convertTripLocationToDictionary(
        _ tripLocation: TripLocation
    ) -> [String: Any]
    {
        var dictionary:
            [String: Any] = [
                "lat":
                    tripLocation.location.coordinate.latitude,

                "lon":
                    tripLocation.location.coordinate.longitude,

                "alt":
                    tripLocation.location.altitude,

                "horizontalAccuracy":
                    tripLocation.location.horizontalAccuracy,

                "verticalAccuracy":
                    tripLocation.location.verticalAccuracy,

                "speed":
                    tripLocation.location.speed,

                "course":
                    tripLocation.location.course,

                "timestamp":
                    tripLocation.location.timestamp
                        .timeIntervalSince1970,

                "minOfMotionsX":
                    tripLocation.minOfMotionsX,

                "maxOfMotionsX":
                    tripLocation.maxOfMotionsX,

                "minOfMotionsY":
                    tripLocation.minOfMotionsY,

                "maxOfMotionsY":
                    tripLocation.maxOfMotionsY,

                "minOfMotionsZ":
                    tripLocation.minOfMotionsZ,

                "maxOfMotionsZ":
                    tripLocation.maxOfMotionsZ
            ]

        if let gyro =
            tripLocation.gyro
        {
            dictionary["gyro"] = [
                "x": gyro.x,
                "y": gyro.y,
                "z": gyro.z
            ]
        }

        if let closePass =
            tripLocation.closePassInfo
        {
            dictionary["closePassInfo"] = [
                "leftSensorValue":
                    closePass.leftSensorValue?.intValue ?? -1,

                "rightSensorValue":
                    closePass.rightSensorValue?.intValue ?? -1,

                "leftSensor1Value":
                    closePass.leftSensor1Value?.intValue ?? -1,

                "leftSensor2Value":
                    closePass.leftSensor2Value?.intValue ?? -1,

                "rightSensor1Value":
                    closePass.rightSensor1Value?.intValue ?? -1,

                "rightSensor2Value":
                    closePass.rightSensor2Value?.intValue ?? -1
            ]
        }

        if let annotation =
            tripLocation.tripAnnotation
        {
            dictionary["tripAnnotation"] = [
                "incidentId":
                    annotation.incidentId,

                "bus":
                    annotation.bus,

                "bicycle":
                    annotation.bicycle,

                "pedestrian":
                    annotation.pedestrian,

                "delivery":
                    annotation.delivery,

                "commercial":
                    annotation.commercial,

                "motorcycle":
                    annotation.motorcycle,

                "car":
                    annotation.car,

                "taxi":
                    annotation.taxi,

                "other":
                    annotation.other,

                "escooter":
                    annotation.escooter,

                "frightening":
                    annotation.frightening,

                "source":
                    annotation.source,

                "comment":
                    annotation.comment ?? ""
            ]
        }

        var motionArray:
            [[String: Any]] = []

        motionArray.reserveCapacity(
            tripLocation.tripMotions.count
        )

        for case let motion as TripMotion
            in tripLocation.tripMotions
        {
            motionArray.append(
                [
                    "x": motion.x,
                    "y": motion.y,
                    "z": motion.z,
                    "xl": motion.xl,
                    "yl": motion.yl,
                    "zl": motion.zl,
                    "xr": motion.xr,
                    "yr": motion.yr,
                    "zr": motion.zr,
                    "cr": motion.cr,
                    "timestamp": motion.timestamp
                ]
            )
        }

        dictionary["tripMotions"] =
            motionArray

        return dictionary
    }

    // MARK: JSON deserialization

    private static func tripLocation(
        fromDictionary dictionary: [String: Any]
    ) -> TripLocation?
    {
        guard
            let latitude =
                doubleValue(
                    dictionary["lat"]
                ),
            let longitude =
                doubleValue(
                    dictionary["lon"]
                )
        else {
            return nil
        }

        let location =
            CLLocation(
                coordinate:
                    CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    ),
                altitude:
                    doubleValue(
                        dictionary["alt"]
                    ) ?? 0,

                horizontalAccuracy:
                    doubleValue(
                        dictionary["horizontalAccuracy"]
                    ) ?? 0,

                verticalAccuracy:
                    doubleValue(
                        dictionary["verticalAccuracy"]
                    ) ?? 0,

                course:
                    doubleValue(
                        dictionary["course"]
                    ) ?? 0,

                speed:
                    doubleValue(
                        dictionary["speed"]
                    ) ?? 0,

                timestamp:
                    Date(
                        timeIntervalSince1970:
                            doubleValue(
                                dictionary["timestamp"]
                            )
                            ?? Date().timeIntervalSince1970
                    )
            )

        let tripLocation =
            TripLocation()

        tripLocation.location =
            location

        tripLocation.minOfMotionsX =
            doubleValue(
                dictionary["minOfMotionsX"]
            ) ?? 0

        tripLocation.maxOfMotionsX =
            doubleValue(
                dictionary["maxOfMotionsX"]
            ) ?? 0

        tripLocation.minOfMotionsY =
            doubleValue(
                dictionary["minOfMotionsY"]
            ) ?? 0

        tripLocation.maxOfMotionsY =
            doubleValue(
                dictionary["maxOfMotionsY"]
            ) ?? 0

        tripLocation.minOfMotionsZ =
            doubleValue(
                dictionary["minOfMotionsZ"]
            ) ?? 0

        tripLocation.maxOfMotionsZ =
            doubleValue(
                dictionary["maxOfMotionsZ"]
            ) ?? 0

        if let gyroDictionary =
            dictionary["gyro"] as? [String: Any]
        {
            let gyro =
                TripGyro()

            gyro.x =
                doubleValue(
                    gyroDictionary["x"]
                ) ?? 0

            gyro.y =
                doubleValue(
                    gyroDictionary["y"]
                ) ?? 0

            gyro.z =
                doubleValue(
                    gyroDictionary["z"]
                ) ?? 0

            tripLocation.gyro =
                gyro
        }

        if let closePassDictionary =
            dictionary["closePassInfo"]
            as? [String: Any]
        {
            let closePass =
                ClosePassInfo()

            closePass.leftSensorValue =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "leftSensorValue"
                            ]
                        ) ?? -1
                )

            closePass.rightSensorValue =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "rightSensorValue"
                            ]
                        ) ?? -1
                )

            closePass.leftSensor1Value =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "leftSensor1Value"
                            ]
                        ) ?? -1
                )

            closePass.leftSensor2Value =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "leftSensor2Value"
                            ]
                        ) ?? -1
                )

            closePass.rightSensor1Value =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "rightSensor1Value"
                            ]
                        ) ?? -1
                )

            closePass.rightSensor2Value =
                NSNumber(
                    value:
                        intValue(
                            closePassDictionary[
                                "rightSensor2Value"
                            ]
                        ) ?? -1
                )

            closePass.location =
                location

            tripLocation.closePassInfo =
                closePass
        }

        if let annotationDictionary =
            dictionary["tripAnnotation"]
            as? [String: Any]
        {
            let annotation =
                TripAnnotation()

            annotation.incidentId =
                intValue(
                    annotationDictionary[
                        "incidentId"
                    ]
                ) ?? 0

            annotation.bus =
                boolValue(
                    annotationDictionary[
                        "bus"
                    ]
                ) ?? false

            annotation.bicycle =
                boolValue(
                    annotationDictionary[
                        "bicycle"
                    ]
                ) ?? false

            annotation.pedestrian =
                boolValue(
                    annotationDictionary[
                        "pedestrian"
                    ]
                ) ?? false

            annotation.delivery =
                boolValue(
                    annotationDictionary[
                        "delivery"
                    ]
                ) ?? false

            annotation.commercial =
                boolValue(
                    annotationDictionary[
                        "commercial"
                    ]
                ) ?? false

            annotation.motorcycle =
                boolValue(
                    annotationDictionary[
                        "motorcycle"
                    ]
                ) ?? false

            annotation.car =
                boolValue(
                    annotationDictionary[
                        "car"
                    ]
                ) ?? false

            annotation.taxi =
                boolValue(
                    annotationDictionary[
                        "taxi"
                    ]
                ) ?? false

            annotation.other =
                boolValue(
                    annotationDictionary[
                        "other"
                    ]
                ) ?? false

            annotation.escooter =
                boolValue(
                    annotationDictionary[
                        "escooter"
                    ]
                ) ?? false

            annotation.frightening =
                boolValue(
                    annotationDictionary[
                        "frightening"
                    ]
                ) ?? false

            annotation.source =
                annotationDictionary[
                    "source"
                ] as? String
                ?? TripAnnotationSource.manual.rawValue

            annotation.comment =
                annotationDictionary[
                    "comment"
                ] as? String

            tripLocation.tripAnnotation =
                annotation
        }

        if let motions =
            dictionary["tripMotions"]
            as? [[String: Any]]
        {
            tripLocation.tripMotions
                .removeAllObjects()

            for motionDictionary in motions {
                let motion =
                    TripMotion()

                motion.x =
                    doubleValue(
                        motionDictionary["x"]
                    ) ?? 0

                motion.y =
                    doubleValue(
                        motionDictionary["y"]
                    ) ?? 0

                motion.z =
                    doubleValue(
                        motionDictionary["z"]
                    ) ?? 0

                motion.xl =
                    doubleValue(
                        motionDictionary["xl"]
                    ) ?? 0

                motion.yl =
                    doubleValue(
                        motionDictionary["yl"]
                    ) ?? 0

                motion.zl =
                    doubleValue(
                        motionDictionary["zl"]
                    ) ?? 0

                motion.xr =
                    doubleValue(
                        motionDictionary["xr"]
                    ) ?? 0

                motion.yr =
                    doubleValue(
                        motionDictionary["yr"]
                    ) ?? 0

                motion.zr =
                    doubleValue(
                        motionDictionary["zr"]
                    ) ?? 0

                motion.cr =
                    doubleValue(
                        motionDictionary["cr"]
                    ) ?? 0

                motion.timestamp =
                    doubleValue(
                        motionDictionary["timestamp"]
                    )
                    ?? Date().timeIntervalSince1970

                tripLocation.tripMotions.add(
                    motion
                )
            }
        }

        return tripLocation
    }

    // MARK: CSV helpers

    private func locationString(
        from tripLocation: TripLocation,
        gyro: TripGyro?,
        closePassInfo: ClosePassInfo?
    ) -> String {
        String(
            format:
                "%f,%f,%f,%f,%f,%.0f,%f,%f,%f,%f,%ld,%ld,%ld,%ld,%d,%f,%f,%f,%f,%f,%f,%f\n",
            tripLocation.location.coordinate.latitude,
            tripLocation.location.coordinate.longitude,
            0.0,
            0.0,
            0.0,
            round(
                tripLocation.location.timestamp
                    .timeIntervalSince1970
                * 1000.0
            ),
            tripLocation.location.horizontalAccuracy,
            gyro?.x ?? 0,
            gyro?.y ?? 0,
            gyro?.z ?? 0,
            closePassInfo?.leftSensor1Value?.intValue ?? -1,
            closePassInfo?.leftSensor2Value?.intValue ?? -1,
            closePassInfo?.rightSensor1Value?.intValue ?? -1,
            closePassInfo?.rightSensor2Value?.intValue ?? -1,
            closePassInfo == nil ? 0 : 1,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0
        )
    }

    private func motionString(
        from tripMotion: TripMotion
    ) -> String {
        String(
            format:
                ",,%f,%f,%f,%.0f,,,,,,,,,,%f,%f,%f,%f,%f,%f,%f\n",
            tripMotion.x,
            tripMotion.y,
            tripMotion.z,
            round(
                tripMotion.timestamp
                * 1000.0
            ),
            tripMotion.xl,
            tripMotion.yl,
            tripMotion.zl,
            tripMotion.xr,
            tripMotion.yr,
            tripMotion.zr,
            tripMotion.cr
        )
    }

    private static func csvTimestamp(
        in line: String,
        index: Int
    ) -> Double {
        let fields =
            line.components(
                separatedBy: ","
            )

        guard fields.indices.contains(index) else {
            return 0
        }

        return Double(
            fields[index]
        ) ?? 0
    }

    private static func escapeLegacyCSVComment(
        _ comment: String
    ) -> String {
        let escaped =
            comment
                .replacingOccurrences(
                    of: "\"",
                    with: "\\\""
                )
                .replacingOccurrences(
                    of: "\n",
                    with: "\\\n"
                )

        return "\"\(escaped)\""
    }

    // MARK: Delete / URLs

    public static func deleteFromStorage(
        _ identifier: Int
    ) {
        Utility.remove(
            key: "Trip-\(identifier)"
        )

        Utility.remove(
            key: "TripInfo-\(identifier)"
        )

        let fileManager =
            FileManager.default

        let urls = [
            tripURL(
                forIdentifier: identifier
            ),

            tripInfoURL(
                forIdentifier: identifier
            ),

            locationsURL(
                forIdentifier: identifier
            ),

            motionsURL(
                forIdentifier: identifier
            ),

            checkpointURL(
                forIdentifier: identifier
            )
        ]

        for url in urls {
            try? fileManager.removeItem(
                at: url
            )
        }

        print(
            "[Trip] deleted trip \(identifier)"
        )
    }

    public static func allStoredIdentifiers()
        -> [NSNumber]
    {
        var identifiers =
            Set<Int>()

        let fileManager =
            FileManager.default

        let documentDirectory =
            documentsDirectoryURL()

        if let contents =
            try? fileManager.contentsOfDirectory(
                atPath: documentDirectory.path
            )
        {
            for content in contents
            where content.hasPrefix("Trip-") && content.hasSuffix(".json")
            {
                let idString =
                    content
                        .dropFirst(
                            "Trip-".count
                        )
                        .dropLast(
                            ".json".count
                        )

                if let id =
                    Int(idString),
                   id > 0
                {
                    identifiers.insert(
                        id
                    )
                }
            }
        }

        for key
            in UserDefaults.standard
                .dictionaryRepresentation()
                .keys
        where key.hasPrefix("Trip-")
        {
            let idString =
                key.dropFirst(
                    "Trip-".count
                )

            if let id =
                Int(idString),
               id > 0
            {
                identifiers.insert(
                    id
                )
            }
        }

        return identifiers
            .sorted()
            .map {
                NSNumber(
                    value: $0
                )
            }
    }

    public static func documentsDirectoryURL()
        -> URL
    {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
        ?? FileManager.default.temporaryDirectory
    }

    public static func tripURL(
        forIdentifier identifier: Int
    ) -> URL {
        documentsDirectoryURL()
            .appendingPathComponent(
                "Trip-\(identifier).json"
            )
    }

    public static func tripInfoURL(
        forIdentifier identifier: Int
    ) -> URL {
        documentsDirectoryURL()
            .appendingPathComponent(
                "TripInfo-\(identifier).json"
            )
    }

    public static func locationsURL(
        forIdentifier identifier: Int
    ) -> URL {
        documentsDirectoryURL()
            .appendingPathComponent(
                "TripLocations-\(identifier).csv"
            )
    }

    public static func motionsURL(
        forIdentifier identifier: Int
    ) -> URL {
        documentsDirectoryURL()
            .appendingPathComponent(
                "TripMotions-\(identifier).csv"
            )
    }

    public static func checkpointURL(
        forIdentifier identifier: Int
    ) -> URL {
        documentsDirectoryURL()
            .appendingPathComponent(
                "TripCheckpoint-\(identifier).json"
            )
    }

    private static func recoverableIdentifiers()
        -> [NSNumber]
    {
        guard let contents =
            try? FileManager.default.contentsOfDirectory(
                atPath:
                    documentsDirectoryURL().path
            )
        else {
            return []
        }

        let identifiers =
            contents.compactMap {
                fileName -> Int? in

                guard
                    fileName.hasPrefix(
                        "TripCheckpoint-"
                    ),
                    fileName.hasSuffix(
                        ".json"
                    )
                else {
                    return nil
                }

                let identifierString =
                    fileName
                        .dropFirst(
                            "TripCheckpoint-".count
                        )
                        .dropLast(
                            ".json".count
                        )

                guard
                    let identifier =
                        Int(identifierString),
                    identifier > 0
                else {
                    return nil
                }

                return identifier
            }

        return Array(
            Set(identifiers)
        )
        .sorted()
        .map {
            NSNumber(
                value: $0
            )
        }
    }

    // MARK: Type conversion helpers

    private static func intValue(
        _ value: Any?
    ) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        if let value = value as? String {
            return Int(value)
        }

        return nil
    }

    private static func doubleValue(
        _ value: Any?
    ) -> Double? {
        if let value = value as? Double {
            return value
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        if let value = value as? String {
            return Double(value)
        }

        return nil
    }

    private static func boolValue(
        _ value: Any?
    ) -> Bool? {
        if let value = value as? Bool {
            return value
        }

        if let value = value as? NSNumber {
            return value.boolValue
        }

        if let value = value as? String {
            switch value.lowercased() {
            case "true",
                 "yes",
                 "1":
                return true

            case "false",
                 "no",
                 "0":
                return false

            default:
                return nil
            }
        }

        return nil
    }

    // MARK: App Delegate

    private func currentAppDelegate()
        -> AppDelegate?
    {
        if let appDelegate {
            return appDelegate
        }

        guard Thread.isMainThread else {
            return nil
        }

        return UIApplication.shared.delegate
            as? AppDelegate
    }

    // MARK: Cleanup

    private func removeLegacyCSVFiles() {
        let fileManager =
            FileManager.default

        try? fileManager.removeItem(
            at:
                Self.locationsURL(
                    forIdentifier: identifier
                )
        )

        try? fileManager.removeItem(
            at:
                Self.motionsURL(
                    forIdentifier: identifier
                )
        )
    }
}
