import Foundation

enum SpotifyURIParser {
    static func normalizePlaylistURI(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("spotify:playlist:") {
            let id = String(trimmed.dropFirst("spotify:playlist:".count))
            return isValidSpotifyID(id) ? "spotify:playlist:\(id)" : nil
        }

        if isValidSpotifyID(trimmed) {
            return "spotify:playlist:\(trimmed)"
        }

        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              host.contains("spotify.com") else {
            return nil
        }

        let components = url.pathComponents
        guard let playlistIndex = components.firstIndex(of: "playlist"),
              components.indices.contains(playlistIndex + 1) else {
            return nil
        }

        let rawID = components[playlistIndex + 1]
        let id = rawID.components(separatedBy: "?").first ?? rawID
        return isValidSpotifyID(id) ? "spotify:playlist:\(id)" : nil
    }

    static func playlistID(from uri: String) -> String? {
        guard uri.hasPrefix("spotify:playlist:") else { return nil }
        let id = String(uri.dropFirst("spotify:playlist:".count))
        return isValidSpotifyID(id) ? id : nil
    }

    private static func isValidSpotifyID(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics
        return value.count >= 16 && value.count <= 32 && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
