import AuthenticationServices
import CryptoKit
import Foundation

final class SpotifyAuthService {
    private let keychain = KeychainStore.shared
    private let store = AlarmConfigStore.shared
    private let accessTokenAccount = "spotifyAccessToken"
    private let refreshTokenAccount = "spotifyRefreshToken"
    private let codeVerifierAccount = "spotifyPKCECodeVerifier"
    private let stateAccount = "spotifyOAuthState"

    func makeAuthorizationURL() throws -> URL {
        let verifier = Self.makeCodeVerifier()
        let state = Self.makeCodeVerifier()
        try keychain.save(verifier, account: codeVerifierAccount)
        try keychain.save(state, account: stateAccount)
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfig.spotifyClientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AppConfig.spotifyRedirectUri),
            URLQueryItem(name: "scope", value: AppConfig.scopesString),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "show_dialog", value: "true")
        ]

        guard let url = components?.url else {
            throw UserFacingError.spotifyAPI("Could not build Spotify login URL.")
        }
        return url
    }

    func handleRedirect(_ url: URL) async throws {
        guard url.scheme == AppConfig.appScheme else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            throw UserFacingError.spotifyAPI("Spotify login failed: \(error)")
        }
        guard let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value,
              let expectedState = try keychain.read(account: stateAccount),
              returnedState == expectedState else {
            throw UserFacingError.spotifyAPI("Spotify login state did not match. Start Spotify login again.")
        }
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw UserFacingError.spotifyAPI("Spotify callback did not include an authorization code.")
        }
        guard let verifier = try keychain.read(account: codeVerifierAccount) else {
            throw UserFacingError.spotifyAPI("Missing PKCE verifier. Start Spotify login again.")
        }

        let response = try await requestToken(parameters: [
            "client_id": AppConfig.spotifyClientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfig.spotifyRedirectUri,
            "code_verifier": verifier
        ])
        try persist(response)
        keychain.delete(account: codeVerifierAccount)
        keychain.delete(account: stateAccount)
    }

    func validAccessToken() async throws -> String {
        guard let state = store.loadAuthState() else {
            throw UserFacingError.spotifyNotConnected
        }

        if !state.isExpired, let token = try keychain.read(account: accessTokenAccount) {
            return token
        }

        return try await refreshAccessToken()
    }

    func refreshAccessToken() async throws -> String {
        guard let refreshToken = try keychain.read(account: refreshTokenAccount) else {
            throw UserFacingError.spotifyNotConnected
        }

        let response = try await requestToken(parameters: [
            "client_id": AppConfig.spotifyClientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])
        try persist(response)
        guard let accessToken = try keychain.read(account: accessTokenAccount) else {
            throw UserFacingError.tokenRefreshFailed
        }
        return accessToken
    }

    func hasRefreshToken() -> Bool {
        (try? keychain.read(account: refreshTokenAccount)) != nil
    }

    func connectionSummary() async -> String {
        guard store.loadAuthState() != nil else { return "Needs re-authentication" }
        guard hasRefreshToken() else { return "Needs re-authentication" }
        do {
            _ = try await validAccessToken()
            return "Connected"
        } catch {
            return "Token expired but refresh failed"
        }
    }

    func disconnect() {
        keychain.delete(account: accessTokenAccount)
        keychain.delete(account: refreshTokenAccount)
        keychain.delete(account: codeVerifierAccount)
        keychain.delete(account: stateAccount)
        store.clearAuthState()
    }

    private func requestToken(parameters: [String: String]) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded(parameters).data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UserFacingError.networkUnavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw UserFacingError.spotifyAPI("Spotify token endpoint did not return HTTP.")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw UserFacingError.spotifyAPI("Spotify token request failed with HTTP \(http.statusCode).")
        }

        return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    }

    private func persist(_ response: SpotifyTokenResponse) throws {
        try keychain.save(response.accessToken, account: accessTokenAccount)
        if let refreshToken = response.refreshToken {
            try keychain.save(refreshToken, account: refreshTokenAccount)
        }
        let scopes = response.scope?.split(separator: " ").map(String.init) ?? AppConfig.spotifyScopes
        store.saveAuthState(SpotifyAuthState(expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)), scopes: scopes))
    }

    private static func makeCodeVerifier() -> String {
        let bytes = (0..<64).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func formURLEncoded(_ parameters: [String: String]) -> String {
        parameters
            .map { key, value in "\(escape(key))=\(escape(value))" }
            .joined(separator: "&")
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
