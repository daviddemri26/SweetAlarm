import Foundation

struct SpotifyAuthState: Codable, Equatable {
    var expiresAt: Date
    var scopes: [String]

    var isExpired: Bool {
        Date().addingTimeInterval(60) >= expiresAt
    }
}
