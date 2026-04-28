import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                LabeledContent("Playlist", value: appState.configuration.playlistName ?? appState.configuration.playlistUri)
                LabeledContent("Alarm time", value: appState.configuration.timeText)
                LabeledContent("Repeat", value: appState.configuration.repeatDaysText)
                LabeledContent("Shortcut volume", value: "\(appState.configuration.targetVolume)%")
                LabeledContent("Spotify", value: appState.authSummary)
                LabeledContent("Last test", value: DateHelpers.timeString(appState.configuration.lastSuccessfulRunAt))
                LabeledContent("Backup", value: appState.configuration.backupAlarmConfigured ? "Configured" : "Needs setup")
            } header: {
                Text("Active Configuration")
            } footer: {
                Text("Shortcuts controls iPhone media volume. This app starts the exact Spotify playlist on the visible iPhone Spotify device.")
            }

            if let message = appState.latestMessage {
                Section {
                    Text(message)
                        .font(.callout)
                }
            }

            Section {
                NavigationLink("Connect Spotify") {
                    SpotifyConnectionView()
                }
                NavigationLink("Choose Playlist") {
                    PlaylistSetupView()
                }
                NavigationLink("Edit Alarm") {
                    AlarmSettingsView()
                }
                Button {
                    appState.testNow()
                } label: {
                    Label(appState.isBusy ? "Testing..." : "Test Now", systemImage: "play.circle")
                }
                .disabled(appState.isBusy)

                NavigationLink("Open Shortcut Setup Guide") {
                    ShortcutSetupGuideView()
                }
                Button {
                    appState.runHealthCheck()
                } label: {
                    Label(appState.isBusy ? "Checking..." : "Run Health Check", systemImage: "checkmark.shield")
                }
                .disabled(appState.isBusy)
            }

            if let latest = appState.logs.first {
                Section("Latest Log") {
                    LabeledContent("Status", value: latest.status.rawValue.capitalized)
                    LabeledContent("Result", value: latest.summary)
                    LabeledContent("Retries", value: "\(latest.retryCount)")
                }
            }
        }
        .navigationTitle("Morning Spotify Alarm")
        .task {
            await appState.refreshAuthSummary()
        }
    }
}
