import SwiftUI

struct ReliabilityChecklistView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            checklistRow("Spotify auth valid", state: spotifyAuthState)
            checklistRow("Refresh token available", state: appState.authSummary == "Needs re-authentication" ? .bad : .good)
            checklistRow("Playlist valid", state: SpotifyURIParser.playlistID(from: appState.configuration.playlistUri) == nil ? .bad : .good)
            checklistRow("Preferred Spotify device saved", state: appState.configuration.devicePreference.hasPreferredDevice ? .good : .bad)
            checklistRow("Preferred Spotify device visible", state: preferredDeviceVisible ? .good : .warning)
            checklistRow("Last playback test successful", state: latestPlaybackSucceeded ? .good : .warning)
            checklistRow("Shortcut volume step confirmed", state: appState.configuration.shortcutVolumeStepConfirmed ? .good : .warning)
            checklistRow("Backup alarm configured", state: appState.configuration.backupAlarmConfigured || appState.configuration.fallbackEnabled ? .good : .warning)
            checklistRow("Last health check successful", state: latestHealthCheckSucceeded ? .good : .warning)

            Section {
                Button {
                    appState.runHealthCheck()
                } label: {
                    Label("Run Health Check", systemImage: "checkmark.shield")
                }
            }
        }
        .navigationTitle("Reliability Checklist")
        .task {
            await appState.refreshAuthSummary()
            await appState.refreshSpotifyDevices()
        }
    }

    private var spotifyAuthState: ChecklistState {
        appState.authSummary == "Connected" ? .good : .bad
    }

    private var latestPlaybackSucceeded: Bool {
        appState.logs.first { $0.source == .testNow || $0.source == .shortcut }?.status == .success
    }

    private var latestHealthCheckSucceeded: Bool {
        appState.logs.first { $0.source == .healthCheck }?.status == .success
    }

    private var preferredDeviceVisible: Bool {
        guard let preferredID = appState.configuration.devicePreference.preferredDeviceId else {
            return false
        }
        return appState.visibleSpotifyDevices.contains { $0.id == preferredID }
    }

    private func checklistRow(_ title: String, state: ChecklistState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: state.icon)
                .foregroundStyle(state.color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text(state.label)
                .foregroundStyle(state.color)
        }
    }
}

private enum ChecklistState {
    case good
    case warning
    case bad

    var icon: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .bad: "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .good: .green
        case .warning: .yellow
        case .bad: .red
        }
    }

    var label: String {
        switch self {
        case .good: "Ready"
        case .warning: "Check"
        case .bad: "Fix"
        }
    }
}
