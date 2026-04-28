import AuthenticationServices
import Combine
import SwiftUI

@main
struct MorningSpotifyAlarmApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    appState.handleCallback(url)
                }
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var configuration: AlarmConfiguration
    @Published var logs: [AlarmRunLog]
    @Published var authSummary: String = "Checking..."
    @Published var isBusy = false
    @Published var latestMessage: String?

    private let store = AlarmConfigStore.shared
    private let authService = SpotifyAuthService()
    private lazy var authSessionRunner = SpotifyAuthSessionRunner(authService: authService)

    init() {
        configuration = store.loadConfiguration()
        logs = store.loadLogs()
        Task { await refreshAuthSummary() }
    }

    func reload() {
        configuration = store.loadConfiguration()
        logs = store.loadLogs()
    }

    func save(_ configuration: AlarmConfiguration) {
        store.saveConfiguration(configuration)
        reload()
    }

    func refreshAuthSummary() async {
        authSummary = await authService.connectionSummary()
    }

    func connectSpotify(prefersEphemeralSession: Bool = false) {
        isBusy = true
        latestMessage = nil
        Task {
            do {
                try await authSessionRunner.authenticate(prefersEphemeralSession: prefersEphemeralSession)
                latestMessage = "Spotify connected."
            } catch {
                latestMessage = Self.authErrorMessage(from: error)
            }
            await refreshAuthSummary()
            isBusy = false
        }
    }

    func disconnectSpotify() {
        authService.disconnect()
        latestMessage = "Local Spotify tokens cleared. Use Reconnect / Switch Account to sign in again."
        Task { await refreshAuthSummary() }
    }

    func handleCallback(_ url: URL) {
        Task {
            do {
                try await authService.handleRedirect(url)
                latestMessage = "Spotify connected."
            } catch {
                latestMessage = error.localizedDescription
            }
            await refreshAuthSummary()
        }
    }

    func testNow() {
        isBusy = true
        latestMessage = nil
        Task {
            let result = await PlaybackOrchestrator().start(source: .testNow)
            await MainActor.run {
                self.latestMessage = result.shortMessage
                self.reload()
                self.isBusy = false
            }
        }
    }

    func runHealthCheck() {
        isBusy = true
        latestMessage = nil
        Task {
            let result = await HealthCheckService().run()
            await MainActor.run {
                self.latestMessage = result.message
                self.reload()
                self.isBusy = false
            }
        }
    }

    private static func authErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            return "Spotify login canceled."
        }

        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("redirect") {
            return "Spotify rejected the redirect URI. In Spotify Developer Dashboard, add exactly: \(AppConfig.spotifyRedirectUri)"
        }
        return description
    }
}
