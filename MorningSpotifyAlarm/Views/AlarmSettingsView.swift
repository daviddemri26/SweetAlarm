import SwiftUI

struct AlarmSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft = AlarmConfiguration()
    @State private var backupMessage: String?

    var body: some View {
        Form {
            Section("Schedule") {
                DatePicker(
                    "Alarm time",
                    selection: Binding(
                        get: { dateFromDraft() },
                        set: { updateTime(from: $0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                Toggle("Enabled", isOn: $draft.enabled)
                repeatDaysPicker
            }

            Section {
                Slider(value: Binding(get: {
                    Double(draft.targetVolume)
                }, set: {
                    draft.targetVolume = Int($0.rounded())
                }), in: 0...100, step: 1)
                LabeledContent("Shortcut volume", value: "\(draft.targetVolume)%")
            } header: {
                Text("iPhone Volume")
            } footer: {
                Text("The app does not control iPhone system volume. The Shortcut should set volume to 0% for Spotify prewarm, then set this target volume immediately before Start Morning Spotify Alarm.")
            }

            Section {
                Toggle("Enable Spotify playback", isOn: $draft.spotifyPlaybackEnabled)
                Toggle("Enable playback retry", isOn: $draft.retryEnabled)
                Toggle("Require preferred device", isOn: $draft.devicePreference.requirePreferredDevice)
                Toggle("Allow automatic iPhone fallback", isOn: $draft.devicePreference.allowAutomaticIPhoneFallback)
                Toggle("Allow non-iPhone fallback", isOn: $draft.devicePreference.allowNonIPhoneFallback)
                Toggle("Advanced Spotify-device volume", isOn: $draft.advancedSpotifyVolumeEnabled)
            } header: {
                Text("Playback")
            } footer: {
                Text("Keep Require preferred device on. The verified alarm route defaults to this iPhone only and fails closed instead of playing on a TV, speaker, computer, web player, or Chromecast. Spotify volume is skipped for iPhone devices that report supports_volume=false.")
            }

            Section {
                Toggle("Enable backup alarm", isOn: $draft.fallbackEnabled)
                Stepper("Delay: \(draft.fallbackDelayMinutes) min", value: $draft.fallbackDelayMinutes, in: 1...10)
                Toggle("Shortcut volume step confirmed", isOn: $draft.shortcutVolumeStepConfirmed)
                Toggle("Backup alarm configured", isOn: $draft.backupAlarmConfigured)
                Button {
                    scheduleBackup()
                } label: {
                    Label("Schedule AlarmKit Backup", systemImage: "bell.badge")
                }
                if let backupMessage {
                    Text(backupMessage)
                        .font(.callout)
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("AlarmKit is a safety fallback only. A regular Clock alarm at +2 minutes is still a good backup for overnight use.")
            }

            Section {
                Button {
                    draft.allowNonIPhoneDeviceFallback = draft.devicePreference.allowNonIPhoneFallback
                    appState.save(draft)
                } label: {
                    Label("Save Settings", systemImage: "checkmark.circle")
                }
            }
        }
        .navigationTitle("Edit Alarm")
        .onAppear {
            draft = appState.configuration
        }
    }

    private var repeatDaysPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat Days")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Weekday.allCases) { day in
                    Button {
                        if draft.repeatDays.contains(day) {
                            draft.repeatDays.removeAll { $0 == day }
                        } else {
                            draft.repeatDays.append(day)
                            draft.repeatDays.sort { $0.rawValue < $1.rawValue }
                        }
                    } label: {
                        Text(day.shortName)
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.repeatDays.contains(day) ? .green : .gray)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dateFromDraft() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = draft.hour
        components.minute = draft.minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func updateTime(from date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        draft.hour = components.hour ?? draft.hour
        draft.minute = components.minute ?? draft.minute
    }

    private func scheduleBackup() {
        appState.save(draft)
        Task {
            do {
                let message = try await BackupAlarmService().scheduleBackup(for: draft)
                await MainActor.run {
                    draft.backupAlarmConfigured = true
                    appState.save(draft)
                    backupMessage = message
                }
            } catch {
                await MainActor.run {
                    backupMessage = error.localizedDescription
                }
            }
        }
    }
}
