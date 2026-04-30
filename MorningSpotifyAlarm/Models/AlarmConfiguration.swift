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
    var devicePreference: DevicePreference = DevicePreference()
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

    init() {}

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enabled
        case hour
        case minute
        case repeatDays
        case playlistUri
        case playlistName
        case playlistOwner
        case playlistImageUrl
        case targetVolume
        case spotifyPlaybackEnabled
        case retryEnabled
        case devicePreference
        case allowNonIPhoneDeviceFallback
        case advancedSpotifyVolumeEnabled
        case fallbackEnabled
        case fallbackDelayMinutes
        case shortcutVolumeStepConfirmed
        case backupAlarmConfigured
        case lastHealthCheckAt
        case lastSuccessfulRunAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Morning Spotify Alarm"
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        hour = try container.decodeIfPresent(Int.self, forKey: .hour) ?? 7
        minute = try container.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        repeatDays = try container.decodeIfPresent([Weekday].self, forKey: .repeatDays) ?? [.monday, .tuesday, .wednesday, .thursday, .friday]
        playlistUri = try container.decodeIfPresent(String.self, forKey: .playlistUri) ?? AppConfig.defaultPlaylistUri
        playlistName = try container.decodeIfPresent(String.self, forKey: .playlistName) ?? "Alarm Clock"
        playlistOwner = try container.decodeIfPresent(String.self, forKey: .playlistOwner)
        playlistImageUrl = try container.decodeIfPresent(String.self, forKey: .playlistImageUrl)
        targetVolume = try container.decodeIfPresent(Int.self, forKey: .targetVolume) ?? 70
        spotifyPlaybackEnabled = try container.decodeIfPresent(Bool.self, forKey: .spotifyPlaybackEnabled) ?? true
        retryEnabled = try container.decodeIfPresent(Bool.self, forKey: .retryEnabled) ?? true
        allowNonIPhoneDeviceFallback = try container.decodeIfPresent(Bool.self, forKey: .allowNonIPhoneDeviceFallback) ?? false
        let decodedDevicePreference = try container.decodeIfPresent(DevicePreference.self, forKey: .devicePreference)
        devicePreference = decodedDevicePreference ?? {
            var preference = DevicePreference()
            preference.allowNonIPhoneFallback = allowNonIPhoneDeviceFallback
            return preference
        }()
        advancedSpotifyVolumeEnabled = try container.decodeIfPresent(Bool.self, forKey: .advancedSpotifyVolumeEnabled) ?? false
        fallbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .fallbackEnabled) ?? true
        fallbackDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .fallbackDelayMinutes) ?? 2
        shortcutVolumeStepConfirmed = try container.decodeIfPresent(Bool.self, forKey: .shortcutVolumeStepConfirmed) ?? false
        backupAlarmConfigured = try container.decodeIfPresent(Bool.self, forKey: .backupAlarmConfigured) ?? false
        lastHealthCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastHealthCheckAt)
        lastSuccessfulRunAt = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulRunAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(hour, forKey: .hour)
        try container.encode(minute, forKey: .minute)
        try container.encode(repeatDays, forKey: .repeatDays)
        try container.encode(playlistUri, forKey: .playlistUri)
        try container.encodeIfPresent(playlistName, forKey: .playlistName)
        try container.encodeIfPresent(playlistOwner, forKey: .playlistOwner)
        try container.encodeIfPresent(playlistImageUrl, forKey: .playlistImageUrl)
        try container.encode(targetVolume, forKey: .targetVolume)
        try container.encode(spotifyPlaybackEnabled, forKey: .spotifyPlaybackEnabled)
        try container.encode(retryEnabled, forKey: .retryEnabled)
        try container.encode(devicePreference, forKey: .devicePreference)
        try container.encode(devicePreference.allowNonIPhoneFallback, forKey: .allowNonIPhoneDeviceFallback)
        try container.encode(advancedSpotifyVolumeEnabled, forKey: .advancedSpotifyVolumeEnabled)
        try container.encode(fallbackEnabled, forKey: .fallbackEnabled)
        try container.encode(fallbackDelayMinutes, forKey: .fallbackDelayMinutes)
        try container.encode(shortcutVolumeStepConfirmed, forKey: .shortcutVolumeStepConfirmed)
        try container.encode(backupAlarmConfigured, forKey: .backupAlarmConfigured)
        try container.encodeIfPresent(lastHealthCheckAt, forKey: .lastHealthCheckAt)
        try container.encodeIfPresent(lastSuccessfulRunAt, forKey: .lastSuccessfulRunAt)
    }
}
