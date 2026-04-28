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
                Text("The app does not control iPhone system volume. Add Shortcuts Set Volume before the App Intent.")
            }

            Section {
                Toggle("Enable Spotify playback", isOn: $draft.spotifyPlaybackEnabled)
                Toggle("Enable playback retry", isOn: $draft.retryEnabled)
                Toggle("Allow non-iPhone fallback", isOn: $draft.allowNonIPhoneDeviceFallback)
                Toggle("Advanced Spotify-device volume", isOn: $draft.advancedSpotifyVolumeEnabled)
            } header: {
                Text("Playback")
            } footer: {
                Text("Keep non-iPhone fallback off for the real alarm unless Spotify is mislabeling your iPhone. Otherwise the app may start playback on a TV or speaker.")
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
