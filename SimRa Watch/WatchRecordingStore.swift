import Foundation

@MainActor
final class WatchRecordingStore: ObservableObject {
    @Published private(set) var isRecording = false

    private let defaults = UserDefaults(
        suiteName: "group.de.tu-berlin.mcc.simra"
    ) ?? .standard

    init() {
        refresh()
    }

    func refresh() {
        isRecording = defaults.bool(forKey: "isRecording")
    }

    func toggleRecording() {
        if isRecording {
            defaults.set("stop", forKey: "pendingRecordingCommand")
        } else {
            defaults.set("start", forKey: "pendingRecordingCommand")
        }

        isRecording.toggle()
    }

    func markIncident() {
        var events = defaults.array(
            forKey: "liveActivityIncidentEvents"
        ) as? [[String: Any]] ?? []

        events.append([
            "id": UUID().uuidString,
            "tripId": 0,
            "incidentType": 0,
            "timestamp": Date().timeIntervalSince1970,
            "source": "Watch",
            "participantMask": 0
        ])

        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }

        defaults.set(events, forKey: "liveActivityIncidentEvents")
        defaults.set(
            events.count,
            forKey: "pendingLiveActivityIncidents"
        )
    }
}
