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
        var selectionResult: DeviceSelectionResult?

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
            let result = SpotifyDeviceSelector.selectDevice(from: devices, preference: configuration.devicePreference)
            selectionResult = result
            if result.preferredDeviceVisible {
                configuration.devicePreference.preferredDeviceLastSeenAt = Date()
            }
            if result.selectedDevice == nil {
                failures.append(result.failureMessage ?? "No eligible Spotify device visible")
            }
            if let selectedDevice = result.selectedDevice,
               !SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(selectedDevice, preference: configuration.devicePreference) {
                failures.append("Selected Spotify device is not an unrestricted iPhone")
            }
            if result.usedFallbackDevice {
                warnings.append("Using iPhone name fallback; confirm this is the alarm iPhone")
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

        return finish(configuration: &configuration, failures: failures, warnings: warnings, selectionResult: selectionResult)
    }

    private func finish(configuration: inout AlarmConfiguration, failures: [String], warnings: [String], selectionResult: DeviceSelectionResult? = nil) -> HealthCheckResult {
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
            preferredDeviceId: nil,
            preferredDeviceName: configuration.devicePreference.preferredDeviceName,
            selectedDeviceId: nil,
            selectedDeviceName: nil,
            selectedDeviceSupportsVolume: nil,
            deviceSelectionReason: selectionResult?.reason,
            usedFallbackDevice: selectionResult?.usedFallbackDevice ?? false,
            visibleDeviceSummary: selectionResult.map { SpotifyDeviceSelector.visibleDeviceSummary($0.visibleDevices) },
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
