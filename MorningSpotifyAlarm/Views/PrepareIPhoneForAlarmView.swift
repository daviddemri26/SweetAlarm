import SwiftUI
import UIKit

struct PrepareIPhoneForAlarmView: View {
    @EnvironmentObject private var appState: AppState

    private var iPhoneLikeDevices: [SpotifyDevice] {
        appState.visibleSpotifyDevices.filter { $0.isIPhoneLike && !$0.isRestricted && $0.id != nil }
    }

    private var preferredDevice: SpotifyDevice? {
        guard let preferredID = appState.configuration.devicePreference.preferredDeviceId else {
            return nil
        }
        return appState.visibleSpotifyDevices.first { $0.id == preferredID }
    }

    var body: some View {
        List {
            Section {
                instructionRow("1. Install and sign in", "Make sure Spotify is installed on this iPhone and logged in.")
                instructionRow("2. Silent prewarm", "The Shortcut sets volume to 0%, opens Spotify, and starts any playback briefly.")
                instructionRow("3. Verified alarm", "The app then checks Spotify Connect, transfers to this iPhone, verifies it, and starts the real playlist with an explicit device ID.")
                instructionRow("4. Fail closed", "If this iPhone is not available, the app will not play on another Spotify device.")
            } header: {
                Text("Alarm Prewarm")
            } footer: {
                Text("Spotify does not provide an official way to permanently lock playback to this iPhone. This app uses a safe prewarm and verification flow.")
            }

            Section {
                Button {
                    openSpotify()
                } label: {
                    Label("Open Spotify", systemImage: "music.note")
                }

                Button {
                    Task { await appState.refreshSpotifyDevices() }
                } label: {
                    Label(appState.isRefreshingDevices ? "Refreshing..." : "Refresh Devices", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isRefreshingDevices)
            } header: {
                Text("Prepare iPhone")
            } footer: {
                Text("During the Shortcut prewarm, the first Spotify playback is intentionally silent and can be any song. Shortcuts must set the alarm volume immediately before running Start Morning Spotify Alarm.")
            }

            Section {
                if iPhoneLikeDevices.isEmpty {
                    Text("No iPhone-like Spotify device is visible yet.")
                        .foregroundStyle(.yellow)
                } else {
                    ForEach(Array(iPhoneLikeDevices.enumerated()), id: \.offset) { _, device in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(device.name)
                                .font(.headline)
                            Text(deviceDetailText(device))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Button {
                                    appState.savePreferredDevice(device)
                                } label: {
                                    Label("Bind This iPhone as Alarm Device", systemImage: "target")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    appState.savePreferredDevice(device)
                                    Task { await appState.playTest(on: device) }
                                } label: {
                                    Label("Save and Test", systemImage: "play.circle")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Visible iPhone-like Devices")
            }

            Section {
                LabeledContent("Preferred", value: appState.configuration.devicePreference.displayName)
                LabeledContent("Last seen", value: DateHelpers.timeString(appState.configuration.devicePreference.preferredDeviceLastSeenAt))
                LabeledContent("Last successful test", value: DateHelpers.timeString(appState.configuration.devicePreference.lastSuccessfulPreferredDeviceTestAt))

                if let preferredDevice {
                    Button {
                        Task { await appState.playTest(on: preferredDevice) }
                    } label: {
                        Label("Run Preferred Device Test", systemImage: "checkmark.circle")
                    }
                }
            } header: {
                Text("Preferred Device Test")
            } footer: {
                Text("Spotify reports iPhone devices with supports_volume=false, so this app skips Spotify volume control for iPhone and relies on Shortcuts Set Volume.")
            }

            if let message = appState.latestMessage {
                Section {
                    Text(message)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("Prepare iPhone")
        .task {
            if appState.visibleSpotifyDevices.isEmpty {
                await appState.refreshSpotifyDevices()
            }
        }
    }

    private func openSpotify() {
        guard let url = URL(string: "spotify://") else { return }
        UIApplication.shared.open(url)
    }

    private func deviceDetailText(_ device: SpotifyDevice) -> String {
        "\(device.type) - active=\(device.isActive) - supports_volume=\(device.supportsVolume)"
    }

    private func instructionRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}
