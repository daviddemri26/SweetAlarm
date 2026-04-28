import AppIntents
import Foundation

struct StartMorningSpotifyAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Morning Spotify Alarm"
    static var description = IntentDescription("Starts the configured Spotify playlist on the visible iPhone Spotify device.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await PlaybackOrchestrator().start(source: .shortcut)
        return .result(dialog: "\(result.shortMessage)")
    }
}
