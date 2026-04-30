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
                LabeledContent("Preferred device", value: appState.configuration.devicePreference.displayName)
                LabeledContent("Preferred last seen", value: DateHelpers.timeString(appState.configuration.devicePreference.preferredDeviceLastSeenAt))
                LabeledContent("Preferred visibility", value: appState.preferredDeviceVisibilityText())
                LabeledContent("Preferred test", value: DateHelpers.timeString(appState.configuration.devicePreference.lastSuccessfulPreferredDeviceTestAt))
                LabeledContent("Last test", value: DateHelpers.timeString(appState.configuration.lastSuccessfulRunAt))
                LabeledContent("Backup", value: appState.configuration.backupAlarmConfigured ? "Configured" : "Needs setup")
            } header: {
                Text("Active Configuration")
            } footer: {
                Text("Shortcuts controls iPhone media volume. This app starts Spotify on the saved preferred device. If the preferred iPhone is not visible, the safe default is to fail and let the backup alarm handle wake-up.")
            }

            if appState.preferredDeviceVisibilityText() == "Not visible" {
                Section {
                    Text("Run the prewarm Shortcut or open Spotify on this iPhone and play briefly to make it visible to Spotify Connect.")
                        .foregroundStyle(.yellow)
                }
            }

            Section {
                LabeledContent("Preferred iPhone", value: appState.configuration.devicePreference.displayName)
                LabeledContent("Visible now", value: appState.preferredDeviceVisibilityText())
                Button {
                    Task { await appState.refreshSpotifyDevices() }
                } label: {
                    Label("Check Spotify iPhone Device", systemImage: "iphone.radiowaves.left.and.right")
                }
                .disabled(appState.isRefreshingDevices)
                Button {
                    Task { await appState.bindVisibleIPhoneAsAlarmDevice() }
                } label: {
                    Label("Bind This iPhone as Alarm Device", systemImage: "target")
                }
                .disabled(appState.visibleSpotifyDevices.isEmpty)
            } header: {
                Text("Spotify iPhone Reliability")
            } footer: {
                Text("Spotify cannot permanently lock playback to this iPhone. The alarm uses a silent prewarm and verified fail-closed playback route.")
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
                NavigationLink("Preferred Spotify Device") {
                    DeviceSelectionView()
                }
                NavigationLink("Alarm Prewarm Setup") {
                    PrepareIPhoneForAlarmView()
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

                NavigationLink {
                    DiagnosticReportView()
                } label: {
                    Label("Run Diagnostic Report", systemImage: "stethoscope")
                }
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
            await appState.refreshSpotifyDevices()
        }
    }
}
