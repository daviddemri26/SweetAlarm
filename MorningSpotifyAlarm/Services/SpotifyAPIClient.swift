import Foundation

struct SpotifyDevice: Codable, Identifiable, Equatable {
    let id: String?
    let isActive: Bool
    let isPrivateSession: Bool
    let isRestricted: Bool
    let name: String
    let type: String
    let supportsVolume: Bool
    let volumePercent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case isActive = "is_active"
        case isPrivateSession = "is_private_session"
        case isRestricted = "is_restricted"
        case name
        case type
        case supportsVolume = "supports_volume"
        case volumePercent = "volume_percent"
    }

    var isIPhoneLike: Bool {
        name.localizedCaseInsensitiveContains("iphone") || type.localizedCaseInsensitiveContains("smartphone")
    }
}

struct SpotifyPlaybackState: Decodable {
    struct Context: Decodable {
        let uri: String?
    }

    let isPlaying: Bool
    let device: SpotifyDevice?
    let context: Context?

    enum CodingKeys: String, CodingKey {
        case isPlaying = "is_playing"
        case device
        case context
    }
}

struct SpotifyPlaylistMetadata: Decodable {
    struct Owner: Decodable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    struct Image: Decodable {
        let url: String
    }

    let name: String
    let owner: Owner
    let images: [Image]
}

final class SpotifyAPIClient {
    private let accessToken: String
    private let baseURL = URL(string: "https://api.spotify.com/v1")!

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func devices() async throws -> [SpotifyDevice] {
        struct Response: Decodable { let devices: [SpotifyDevice] }
        let response: Response = try await send(path: "/me/player/devices")
        return response.devices
    }

    func startPlayback(deviceID: String, contextURI: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/me/player/play"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
        guard let url = components.url else { throw UserFacingError.spotifyAPI("Invalid playback URL.") }
        var request = authorizedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["context_uri": contextURI])
        try await sendWithoutBody(request)
    }

    func transferPlayback(deviceID: String, play: Bool) async throws {
        let url = baseURL.appendingPathComponent("/me/player")
        var request = authorizedRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TransferPlaybackRequest(deviceIds: [deviceID], play: play))
        try await sendWithoutBody(request)
    }

    func pausePlayback(deviceID: String) async throws {
        var components = URLComponents(url: baseURL.appendingPathComponent("/me/player/pause"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "device_id", value: deviceID)]
        guard let url = components.url else { throw UserFacingError.spotifyAPI("Invalid pause URL.") }
        var request = authorizedRequest(url: url)
        request.httpMethod = "PUT"
        try await sendWithoutBody(request)
    }


    func playbackState() async throws -> SpotifyPlaybackState? {
        let request = authorizedRequest(url: baseURL.appendingPathComponent("/me/player"))
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UserFacingError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw UserFacingError.spotifyAPI("Spotify playback state did not return HTTP.")
        }

        if http.statusCode == 204 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw mapSpotifyError(statusCode: http.statusCode, data: data)
        }
        return try JSONDecoder().decode(SpotifyPlaybackState.self, from: data)
    }

    func playlistMetadata(playlistID: String) async throws -> SpotifyPlaylistMetadata {
        try await send(path: "/playlists/\(playlistID)")
    }

    func setVolumeIfSupported(device: SpotifyDevice, percent: Int) async throws {
        guard device.supportsVolume, let id = device.id else { return }
        var components = URLComponents(url: baseURL.appendingPathComponent("/me/player/volume"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "volume_percent", value: String(max(0, min(100, percent)))),
            URLQueryItem(name: "device_id", value: id)
        ]
        guard let url = components.url else { return }
        var request = authorizedRequest(url: url)
        request.httpMethod = "PUT"
        try await sendWithoutBody(request)
    }

    private func send<T: Decodable>(path: String) async throws -> T {
        let request = authorizedRequest(url: baseURL.appendingPathComponent(path))
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UserFacingError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw UserFacingError.spotifyAPI("Spotify API did not return HTTP.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapSpotifyError(statusCode: http.statusCode, data: data)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sendWithoutBody(_ request: URLRequest) async throws {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UserFacingError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw UserFacingError.spotifyAPI("Spotify API did not return HTTP.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapSpotifyError(statusCode: http.statusCode, data: data)
        }
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func mapSpotifyError(statusCode: Int, data: Data) -> Error {
        if statusCode == 403 { return UserFacingError.premiumRequired }
        if statusCode == 429 { return UserFacingError.rateLimited }
        if let response = try? JSONDecoder().decode(SpotifyErrorResponse.self, from: data) {
            return UserFacingError.spotifyAPI(response.error.message)
        }
        return UserFacingError.spotifyAPI("Spotify API failed with HTTP \(statusCode).")
    }
}

private struct TransferPlaybackRequest: Encodable {
    let deviceIds: [String]
    let play: Bool

    enum CodingKeys: String, CodingKey {
        case deviceIds = "device_ids"
        case play
    }
}

private struct SpotifyErrorResponse: Decodable {
    struct Body: Decodable {
        let status: Int
        let message: String
    }

    let error: Body
}
