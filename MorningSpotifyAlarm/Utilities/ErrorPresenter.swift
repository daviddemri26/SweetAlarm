import Foundation

enum UserFacingError: LocalizedError {
    case spotifyNotConnected
    case tokenRefreshFailed
    case noPlaylistConfigured
    case invalidPlaylistURI
    case premiumRequired
    case noIPhoneDeviceFound
    case spotifyDeviceUnavailable
    case rateLimited
    case networkUnavailable
    case playbackNotConfirmed
    case shortcutVolumeNotConfigured
    case spotifyAPI(String)

    var errorDescription: String? {
        switch self {
        case .spotifyNotConnected:
            "Spotify is not connected."
        case .tokenRefreshFailed:
            "Spotify token refresh failed. Reconnect Spotify."
        case .noPlaylistConfigured:
            "No playlist is configured."
        case .invalidPlaylistURI:
            "The Spotify playlist URI is invalid."
        case .premiumRequired:
            "Spotify Premium is required for Web API playback control."
        case .noIPhoneDeviceFound:
            "No iPhone Spotify device is visible. Open Spotify on the iPhone, start playback on This iPhone, then try again."
        case .spotifyDeviceUnavailable:
            "Spotify device unavailable. Open Spotify once and run Test Now."
        case .rateLimited:
            "Spotify rate limit reached. Try again shortly."
        case .networkUnavailable:
            "Network unavailable."
        case .playbackNotConfirmed:
            "Playback command was sent but Spotify did not confirm playback."
        case .shortcutVolumeNotConfigured:
            "Shortcut volume step is not confirmed."
        case .spotifyAPI(let message):
            message
        }
    }
}
