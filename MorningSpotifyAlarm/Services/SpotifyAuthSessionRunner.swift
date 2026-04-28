import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class SpotifyAuthSessionRunner: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let authService: SpotifyAuthService
    private var session: ASWebAuthenticationSession?

    init(authService: SpotifyAuthService) {
        self.authService = authService
    }

    func authenticate(prefersEphemeralSession: Bool) async throws {
        let authorizationURL = try authService.makeAuthorizationURL()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: AppConfig.appScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.session = nil

                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: UserFacingError.spotifyAPI("Spotify login did not return a callback URL."))
                        return
                    }

                    do {
                        try await self?.authService.handleRedirect(callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = prefersEphemeralSession
            self.session = session

            if !session.start() {
                self.session = nil
                continuation.resume(throwing: UserFacingError.spotifyAPI("Could not start Spotify login session."))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let keyWindow = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return keyWindow
        }

        if let scene = scenes.first {
            return ASPresentationAnchor(windowScene: scene)
        }

        preconditionFailure("Spotify login requires an active window scene.")
    }
}
