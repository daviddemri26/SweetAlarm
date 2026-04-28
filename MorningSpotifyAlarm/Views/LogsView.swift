import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            if appState.logs.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "list.bullet.rectangle", description: Text("Run Test Now or Health Check to create logs."))
            } else {
                ForEach(appState.logs) { log in
                    Section {
                        LabeledContent("Started", value: DateHelpers.timeString(log.startedAt))
                        LabeledContent("Source", value: log.source.rawValue)
                        LabeledContent("Status", value: log.status.rawValue.capitalized)
                        LabeledContent("Playlist", value: log.playlistUri)
                        LabeledContent("Target Shortcut volume", value: "\(log.targetVolume)%")
                        if let deviceName = log.selectedDeviceName {
                            LabeledContent("Device", value: deviceName)
                        }
                        if let supportsVolume = log.selectedDeviceSupportsVolume {
                            LabeledContent("Spotify volume support", value: supportsVolume ? "Yes" : "No")
                        }
                        LabeledContent("Retries", value: "\(log.retryCount)")
                        if let error = log.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text(log.summary)
                    }
                }
            }
        }
        .navigationTitle("Logs")
        .toolbar {
            Button {
                appState.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }
}
