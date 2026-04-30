import Foundation
import os

final class SpotifyAlarmRouteManager {
    private let logger = Logger(subsystem: "MorningSpotifyAlarm", category: "AlarmRoute")
    private let store = AlarmConfigStore.shared
    private let authService = SpotifyAuthService()

    func startAlarm(source: AlarmRunSource, shortcutPrewarmExpected: Bool = true) async -> PlaybackRunResult {
        let appIntentStartedAt = Date()
        var configuration = store.loadConfiguration()
        let prewarmStartedAt = store.loadPrewarmStartedAt()
        var selectedDevice: SpotifyDevice?
        var selectionResult: DeviceSelectionResult?
        var visibleDevices: [SpotifyDevice] = []
        var tokenRefreshResult: String?
        var devicesFetchAttempts = 0
        var transferResult: String?
        var activeDeviceAfterTransfer: String?
        var playResult: String?
        var activeDeviceAfterPlay: String?
        var isPlayingAfterPlay: Bool?
        var finalStatus: AlarmRouteFinalStatus = .failedUnknown
        var status: AlarmRunStatus = .failed
        var errorMessage: String?

        do {
            guard configuration.spotifyPlaybackEnabled else {
                finalStatus = .failedAPI
                throw UserFacingError.spotifyAPI("Spotify playback is disabled in settings.")
            }

            guard SpotifyURIParser.playlistID(from: configuration.playlistUri) != nil else {
                finalStatus = .failedAPI
                throw UserFacingError.invalidPlaylistURI
            }

            let token: String
            do {
                token = try await refreshAccessTokenIfNeeded()
                tokenRefreshResult = "success"
            } catch {
                tokenRefreshResult = "failed: \(error.localizedDescription)"
                finalStatus = .failedToken
                throw error
            }

            let client = SpotifyAPIClient(accessToken: token)
            let discovery = try await fetchPreferredIPhoneWithRetry(client: client, preference: configuration.devicePreference)
            visibleDevices = discovery.devices
            selectionResult = discovery.selectionResult
            devicesFetchAttempts = discovery.attempts

            guard let device = discovery.selectionResult.selectedDevice,
                  let deviceID = device.id else {
                finalStatus = .failedMissingIPhone
                throw UserFacingError.noIPhoneDeviceFound
            }

            guard SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(device, preference: configuration.devicePreference) else {
                finalStatus = .failedWrongDevice
                throw UserFacingError.spotifyAPI("Selected Spotify device is not an unrestricted iPhone.")
            }

            selectedDevice = device
            configuration.devicePreference.save(device: device)
            store.saveConfiguration(configuration)

            do {
                try await transferPlaybackToDevice(client: client, deviceId: deviceID, play: false)
                transferResult = "success"
            } catch {
                transferResult = "failed: \(error.localizedDescription)"
                finalStatus = .failedAPI
                throw error
            }

            try await Task.sleep(nanoseconds: 800_000_000)

            let transferState = try await client.playbackState()
            activeDeviceAfterTransfer = deviceSummary(transferState?.device)
            guard verifyActiveDevice(transferState, deviceId: deviceID) else {
                await pauseIfDeviceKnown(client: client, state: transferState)
                finalStatus = .failedTransferNotConfirmed
                throw UserFacingError.spotifyAPI("Spotify did not confirm transfer to this iPhone.")
            }

            do {
                try await startAlarmPlaylist(client: client, deviceId: deviceID, playlistUri: configuration.playlistUri)
                playResult = "success"
            } catch {
                playResult = "failed: \(error.localizedDescription)"
                finalStatus = .failedAPI
                throw error
            }

            try await Task.sleep(nanoseconds: 1_500_000_000)

            let playState = try await client.playbackState()
            activeDeviceAfterPlay = deviceSummary(playState?.device)
            isPlayingAfterPlay = playState?.isPlaying
            guard verifyAlarmPlayback(playState, deviceId: deviceID, playlistUri: configuration.playlistUri) else {
                await pauseIfDeviceKnown(client: client, state: playState)
                finalStatus = .failedWrongDevice
                throw UserFacingError.playbackNotConfirmed
            }

            status = .success
            finalStatus = .success
            configuration.lastSuccessfulRunAt = Date()
            configuration.devicePreference.lastSuccessfulPreferredDeviceTestAt = Date()
            configuration.devicePreference.preferredDeviceLastSeenAt = Date()
            store.saveConfiguration(configuration)
        } catch {
            if finalStatus == .failedUnknown {
                finalStatus = Self.finalStatus(for: error)
            }
            errorMessage = error.localizedDescription
            failClosed(reason: error.localizedDescription)
        }

        let log = AlarmRunLog(
            source: source,
            startedAt: appIntentStartedAt,
            completedAt: Date(),
            status: status,
            playlistUri: configuration.playlistUri,
            targetVolume: configuration.targetVolume,
            preferredDeviceId: nil,
            preferredDeviceName: configuration.devicePreference.preferredDeviceName,
            selectedDeviceId: nil,
            selectedDeviceName: selectedDevice?.name,
            selectedDeviceSupportsVolume: selectedDevice?.supportsVolume,
            deviceSelectionReason: selectionResult?.reason,
            usedFallbackDevice: false,
            visibleDeviceSummary: SpotifyDeviceSelector.visibleDeviceSummary(visibleDevices),
            errorMessage: errorMessage,
            retryCount: max(0, devicesFetchAttempts - 1),
            scheduledAlarmTime: configuration.timeText,
            shortcutPrewarmExpected: shortcutPrewarmExpected,
            prewarmStartedAt: prewarmStartedAt,
            appIntentStartedAt: appIntentStartedAt,
            tokenRefreshResult: tokenRefreshResult,
            devicesFetchAttempts: devicesFetchAttempts,
            selectedDeviceIdHash: SpotifyDeviceSelector.idHash(selectedDevice?.id),
            selectedDeviceType: selectedDevice?.type,
            transferResult: transferResult,
            activeDeviceAfterTransfer: activeDeviceAfterTransfer,
            playResult: playResult,
            activeDeviceAfterPlay: activeDeviceAfterPlay,
            isPlayingAfterPlay: isPlayingAfterPlay,
            finalStatus: finalStatus
        )
        store.appendLog(log)
        store.clearPrewarmStartedAt()

        logger.info("Alarm route finished status=\(finalStatus.rawValue, privacy: .public), attempts=\(devicesFetchAttempts, privacy: .public), device=\(selectedDevice?.name ?? "nil", privacy: .public)")
        return PlaybackRunResult(status: status, shortMessage: Self.message(for: log), log: log)
    }

    func refreshAccessTokenIfNeeded() async throws -> String {
        try await authService.validAccessToken()
    }

    func fetchAvailableDevices(client: SpotifyAPIClient) async throws -> [SpotifyDevice] {
        try await client.devices()
    }

    func findPreferredIPhoneDevice(devices: [SpotifyDevice], preference: DevicePreference) -> DeviceSelectionResult {
        SpotifyDeviceSelector.selectDevice(from: devices, preference: preference)
    }

    func transferPlaybackToDevice(client: SpotifyAPIClient, deviceId: String, play: Bool) async throws {
        try await client.transferPlayback(deviceID: deviceId, play: play)
    }

    func verifyActiveDevice(_ state: SpotifyPlaybackState?, deviceId: String) -> Bool {
        guard let stateDevice = state?.device,
              let activeDeviceID = stateDevice.id,
              activeDeviceID == deviceId,
              !stateDevice.isRestricted else {
            return false
        }
        return stateDevice.type.localizedCaseInsensitiveCompare("Smartphone") == .orderedSame
            || stateDevice.name.localizedCaseInsensitiveContains("iphone")
    }

    func startAlarmPlaylist(client: SpotifyAPIClient, deviceId: String, playlistUri: String) async throws {
        try await client.startPlayback(deviceID: deviceId, contextURI: playlistUri)
    }

    func verifyAlarmPlayback(_ state: SpotifyPlaybackState?, deviceId: String, playlistUri: String) -> Bool {
        guard let state, state.isPlaying, verifyActiveDevice(state, deviceId: deviceId) else {
            return false
        }
        if let contextURI = state.context?.uri, !contextURI.isEmpty {
            return contextURI == playlistUri
        }
        return true
    }

    func failClosed(reason: String) {
        logger.error("Alarm route failed closed: \(reason, privacy: .public)")
    }

    private func pauseIfDeviceKnown(client: SpotifyAPIClient, state: SpotifyPlaybackState?) async {
        guard let deviceID = state?.device?.id else { return }
        do {
            try await client.pausePlayback(deviceID: deviceID)
            logger.warning("Paused Spotify playback during fail-closed path on deviceHash=\(SpotifyDeviceSelector.idHash(deviceID), privacy: .public)")
        } catch {
            logger.warning("Could not pause Spotify playback during fail-closed path: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchPreferredIPhoneWithRetry(client: SpotifyAPIClient, preference: DevicePreference) async throws -> (devices: [SpotifyDevice], selectionResult: DeviceSelectionResult, attempts: Int) {
        let retryDelays: [UInt64] = [0, 1_000_000_000, 2_000_000_000, 3_000_000_000]
        var attempts = 0
        var lastDevices: [SpotifyDevice] = []
        var lastSelection = DeviceSelectionResult(
            selectedDevice: nil,
            reason: .noEligibleDevice,
            preferredDeviceVisible: false,
            usedFallbackDevice: false,
            visibleDevices: [],
            failureMessage: SpotifyDeviceSelector.preferredMissingMessage
        )
        var lastError: Error?

        for delay in retryDelays {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }

            attempts += 1
            do {
                let devices = try await fetchAvailableDevices(client: client)
                let selection = findPreferredIPhoneDevice(devices: devices, preference: preference)
                lastDevices = devices
                lastSelection = selection

                logger.info("GET /devices attempt=\(attempts, privacy: .public), count=\(devices.count, privacy: .public), selected=\(selection.selectedDevice?.name ?? "nil", privacy: .public)")

                if selection.selectedDevice != nil {
                    return (devices, selection, attempts)
                }
            } catch {
                lastError = error
                logger.warning("GET /devices attempt=\(attempts, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if lastDevices.isEmpty, let lastError {
            throw lastError
        }
        return (lastDevices, lastSelection, attempts)
    }

    private func deviceSummary(_ device: SpotifyDevice?) -> String {
        guard let device else { return "nil" }
        return "\(device.name) (\(device.type), idHash=\(SpotifyDeviceSelector.idHash(device.id)), restricted=\(device.isRestricted), supportsVolume=\(device.supportsVolume))"
    }

    private static func message(for log: AlarmRunLog) -> String {
        switch log.finalStatus {
        case .success:
            return "Started playlist on \(log.selectedDeviceName ?? "this iPhone")."
        case .failedMissingIPhone:
            return "This iPhone was not visible in Spotify after prewarm. Spotify playback was not started."
        case .failedTransferNotConfirmed:
            return "Spotify did not confirm playback transfer to this iPhone. Playback was not started."
        case .failedWrongDevice:
            return "Spotify did not confirm the alarm on this iPhone. No fallback device was used."
        case .failedToken:
            return "Spotify token refresh failed. Reconnect Spotify."
        case .failedAPI:
            return log.errorMessage ?? "Spotify API failed. Playback was not started."
        case .failedUnknown, nil:
            return log.errorMessage ?? "Morning Spotify Alarm failed closed."
        }
    }

    private static func finalStatus(for error: Error) -> AlarmRouteFinalStatus {
        if let userError = error as? UserFacingError {
            switch userError {
            case .spotifyNotConnected, .tokenRefreshFailed:
                return .failedToken
            case .noIPhoneDeviceFound, .spotifyDeviceUnavailable:
                return .failedMissingIPhone
            case .playbackNotConfirmed:
                return .failedWrongDevice
            default:
                return .failedAPI
            }
        }
        return .failedUnknown
    }
}
