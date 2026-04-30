import SwiftUI

struct DeviceSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pendingNonIPhoneDevice: SpotifyDevice?

    private var visibleAlarmIPhone: SpotifyDevice? {
        SpotifyDeviceSelector
            .selectDevice(from: appState.visibleSpotifyDevices, preference: appState.configuration.devicePreference)
            .selectedDevice
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Preferred", value: appState.configuration.devicePreference.displayName)
                LabeledContent("Last seen", value: DateHelpers.timeString(appState.configuration.devicePreference.preferredDeviceLastSeenAt))
                LabeledContent("Visible", value: appState.preferredDeviceVisibilityText())

                Button {
                    Task { await appState.refreshSpotifyDevices() }
                } label: {
                    Label(appState.isRefreshingDevices ? "Refreshing..." : "Refresh Devices", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isRefreshingDevices)
            } header: {
                Text("Preferred Spotify Device")
            } footer: {
                Text("Spotify Connect devices can appear and disappear. The alarm targets the saved preferred iPhone device. If that device is not visible, the safe default is to fail and let the backup alarm handle wake-up.")
            }

            Section {
                LabeledContent("Currently visible", value: visibleAlarmIPhone?.name ?? "No")
                Button {
                    Task { await appState.refreshSpotifyDevices() }
                } label: {
                    Label("Check Spotify iPhone Device", systemImage: "iphone.radiowaves.left.and.right")
                }
                .disabled(appState.isRefreshingDevices)

                if visibleAlarmIPhone != nil {
                    Button {
                        Task { await appState.bindVisibleIPhoneAsAlarmDevice() }
                    } label: {
                        Label("Bind This iPhone as Alarm Device", systemImage: "target")
                    }
                }

                NavigationLink {
                    PrepareIPhoneForAlarmView()
                } label: {
                    Label("Alarm Prewarm Setup", systemImage: "music.note")
                }
            } header: {
                Text("Spotify iPhone Reliability")
            } footer: {
                Text("Spotify does not provide an official way to permanently lock playback to this iPhone. This app uses a safe prewarm and verification flow, and will not play on another device when this iPhone is missing.")
            }

            if let message = appState.latestMessage {
                Section {
                    Text(message)
                        .font(.callout)
                }
            }

            Section {
                if appState.visibleSpotifyDevices.isEmpty {
                    ContentUnavailableView("No Devices", systemImage: "speaker.slash", description: Text("Open Spotify on the iPhone, choose This iPhone, then refresh."))
                } else {
                    ForEach(Array(appState.visibleSpotifyDevices.enumerated()), id: \.offset) { _, device in
                        DeviceRow(
                            device: device,
                            isPreferred: device.id == appState.configuration.devicePreference.preferredDeviceId,
                            onSave: {
                                if device.isIPhoneLike {
                                    appState.savePreferredDevice(device)
                                } else {
                                    pendingNonIPhoneDevice = device
                                }
                            },
                            onTest: {
                                Task { await appState.playTest(on: device) }
                            }
                        )
                    }
                }
            } header: {
                Text("Visible Spotify Devices")
            } footer: {
                Text("Non-iPhone devices such as TVs, speakers, computers, web players, and Chromecast targets are shown for visibility only. The real alarm defaults to this iPhone only.")
            }
        }
        .navigationTitle("Spotify Devices")
        .task {
            if appState.visibleSpotifyDevices.isEmpty {
                await appState.refreshSpotifyDevices()
            }
        }
        .alert("Select non-iPhone device?", isPresented: Binding(
            get: { pendingNonIPhoneDevice != nil },
            set: { if !$0 { pendingNonIPhoneDevice = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingNonIPhoneDevice = nil
            }
            Button("Save Anyway", role: .destructive) {
                if let pendingNonIPhoneDevice {
                    appState.savePreferredDevice(pendingNonIPhoneDevice)
                }
                pendingNonIPhoneDevice = nil
            }
        } message: {
            Text("This device is not iPhone-like. Selecting a TV or speaker can make the alarm play somewhere else.")
        }
    }
}

private struct DeviceRow: View {
    let device: SpotifyDevice
    let isPreferred: Bool
    let onSave: () -> Void
    let onTest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                    Text(device.type)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isPreferred {
                    Label("Preferred", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    statusLabel("Active", device.isActive)
                    statusLabel("Restricted", device.isRestricted, warningWhenTrue: true)
                }
                GridRow {
                    statusLabel("Supports volume", device.supportsVolume)
                    statusLabel("iPhone-like", device.isIPhoneLike)
                }
            }
            .font(.caption)

            HStack {
                Button {
                    onSave()
                } label: {
                    Label(isPreferred ? "Saved" : "Bind This iPhone", systemImage: "target")
                }
                .buttonStyle(.bordered)
                .disabled(device.id == nil || device.isRestricted || !device.isIPhoneLike)

                Button {
                    onTest()
                } label: {
                    Label("Play Test", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(device.id == nil || device.isRestricted || !device.isIPhoneLike)
            }
        }
        .padding(.vertical, 6)
    }

    private func statusLabel(_ title: String, _ value: Bool, warningWhenTrue: Bool = false) -> some View {
        Label(value ? "Yes: \(title)" : "No: \(title)", systemImage: value ? "checkmark.circle" : "xmark.circle")
            .foregroundStyle(value && warningWhenTrue ? .red : (value ? .green : .secondary))
    }
}
