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
    @Published var isRefreshingDevices = false
    @Published var hasRefreshedSpotifyDevices = false
    @Published var visibleSpotifyDevices: [SpotifyDevice] = []
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

    func refreshSpotifyDevices() async {
        isRefreshingDevices = true
        defer { isRefreshingDevices = false }

        do {
            let token = try await authService.validAccessToken()
            let devices = try await SpotifyAPIClient(accessToken: token).devices()
            visibleSpotifyDevices = devices
            hasRefreshedSpotifyDevices = true

            var updatedConfiguration = configuration
            let selection = SpotifyDeviceSelector.selectDevice(from: devices, preference: updatedConfiguration.devicePreference)
            if selection.preferredDeviceVisible {
                updatedConfiguration.devicePreference.preferredDeviceLastSeenAt = Date()
                save(updatedConfiguration)
            }
            latestMessage = devices.isEmpty ? "No Spotify Connect devices are visible." : "Found \(devices.count) Spotify device(s)."
        } catch {
            hasRefreshedSpotifyDevices = true
            latestMessage = error.localizedDescription
        }
    }

    func savePreferredDevice(_ device: SpotifyDevice) {
        var updatedConfiguration = configuration
        updatedConfiguration.devicePreference.save(device: device)
        updatedConfiguration.allowNonIPhoneDeviceFallback = updatedConfiguration.devicePreference.allowNonIPhoneFallback
        save(updatedConfiguration)
        latestMessage = "Saved \(device.name) as the preferred alarm device."
    }

    func saveDevicePreference(_ preference: DevicePreference) {
        var updatedConfiguration = configuration
        updatedConfiguration.devicePreference = preference
        updatedConfiguration.allowNonIPhoneDeviceFallback = preference.allowNonIPhoneFallback
        save(updatedConfiguration)
    }

    func preferredDeviceVisibilityText() -> String {
        guard configuration.devicePreference.hasPreferredDevice else {
            return "No preferred device saved"
        }
        let selection = SpotifyDeviceSelector.selectDevice(from: visibleSpotifyDevices, preference: configuration.devicePreference)
        if selection.selectedDevice != nil {
            return "Visible now"
        }
        if visibleSpotifyDevices.isEmpty && !hasRefreshedSpotifyDevices {
            return "Unknown until refresh"
        }
        return "Not visible"
    }

    func bindVisibleIPhoneAsAlarmDevice() async {
        isRefreshingDevices = true
        defer { isRefreshingDevices = false }

        do {
            let token = try await authService.validAccessToken()
            let devices = try await SpotifyAPIClient(accessToken: token).devices()
            visibleSpotifyDevices = devices
            hasRefreshedSpotifyDevices = true
            let selection = SpotifyDeviceSelector.selectDevice(from: devices, preference: configuration.devicePreference)
            guard let device = selection.selectedDevice,
                  SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(device, preference: configuration.devicePreference) else {
                latestMessage = selection.failureMessage ?? "No unrestricted iPhone Spotify device is visible."
                return
            }
            savePreferredDevice(device)
        } catch {
            latestMessage = error.localizedDescription
        }
    }

    func playTest(on device: SpotifyDevice) async {
        guard let deviceID = device.id else {
            latestMessage = "This Spotify device does not have a device_id."
            return
        }
        guard SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(device, preference: configuration.devicePreference) else {
            latestMessage = "Playback test skipped. The alarm only targets an unrestricted iPhone device."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let token = try await authService.validAccessToken()
            let client = SpotifyAPIClient(accessToken: token)
            let routeManager = SpotifyAlarmRouteManager()
            if configuration.advancedSpotifyVolumeEnabled && device.supportsVolume {
                try await client.setVolumeIfSupported(device: device, percent: configuration.targetVolume)
            }
            try await routeManager.transferPlaybackToDevice(client: client, deviceId: deviceID, play: false)
            try await Task.sleep(nanoseconds: 800_000_000)
            guard routeManager.verifyActiveDevice(try await client.playbackState(), deviceId: deviceID) else {
                latestMessage = "Spotify did not confirm transfer to \(device.name)."
                return
            }
            try await client.startPlayback(deviceID: deviceID, contextURI: configuration.playlistUri)
            try await Task.sleep(nanoseconds: 1_000_000_000)

            if routeManager.verifyAlarmPlayback(try await client.playbackState(), deviceId: deviceID, playlistUri: configuration.playlistUri) {
                var updatedConfiguration = configuration
                if updatedConfiguration.devicePreference.preferredDeviceId == deviceID {
                    updatedConfiguration.devicePreference.lastSuccessfulPreferredDeviceTestAt = Date()
                    updatedConfiguration.devicePreference.preferredDeviceLastSeenAt = Date()
                    save(updatedConfiguration)
                }
                latestMessage = "Playback test confirmed on \(device.name)."
            } else {
                latestMessage = "Playback command sent to \(device.name), but Spotify did not confirm playback."
            }
        } catch {
            latestMessage = error.localizedDescription
        }
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
