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
                        if let finalStatus = log.finalStatus {
                            LabeledContent("Final status", value: finalStatus.rawValue)
                        }
                        LabeledContent("Playlist", value: log.playlistUri)
                        LabeledContent("Target Shortcut volume", value: "\(log.targetVolume)%")
                        LabeledContent("Scheduled alarm", value: log.scheduledAlarmTime ?? "Unknown")
                        LabeledContent("Prewarm expected", value: log.shortcutPrewarmExpected ? "Yes" : "No")
                        if let prewarmStartedAt = log.prewarmStartedAt {
                            LabeledContent("Prewarm started", value: DateHelpers.timeString(prewarmStartedAt))
                        }
                        LabeledContent("Device fetch attempts", value: "\(log.devicesFetchAttempts)")
                        if let preferredDeviceName = log.preferredDeviceName {
                            LabeledContent("Preferred device", value: preferredDeviceName)
                        }
                        if let deviceName = log.selectedDeviceName {
                            LabeledContent("Device", value: deviceName)
                        }
                        if let selectedDeviceType = log.selectedDeviceType {
                            LabeledContent("Device type", value: selectedDeviceType)
                        }
                        if let selectedDeviceIdHash = log.selectedDeviceIdHash {
                            LabeledContent("Device ID hash", value: selectedDeviceIdHash)
                        }
                        if let supportsVolume = log.selectedDeviceSupportsVolume {
                            LabeledContent("Spotify volume support", value: supportsVolume ? "Yes" : "No")
                        }
                        if let reason = log.deviceSelectionReason {
                            LabeledContent("Selection reason", value: reason.rawValue)
                        }
                        LabeledContent("Used fallback", value: log.usedFallbackDevice ? "Yes" : "No")
                        LabeledContent("Retries", value: "\(log.retryCount)")
                        if let tokenRefreshResult = log.tokenRefreshResult {
                            LabeledContent("Token", value: tokenRefreshResult)
                        }
                        if let transferResult = log.transferResult {
                            LabeledContent("Transfer", value: transferResult)
                        }
                        if let activeDeviceAfterTransfer = log.activeDeviceAfterTransfer {
                            Text("After transfer: \(activeDeviceAfterTransfer)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let playResult = log.playResult {
                            LabeledContent("Play", value: playResult)
                        }
                        if let activeDeviceAfterPlay = log.activeDeviceAfterPlay {
                            Text("After play: \(activeDeviceAfterPlay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let isPlayingAfterPlay = log.isPlayingAfterPlay {
                            LabeledContent("Playing after play", value: isPlayingAfterPlay ? "Yes" : "No")
                        }
                        if let visibleDeviceSummary = log.visibleDeviceSummary {
                            Text(visibleDeviceSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
