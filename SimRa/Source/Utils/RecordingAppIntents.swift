//
//  RecordingAppIntents.swift
//  SimRa
//
//  App Intents and Live Activity actions.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import AppIntents
import Foundation

enum WidgetRecordingCommandStore {

    private static let suiteName =
        "group.de.tu-berlin.mcc.simra"

    private static let commandKey =
        "pendingRecordingCommand"

    private static let incidentEventsKey =
        "liveActivityIncidentEvents"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func enqueueStop() {
        defaults.set("stop", forKey: commandKey)
    }

    static func enqueueIncident(
        _ incidentType: Int,
        source: String = "Live Activity",
        participantMask: Int = 0,
        frightening: Bool = false,
        comment: String? = nil
    ) {
        guard incidentType >= 0 else {
            return
        }

        var events =
            defaults.array(forKey: incidentEventsKey)
            as? [[String: Any]]
            ?? []

        events.append([
            "id": UUID().uuidString,
            "tripId": 0,
            "incidentType": incidentType,
            "timestamp": Date().timeIntervalSince1970,
            "source": source,
            "participantMask": participantMask,
            "frightening": frightening,
            "comment": comment ?? ""
        ])

        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }

        defaults.set(events, forKey: incidentEventsKey)
        defaults.set(events.count, forKey: "pendingLiveActivityIncidents")
    }

    static func takeCommand()
        -> (command: String, incidentType: Int?)?
    {
        guard let command = defaults.string(forKey: commandKey) else {
            return nil
        }

        defaults.removeObject(forKey: commandKey)

        return (command, nil)
    }
}

// MARK: - Stop Recording

@available(iOS 16.2, *)
struct StopRecordingIntent: LiveActivityIntent {

    static let title: LocalizedStringResource =
        "Stop Recording"

    static let description = IntentDescription(
        "Stop the active SimRa recording."
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetRecordingCommandStore.enqueueStop()

        return .result()
    }
}

// MARK: - Mark General Incident

@available(iOS 16.2, *)
struct MarkGeneralIncidentIntent: LiveActivityIntent {

    static let title: LocalizedStringResource =
        "Mark hazard"

    static let description = IntentDescription(
        "Record a hazard during the active SimRa recording."
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetRecordingCommandStore.enqueueIncident(
            0,
            source: "Live Activity"
        )

        return .result()
    }
}

#if !WIDGET_EXTENSION
// MARK: - Start Recording

@available(iOS 16.0, *)
struct StartRecordingIntent: AppIntent {

    static let title: LocalizedStringResource =
        "Start Recording"

    static let description = IntentDescription(
        "Start a new SimRa recording."
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let started = await MainActor.run {
            RecordingShortcutBridge.startRecording()
        }

        guard started else {
            throw RecordingShortcutError.alreadyRecording
        }

        return .result(
            dialog: IntentDialog(
                "Recording started."
            )
        )
    }
}

@available(iOS 16.0, *)
struct StopRecordingAppIntent: AppIntent {

    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription(
        "Stop the active SimRa recording."
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let stopped = await MainActor.run {
            RecordingShortcutBridge.stopRecording()
        }

        guard stopped else {
            throw RecordingShortcutError.notRecording
        }

        return .result(dialog: IntentDialog("Recording stopped."))
    }
}

// MARK: - Typed Incident

@available(iOS 16.0, *)
struct MarkIncidentIntent: AppIntent {

    static let title: LocalizedStringResource =
        "Mark Incident"

    static let description = IntentDescription(
        "Record an incident with a hazard type."
    )

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Hazard type")
    var hazardType: IncidentType?

    @Parameter(title: "Involved road user")
    var participant: IncidentParticipant?

    @Parameter(title: "Frightening")
    var frightening: Bool

    @Parameter(title: "Comment")
    var comment: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Report \(\.$hazardType) involving \(\.$participant)") {
            \.$frightening
            \.$comment
        }
    }

    init() {
        self.hazardType = nil
        self.participant = nil
        self.frightening = false
        self.comment = nil
    }

    init(hazardType: IncidentType) {
        self.hazardType = hazardType
        self.participant = nil
        self.frightening = false
        self.comment = nil
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let selectedType = try await $hazardType.requestValue("What happened?")
        let selectedParticipant = try await $participant.requestValue("Who was involved?")
        let selectedFrightening = try await $frightening.requestValue(
            "Was it frightening?"
        )
        let selectedComment = try await $comment.requestValue(
            "Add a comment."
        )

        let marked = await MainActor.run {
            RecordingShortcutBridge.markIncident(
                selectedType.incidentID,
                source: "Siri",
                participantMask:
                    selectedParticipant.maskValue,
                frightening:
                    selectedFrightening,
                comment:
                    selectedComment
            )
        }

        guard marked else {
            throw RecordingShortcutError.notRecording
        }

        return .result(
            dialog: IntentDialog(
                "Hazard recorded."
            )
        )
    }
}

@available(iOS 16.0, *)
enum IncidentParticipant: String, AppEnum {
    case car
    case taxi
    case delivery
    case bus
    case pedestrian
    case bicycle
    case motorcycle
    case escooter
    case other
    case unknown

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Involved road user")
    }

    static var caseDisplayRepresentations:
        [IncidentParticipant: DisplayRepresentation] {
        [
            .car: "Car",
            .taxi: "Taxi",
            .delivery: "Delivery vehicle",
            .bus: "Bus",
            .pedestrian: "Pedestrian",
            .bicycle: "Bicycle",
            .motorcycle: "Motorcycle",
            .escooter: "E-scooter",
            .other: "Other",
            .unknown: "Not sure"
        ]
    }

    var maskValue: Int {
        guard self != .unknown else {
            return 0
        }
        return 1 << rawIndex
    }

    private var rawIndex: Int {
        switch self {
        case .car: return 0
        case .taxi: return 1
        case .delivery: return 2
        case .bus: return 3
        case .pedestrian: return 4
        case .bicycle: return 5
        case .motorcycle: return 6
        case .escooter: return 7
        case .other: return 8
        case .unknown: return 9
        }
    }
}

@available(iOS 16.0, *)
struct MarkShortcutIncidentIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Incident"
    static let description = IntentDescription(
        "Record an incident from a Shortcut."
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetRecordingCommandStore.enqueueIncident(
            0,
            source: "Shortcut",
            comment: nil
        )
        return .result()
    }
}

// MARK: - Errors

@available(iOS 16.0, *)
enum RecordingShortcutError:
    Error,
    CustomLocalizedStringResourceConvertible {

    case alreadyRecording
    case notRecording

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .alreadyRecording:
            return "A SimRa recording is already active."

        case .notRecording:
            return "No SimRa recording is active."
        }
    }
}
#endif

// MARK: - Incident Type

@available(iOS 16.0, *)
enum IncidentType: String, AppEnum {

    case generalHazard = "General Hazard"
    case closePassing = "Close Passing"
    case dooring = "Dooring"
    case turningAccident = "Turning Accident"
    case oncomingTraffic = "Oncoming Traffic"
    case parkingCar = "Parking Car"
    case tailgating = "Tailgating"
    case sidestep = "Sidestep"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "Hazard type"
        )
    }

    static var caseDisplayRepresentations:
        [IncidentType: DisplayRepresentation] {
        [
            .generalHazard:
                "Danger",

            .closePassing:
                "Close Passing",

            .dooring:
                "Dooring",

            .turningAccident:
                "Turning Accident",

            .oncomingTraffic:
                "Oncoming Traffic",

            .parkingCar:
                "Parking Car",

            .tailgating:
                "Tailgating",

            .sidestep:
                "Sidestep"
        ]
    }

    var incidentID: Int {
        switch self {
        case .generalHazard:
            return 0

        case .closePassing:
            return 1

        case .dooring:
            return 2

        case .turningAccident:
            return 3

        case .oncomingTraffic:
            return 4

        case .parkingCar:
            return 5

        case .tailgating:
            return 6

        case .sidestep:
            return 7
        }
    }

    var localizedName: String {
        switch self {
        case .generalHazard:
            return NSLocalizedString("Danger", comment: "Hazard type")

        case .closePassing:
            return NSLocalizedString("Close Passing", comment: "Hazard type")

        case .dooring:
            return NSLocalizedString("Dooring", comment: "Hazard type")

        case .turningAccident:
            return NSLocalizedString("Turning Accident", comment: "Hazard type")

        case .oncomingTraffic:
            return "Gegenverkehr"

        case .parkingCar:
            return "Einparkendes Auto"

        case .tailgating:
            return "Auffahren"

        case .sidestep:
            return "Ausweichen"
        }
    }
}

// MARK: - App Shortcuts

#if !WIDGET_EXTENSION
@available(iOS 16.0, *)
struct SimRaShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {

        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Aufzeichnung in \(.applicationName) starten",
                "Fahrt in \(.applicationName) starten",
                "Start a recording in \(.applicationName)",
                "Start a ride in \(.applicationName)",
                "Démarrer un trajet avec \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: StopRecordingAppIntent(),
            phrases: [
                "Aufzeichnung in \(.applicationName) stoppen",
                "Fahrt in \(.applicationName) beenden",
                "Stop a recording in \(.applicationName)",
                "Stop a ride in \(.applicationName)",
                "Arrêter un trajet avec \(.applicationName)"
            ],
            shortTitle: "Stop Recording",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: MarkShortcutIncidentIntent(),
            phrases: [
                "Gefahr in \(.applicationName) melden",
                "Gefahr in \(.applicationName) erfassen",
                "Gefahrenstelle in \(.applicationName) melden",
                "Vorfall in \(.applicationName) erfassen",
                "Signaler un danger avec \(.applicationName)"
            ],
            shortTitle: "Mark Incident",
            systemImageName: "exclamationmark.triangle.fill"
        )

        AppShortcut(
            intent: MarkIncidentIntent(),
            phrases: [
                "Gefahr mit \(.applicationName) erfassen",
                "Report a hazard with \(.applicationName)",
                "Décrire un danger avec \(.applicationName)"
            ],
            shortTitle: "Report hazard",
            systemImageName: "questionmark.bubble"
        )
    }
}
#endif
