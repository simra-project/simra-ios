//
//  TripModels.swift
//  SimRa
//
//  Swift equivalents of the legacy Trip model support types.
//

import Foundation
import CoreLocation

@objcMembers
public final class TripAnnotation: NSObject {
    public var comment: String?
    public var frightening: Bool = false
    public var car: Bool = false
    public var taxi: Bool = false
    public var delivery: Bool = false
    public var bus: Bool = false
    public var commercial: Bool = false
    public var pedestrian: Bool = false
    public var bicycle: Bool = false
    public var motorcycle: Bool = false
    public var other: Bool = false
    public var escooter: Bool = false
    public var incidentId: Int = 0
    public var source: String = "Manual" // "Manual", "Siri", "Widget"

    public override init() {
        super.init()
    }
}

@objcMembers
public final class TripMotion: NSObject {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0
    public var xl: Double = 0
    public var yl: Double = 0
    public var zl: Double = 0
    public var xr: Double = 0
    public var yr: Double = 0
    public var zr: Double = 0
    public var cr: Double = 0
    public var timestamp: TimeInterval = 0

    public override init() {
        super.init()
    }

    public func motionString(from tripMotion: TripMotion) -> String {
        var csvString = ",,"
        csvString += String(format: "%f,%f,%f,%.0f,", tripMotion.x * 9.81, tripMotion.y * 9.81, tripMotion.z * 9.81, tripMotion.timestamp * 1000.0)
        csvString += ","
        csvString += ",,,"
        csvString += ",,,,,"
        csvString += String(format: "%f,%f,%f,%f,%f,%f,%f", tripMotion.xl * 9.81, tripMotion.yl * 9.81, tripMotion.zl * 9.81, tripMotion.xr, tripMotion.yr, tripMotion.zr, tripMotion.cr)
        csvString += "\n"
        return csvString
    }
}

@objcMembers
public final class TripGyro: NSObject {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0

    public override init() {
        super.init()
    }

    public func locationString(from tripLocation: TripLocation, gyro: TripGyro?, closePassInfo: ClosePassInfo?) -> String {
        let lat = tripLocation.location.coordinate.latitude
        let lon = tripLocation.location.coordinate.longitude
        let horizontalAccuracy = tripLocation.location.horizontalAccuracy

        var csvString = String(format: "%f,%f,", lat, lon)
        csvString += String(format: "%f,%f,%f,%.0f,", 0.0, 0.0, 0.0, round(tripLocation.location.timestamp.timeIntervalSince1970) * 1000.0)

        if horizontalAccuracy == -1.0 {
            csvString += ","
        } else {
            csvString += String(format: "%f,", horizontalAccuracy)
        }

        if let gyro {
            csvString += String(format: "%f,%f,%f,", gyro.x, gyro.y, gyro.z)
        } else {
            csvString += ",,,"
        }

        var isClosePassEvent = "0"
        var leftSensorVal1 = ""
        var leftSensorVal2 = ""
        var rightSensorVal1 = ""
        var rightSensorVal2 = ""

        if let closePassInfo {
            isClosePassEvent = "1"
            leftSensorVal1 = closePassInfo.leftSensor1Value?.stringValue ?? ""
            leftSensorVal2 = closePassInfo.leftSensor2Value?.stringValue ?? ""
            rightSensorVal1 = closePassInfo.rightSensor1Value?.stringValue ?? ""
            rightSensorVal2 = closePassInfo.rightSensor2Value?.stringValue ?? ""
        }

        csvString += "\(leftSensorVal1),\(leftSensorVal2),\(rightSensorVal1),\(rightSensorVal2),\(isClosePassEvent),"
        csvString += ",,,,,,"
        csvString += "\n"
        return csvString
    }
}

@objcMembers
public final class TripLocation: NSObject {
    public var location: CLLocation
    public var gyro: TripGyro?
    public var tripMotions: NSMutableArray
    public var tripAnnotation: TripAnnotation?
    public var closePassInfo: ClosePassInfo?

    var minOfMotionsX: Double = 0
    var minOfMotionsY: Double = 0
    var minOfMotionsZ: Double = 0
    var maxOfMotionsX: Double = 0
    var maxOfMotionsY: Double = 0
    var maxOfMotionsZ: Double = 0

    public override init() {
        self.location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: -1,
            horizontalAccuracy: -1,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: Date()
        )
        self.tripMotions = NSMutableArray()
        super.init()
    }

    public init(location: CLLocation) {
        self.location = location
        self.tripMotions = NSMutableArray()
        super.init()
    }
}

@objcMembers
public final class TripInfo: NSObject {
    public var identifier: Int = 0
    public var version: Int = 0
    public var edited: Bool = false
    public var uploaded: Bool = false
    public var statisticsAdded: Bool = false
    public var reUploaded: Bool = false
    public var annotationsCount: Int = 0
    public var validAnnotationsCount: Int = 0
    public var fileHash: String?
    public var filePasswd: String?
    public var duration: NSDateInterval = NSDateInterval(start: Date(), end: Date())
    public var length: Int = 0

    public override init() {
        super.init()
    }

    public init(identifier: Int) {
        self.identifier = identifier
        super.init()
    }

    private convenience init?(dictionary: [String: Any]) {
        self.init()

        guard let identifier = dictionary["identifier"] as? NSNumber else { return nil }
        self.identifier = identifier.intValue
        self.version = (dictionary["version"] as? NSNumber)?.intValue ?? 0
        self.edited = (dictionary["edited"] as? NSNumber)?.boolValue ?? false
        self.uploaded = (dictionary["uploaded"] as? NSNumber)?.boolValue ?? false
        self.statisticsAdded = (dictionary["statisticsAdded"] as? NSNumber)?.boolValue ?? false
        self.reUploaded = (dictionary["reUploaded"] as? NSNumber)?.boolValue ?? false
        self.annotationsCount = (dictionary["annotationsCount"] as? NSNumber)?.intValue ?? 0
        self.validAnnotationsCount = (dictionary["validAnnotationsCount"] as? NSNumber)?.intValue ?? 0
        self.fileHash = dictionary["fileHash"] as? String
        self.filePasswd = dictionary["filePasswd"] as? String

        let start = (dictionary["start"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        let end = (dictionary["end"] as? NSNumber)?.doubleValue ?? start
        self.duration = NSDateInterval(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end)
        )
        self.length = (dictionary["length"] as? NSNumber)?.intValue ?? 0
    }

    public convenience init?(fromStorage identifier: Int) {
        let key = "TripInfo-\(identifier)"
        let defaults = UserDefaults.standard

        if let dict = defaults.dictionary(forKey: key) {
            self.init(dictionary: dict)
            return
        }

        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let tripInfoURL = documentDirectory?.appendingPathComponent("TripInfo-\(identifier).json")
        guard
            let tripInfoURL,
            let jsonData = try? Data(contentsOf: tripInfoURL),
            let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
        else {
            return nil
        }

        self.init(dictionary: dict)
    }

    public static func allStoredIdentifiers() -> [NSNumber] {
        var identifiers: [Int] = []
        let defaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys.sorted()

        for key in defaultsKeys where key.hasPrefix("TripInfo-") {
            let id = Int(key.dropFirst("TripInfo-".count)) ?? 0
            if id > 0 {
                identifiers.append(id)
            }
        }

        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: documentDirectory.path) {
            for content in contents where content.hasPrefix("TripInfo-") {
                let id = Int(content.dropFirst("TripInfo-".count).dropLast(".json".count)) ?? 0
                if id > 0 && !identifiers.contains(id) {
                    identifiers.append(id)
                }
            }
        }

        return identifiers.map { NSNumber(value: $0) }
    }

    public func asDictionary() -> [String: Any] {
        var tripInfoDict: [String: Any] = [
            "identifier": identifier,
            "version": version,
            "edited": edited,
            "uploaded": uploaded,
            "statisticsAdded": statisticsAdded,
            "reUploaded": reUploaded,
            "annotationsCount": annotationsCount,
            "validAnnotationsCount": validAnnotationsCount,
            "start": duration.startDate.timeIntervalSince1970,
            "end": duration.endDate.timeIntervalSince1970,
            "length": length
        ]

        if let fileHash {
            tripInfoDict["fileHash"] = fileHash
        }
        if let filePasswd {
            tripInfoDict["filePasswd"] = filePasswd
        }

        return tripInfoDict
    }

    public func asJSONData() -> Data? {
        try? JSONSerialization.data(withJSONObject: asDictionary(), options: [])
    }
}

@objcMembers
public final class Trips: UploaderObject {
    public var tripInfos: [NSNumber: TripInfo] = [:]
    private weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate?) {
        self.appDelegate = appDelegate
        super.init()
        let defaults = appDelegate?.defaults ?? UserDefaults.standard
        self.version = defaults.integer(forKey: "version")
        self.uploaded = defaults.bool(forKey: "uploaded")
        self.fileHash = defaults.string(forKey: "fileHash")
        self.filePasswd = defaults.string(forKey: "filePasswd")

        self.tripInfos = [:]
        loadTripInfos()
    }

    public func loadTripInfos() {
        let allTripInfos = TripInfo.allStoredIdentifiers()
        for anIdentifier in allTripInfos {
            let identifier = anIdentifier.intValue
            if let tripInfo = TripInfo(fromStorage: identifier) {
                self.tripInfos[NSNumber(value: tripInfo.identifier)] = tripInfo
            }
        }

    }

    public func newTrip() -> Trip {
        let trip = Trip()
        let tripInfo = trip.tripInfo()
        self.tripInfos[NSNumber(value: trip.identifier)] = tripInfo
        return trip
    }

    public func deleteTrip(withIdentifier identifier: Int) {
        self.tripInfos.removeValue(forKey: NSNumber(value: identifier))
        Trip.deleteFromStorage(identifier)
    }

    public func updateTrip(_ trip: Trip) {
        let tripInfo = trip.tripInfo()
        self.tripInfos[NSNumber(value: trip.identifier)] = tripInfo
    }

    public func addTripToStatistics(_ trip: Trip) {
        let appDelegate = self.appDelegate ?? AppDelegate.shared()
        let defaults = appDelegate.defaults
        let regionId = appDelegate.regions.regionId
        let regionSuffix = regionId == 0 ? "" : "-\(regionId)"

        let ridesKey = "totalRides\(regionSuffix)"
        let durationKey = "totalDuration\(regionSuffix)"
        let incidentsKey = "totalIncidents\(regionSuffix)"
        let lengthKey = "totalLength\(regionSuffix)"
        let idleKey = "totalIdle\(regionSuffix)"
        let scaryKey = "numberOfScary\(regionSuffix)"
        let slotsKey = "totalSlots\(regionSuffix)"

        let totalRides = defaults.integer(forKey: ridesKey) + 1
        let tripDuration = Int(trip.duration()?.duration ?? 0)
        let totalDuration = defaults.integer(forKey: durationKey) + tripDuration
        let totalIncidents = defaults.integer(forKey: incidentsKey) + trip.tripValidAnnotations()
        let totalLength = defaults.integer(forKey: lengthKey) + trip.length()
        let totalIdle = defaults.integer(forKey: idleKey) + trip.idle()
        let totalScary = defaults.integer(forKey: scaryKey) + trip.numberOfScary()

        var totalSlots = defaults.array(forKey: slotsKey) as? [Int] ?? [Int](repeating: 0, count: 24)
        if totalSlots.count < 24 {
            totalSlots = [Int](repeating: 0, count: 24)
        }

        // Use first location timestamp as fallback if durationStartDate fails
        let startDate: Date?
        if let durationStart = trip.durationStartDate() {
            startDate = durationStart
        } else if let firstLocation = trip.tripLocations.firstObject as? TripLocation {
            startDate = firstLocation.location.timestamp
        } else {
            startDate = nil
        }

        if let startDate {
            let hour = Calendar.current.component(.hour, from: startDate)
            if hour >= 0 && hour < 24 {
                totalSlots[hour] += 1
            }
        }

        defaults.set(totalRides, forKey: ridesKey)
        defaults.set(totalDuration, forKey: durationKey)
        defaults.set(totalIncidents, forKey: incidentsKey)
        defaults.set(totalLength, forKey: lengthKey)
        defaults.set(totalIdle, forKey: idleKey)
        defaults.set(totalScary, forKey: scaryKey)
        defaults.set(totalSlots, forKey: slotsKey)
    }

    public override func csvFile() -> URL? {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent("trips.csv")
        try? fileManager.removeItem(at: fileURL)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        guard let fh = FileHandle(forWritingAtPath: fileURL.path) else { return nil }

        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let major = bundleVersion.components(separatedBy: ".").first ?? bundleVersion
        var csvString = "i\(major)#\(version)\n"
        csvString += "birth,gender,region,experience,numberOfRides,duration,numberOfIncidents,length,idle,behaviour,numberOfScary"
        for i in 0..<24 {
            csvString += ",\(i)"
        }
        csvString += "\n"
        if let data = csvString.data(using: .utf8) {
            fh.write(data)
        }

        let appDelegate = self.appDelegate ?? AppDelegate.shared()

        let regionId = appDelegate.regions.regionId
        let regionSuffix = regionId == 0 ? "" : "-\(regionId)"
        let rides = appDelegate.defaults.integer(forKey: "totalRides\(regionSuffix)")
        let duration = appDelegate.defaults.integer(forKey: "totalDuration\(regionSuffix)")
        let incidents = appDelegate.defaults.integer(forKey: "totalIncidents\(regionSuffix)")
        let length = appDelegate.defaults.integer(forKey: "totalLength\(regionSuffix)")
        let idle = appDelegate.defaults.integer(forKey: "totalIdle\(regionSuffix)")
        let scary = appDelegate.defaults.integer(forKey: "numberOfScary\(regionSuffix)")
        let slots = appDelegate.defaults.array(forKey: "totalSlots\(regionSuffix)") as? [Int] ?? [Int](repeating: 0, count: 24)

        var line = String(
            format: "%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%@,%ld",
            appDelegate.defaults.integer(forKey: "ageId"),
            appDelegate.defaults.integer(forKey: "sexId"),
            regionId,
            appDelegate.defaults.integer(forKey: "experienceId"),
            rides,
            duration,
            incidents,
            length,
            idle,
            appDelegate.defaults.bool(forKey: "behaviour") ? "1" : "0",
            scary
        )
        for i in 0..<24 {
            line += String(format: ",%ld", i < slots.count ? slots[i] : 0)
        }
        line += "\n"
        if let data = line.data(using: .utf8) {
            fh.write(data)
        }

        try? fh.close()
        return fileURL
    }
}
