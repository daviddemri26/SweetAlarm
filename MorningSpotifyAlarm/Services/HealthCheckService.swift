import Foundation

struct HealthCheckResult {
    let message: String
}

final class HealthCheckService {
    private let store = AlarmConfigStore.shared
    private let authService = SpotifyAuthService()

    func run() async -> HealthCheckResult {
        var configuration = store.loadConfiguration()
        var failures: [String] = []
        var warnings: [String] = []

        if !authService.hasRefreshToken() {
            failures.append("No refresh token")
        }

        guard SpotifyURIParser.playlistID(from: configuration.playlistUri) != nil else {
            failures.append("Invalid playlist")
            return finish(configuration: &configuration, failures: failures, warnings: warnings)
        }

        do {
            let token = try await authService.validAccessToken()
            let client = SpotifyAPIClient(accessToken: token)
            let devices = try await client.devices()
            if PlaybackOrchestrator.selectIPhoneDevice(from: devices) == nil {
                failures.append("No iPhone Spotify device visible")
            }
        } catch {
            failures.append(error.localizedDescription)
        }

        if !configuration.shortcutVolumeStepConfirmed {
            warnings.append("Shortcut volume step not manually confirmed")
        }
        if !configuration.backupAlarmConfigured && !configuration.fallbackEnabled {
            warnings.append("Backup alarm not configured")
        }

        return finish(configuration: &configuration, failures: failures, warnings: warnings)
    }

    private func finish(configuration: inout AlarmConfiguration, failures: [String], warnings: [String]) -> HealthCheckResult {
        configuration.lastHealthCheckAt = Date()
        store.saveConfiguration(configuration)

        let status: AlarmRunStatus = failures.isEmpty ? .success : .failed
        let log = AlarmRunLog(
            source: .healthCheck,
            startedAt: Date(),
            completedAt: Date(),
            status: status,
            playlistUri: configuration.playlistUri,
            targetVolume: configuration.targetVolume,
            selectedDeviceId: nil,
            selectedDeviceName: nil,
            selectedDeviceSupportsVolume: nil,
            errorMessage: failures.first,
            retryCount: 0
        )
        store.appendLog(log)

        if failures.isEmpty && warnings.isEmpty {
            return HealthCheckResult(message: "Health check passed.")
        }
        if failures.isEmpty {
            return HealthCheckResult(message: "Health check passed with warning: \(warnings.joined(separator: ", ")).")
        }
        return HealthCheckResult(message: "Health check failed: \(failures.joined(separator: ", ")).")
    }
}
