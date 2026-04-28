import Foundation

enum AppConfig {
    static let spotifyClientId = "569bdbf9ce1b47fd87da2adc41793143"
    static let appScheme = "morningspotifyalarm"
    static let spotifyRedirectUri = "morningspotifyalarm://callback"
    static let defaultPlaylistUri = "spotify:playlist:3EYSOl9YotgAxH92H2nhYe"

    static let spotifyScopes = [
        "user-modify-playback-state",
        "user-read-playback-state",
        "user-read-currently-playing",
        "playlist-read-private",
        "playlist-read-collaborative"
    ]

    static var scopesString: String {
        spotifyScopes.joined(separator: " ")
    }
}
