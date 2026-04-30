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
        1. Optional: Run App Shortcut: Mark Spotify Prewarm Started.
        2. Set Volume to 0%.
        3. Open App: Spotify.
        4. Play media or resume playback in Spotify.
        5. Wait 8 seconds.
        6. Set Volume to \(appState.configuration.targetVolume)%.
        7. Run App Shortcut: Start Morning Spotify Alarm.

        The first Spotify playback is only a silent prewarm. The app chooses the real playlist later and will fail closed if this iPhone is not verified.
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
                guideRow("1. Optional Mark Prewarm", "Run Mark Spotify Prewarm Started.")
                guideRow("2. Set Volume", "Set iPhone media volume to 0%.")
                guideRow("3. Open Spotify", "Open App: Spotify.")
                guideRow("4. Start Spotify Playback", "Use Play media, Resume playback, or any reliable Siri/Spotify action.")
                guideRow("5. Wait", "Wait 8 seconds.")
                guideRow("6. Set Alarm Volume", "Set iPhone media volume to \(appState.configuration.targetVolume)%.")
                guideRow("7. Run App Shortcut", "Choose Start Morning Spotify Alarm.")
            }

            Section {
                Text("The first playback is only a silent prewarm. The real alarm playlist is selected later by the app through Spotify Web API.")
                    .font(.callout)
                Text("The app still verifies and transfers playback to this iPhone before final playback. It never trusts the current active Spotify device.")
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
