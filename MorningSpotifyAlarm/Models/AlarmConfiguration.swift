import Foundation

struct AlarmConfiguration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Morning Spotify Alarm"
    var enabled: Bool = true
    var hour: Int = 7
    var minute: Int = 0
    var repeatDays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    var playlistUri: String = AppConfig.defaultPlaylistUri
    var playlistName: String? = "Alarm Clock"
    var playlistOwner: String?
    var playlistImageUrl: String?
    var targetVolume: Int = 70
    var spotifyPlaybackEnabled: Bool = true
    var retryEnabled: Bool = true
    var allowNonIPhoneDeviceFallback: Bool = false
    var advancedSpotifyVolumeEnabled: Bool = false
    var fallbackEnabled: Bool = true
    var fallbackDelayMinutes: Int = 2
    var shortcutVolumeStepConfirmed: Bool = false
    var backupAlarmConfigured: Bool = false
    var lastHealthCheckAt: Date?
    var lastSuccessfulRunAt: Date?

    var timeText: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatDaysText: String {
        repeatDays.isEmpty ? "Once" : repeatDays.map(\.shortName).joined(separator: ", ")
    }
}
