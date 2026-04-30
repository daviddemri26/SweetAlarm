import Foundation

struct PlaybackRunResult {
    let status: AlarmRunStatus
    let shortMessage: String
    let log: AlarmRunLog
}

final class PlaybackOrchestrator {
    func start(source: AlarmRunSource) async -> PlaybackRunResult {
        await SpotifyAlarmRouteManager().startAlarm(source: source, shortcutPrewarmExpected: source == .shortcut)
    }

    static func verifyPlayback(client: SpotifyAPIClient, deviceID: String, playlistURI: String) async throws -> Bool {
        let state = try await client.playbackState()
        return SpotifyAlarmRouteManager().verifyAlarmPlayback(state, deviceId: deviceID, playlistUri: playlistURI)
    }
}
