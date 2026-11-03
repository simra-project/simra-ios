// currently not implemented
 
import SwiftUI

@main
struct SimRaWatchApp: App {
    @StateObject private var store = WatchRecordingStore()

    var body: some Scene {
        WindowGroup {
            WatchRecordingView(store: store)
        }
    }
}

private struct WatchRecordingView: View {
    @ObservedObject var store: WatchRecordingStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bicycle")
                .font(.title2)
                .foregroundStyle(.tint)

            Text("SimRa")
                .font(.headline)

            Button {
                store.markIncident()
            } label: {
                Label(
                    "Mark hazard",
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
            .tint(.orange)
            .disabled(!store.isRecording)

            Button {
                store.toggleRecording()
            } label: {
                Label(
                    store.isRecording ? "Stop" : "Start",
                    systemImage: store.isRecording
                        ? "stop.fill"
                        : "record.circle"
                )
            }
            .tint(store.isRecording ? .red : .green)
        }
        .padding()
        .containerBackground(.regularMaterial, for: .watch)
        .task {
            store.refresh()
        }
    }
}
