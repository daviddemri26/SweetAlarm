import AppIntents

struct MorningSpotifyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMorningSpotifyAlarmIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Start Morning Spotify Alarm with \(.applicationName)"
            ],
            shortTitle: "Start Alarm",
            systemImageName: "music.note"
        )

        AppShortcut(
            intent: RunMorningAlarmHealthCheckIntent(),
            phrases: [
                "Check \(.applicationName)",
                "Run Morning Alarm Health Check with \(.applicationName)"
            ],
            shortTitle: "Health Check",
            systemImageName: "checkmark.shield"
        )
    }
}
