import SwiftUI
import UIKit

struct ShortcutSetupGuideView: View {
    @EnvironmentObject private var appState: AppState
    @State private var copied = false

    private var instructions: String {
        """
        Morning Spotify Alarm Shortcut Setup

        Automation: Time of Day
        Repeat: \(appState.configuration.repeatDaysText)
        Run: Run Immediately

        Actions:
        1. Set Volume to \(appState.configuration.targetVolume)%.
        2. Run App Shortcut: Start Morning Spotify Alarm.
        3. Wait 2 seconds.
        4. Optional: Set Volume to \(appState.configuration.targetVolume)% again.

        Do not add Open Spotify URL.
        Do not add Play/Pause.
        """
    }

    var body: some View {
        List {
            Section("Automation") {
                guideRow("Time of Day", "Choose \(appState.configuration.timeText).")
                guideRow("Repeat", appState.configuration.repeatDaysText)
                guideRow("Run Immediately", "Disable confirmation prompts if iOS offers the option.")
            }

            Section("Actions") {
                guideRow("1. Set Volume", "Set iPhone media volume to \(appState.configuration.targetVolume)%.")
                guideRow("2. Run App Shortcut", "Choose Start Morning Spotify Alarm.")
                guideRow("3. Wait", "Wait 2 seconds.")
                guideRow("4. Optional Set Volume", "Set iPhone media volume to \(appState.configuration.targetVolume)% again.")
            }

            Section {
                Text("Do not use Open Spotify URL or Play/Pause. URL opening only opens the playlist, and Play/Pause can resume previous Spotify content.")
                    .font(.callout)
                Button {
                    UIPasteboard.general.string = instructions
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy Shortcut Instructions", systemImage: "doc.on.doc")
                }
            } footer: {
                Text("Shortcuts is the reliable time trigger and the only system-volume controller in this setup.")
            }
        }
        .navigationTitle("Shortcut Setup")
    }

    private func guideRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
