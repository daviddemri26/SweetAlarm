import Foundation
import os

struct PlaybackRunResult {
    let status: AlarmRunStatus
    let shortMessage: String
    let log: AlarmRunLog
}

final class PlaybackOrchestrator {
    private let logger = Logger(subsystem: "MorningSpotifyAlarm", category: "Playback")
    private let store = AlarmConfigStore.shared
    private let authService = SpotifyAuthService()

    func start(source: AlarmRunSource) async -> PlaybackRunResult {
        let startedAt = Date()
        var configuration = store.loadConfiguration()
        var selectedDevice: SpotifyDevice?
        var retryCount = 0
        var status: AlarmRunStatus = .failed
        var errorMessage: String?

        do {
            guard configuration.spotifyPlaybackEnabled else {
                throw UserFacingError.spotifyAPI("Spotify playback is disabled in settings.")
            }

            guard SpotifyURIParser.playlistID(from: configuration.playlistUri) != nil else {
                throw UserFacingError.invalidPlaylistURI
            }

            let token = try await authService.validAccessToken()
            let client = SpotifyAPIClient(accessToken: token)
            let devices = try await client.devices()
            guard let device = Self.selectPlaybackDevice(from: devices, allowNonIPhoneFallback: configuration.allowNonIPhoneDeviceFallback),
                  let deviceID = device.id else {
                let visibleDevices = devices.map { "\($0.name) (\($0.type))" }.joined(separator: ", ")
                throw UserFacingError.spotifyAPI("No iPhone Spotify device is visible. Visible devices: \(visibleDevices.isEmpty ? "none" : visibleDevices). Open Spotify on the iPhone and choose This iPhone, then try again.")
            }
            selectedDevice = device

            if configuration.advancedSpotifyVolumeEnabled && device.supportsVolume {
                try await client.setVolumeIfSupported(device: device, percent: configuration.targetVolume)
            }

            try await client.startPlayback(deviceID: deviceID, contextURI: configuration.playlistUri)
            let maxAttempts = configuration.retryEnabled ? 3 : 1
            var verified = false

            for attempt in 1...maxAttempts {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                if try await Self.verifyPlayback(client: client, deviceID: deviceID, playlistURI: configuration.playlistUri) {
                    verified = true
                    retryCount = attempt - 1
                    break
                }

                retryCount = attempt
                if attempt < maxAttempts {
                    try await client.startPlayback(deviceID: deviceID, contextURI: configuration.playlistUri)
                }
            }

            if verified {
                status = .success
                configuration.lastSuccessfulRunAt = Date()
                store.saveConfiguration(configuration)
            } else {
                status = .partial
                errorMessage = UserFacingError.playbackNotConfirmed.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Playback failed: \(error.localizedDescription, privacy: .public)")
        }

        let log = AlarmRunLog(
            source: source,
            startedAt: startedAt,
            completedAt: Date(),
            status: status,
            playlistUri: configuration.playlistUri,
            targetVolume: configuration.targetVolume,
            selectedDeviceId: selectedDevice?.id,
            selectedDeviceName: selectedDevice?.name,
            selectedDeviceSupportsVolume: selectedDevice?.supportsVolume,
            errorMessage: errorMessage,
            retryCount: retryCount
        )
        store.appendLog(log)

        return PlaybackRunResult(status: status, shortMessage: Self.message(for: log), log: log)
    }

    static func selectIPhoneDevice(from devices: [SpotifyDevice]) -> SpotifyDevice? {
        devices
            .filter { !$0.isRestricted && $0.id != nil && $0.isIPhoneLike }
            .sorted { lhs, rhs in
                score(lhs) > score(rhs)
            }
            .first
    }

    static func selectPlaybackDevice(from devices: [SpotifyDevice], allowNonIPhoneFallback: Bool) -> SpotifyDevice? {
        if let iPhoneDevice = selectIPhoneDevice(from: devices) {
            return iPhoneDevice
        }

        guard allowNonIPhoneFallback else { return nil }

        return devices
            .filter { !$0.isRestricted && $0.id != nil }
            .sorted { lhs, rhs in
                fallbackScore(lhs) > fallbackScore(rhs)
            }
            .first
    }

    private static func score(_ device: SpotifyDevice) -> Int {
        var value = 0
        if device.isActive { value += 100 }
        if device.name.localizedCaseInsensitiveContains("iphone") { value += 50 }
        if device.type.localizedCaseInsensitiveContains("smartphone") { value += 25 }
        return value
    }

    private static func fallbackScore(_ device: SpotifyDevice) -> Int {
        var value = 0
        if device.isActive { value += 100 }
        if device.type.localizedCaseInsensitiveContains("computer") { value += 20 }
        if device.type.localizedCaseInsensitiveContains("speaker") { value += 10 }
        return value
    }

    private static func verifyPlayback(client: SpotifyAPIClient, deviceID: String, playlistURI: String) async throws -> Bool {
        guard let state = try await client.playbackState(), state.isPlaying else { return false }
        if let currentDeviceID = state.device?.id, currentDeviceID != deviceID {
            return false
        }
        if let contextURI = state.context?.uri, !contextURI.isEmpty {
            return contextURI == playlistURI
        }
        return true
    }

    private static func message(for log: AlarmRunLog) -> String {
        switch log.status {
        case .success:
            "Started playlist on \(log.selectedDeviceName ?? "iPhone")."
        case .partial:
            "Playback command was sent, but Spotify did not fully confirm playback."
        case .failed:
            log.errorMessage ?? "Morning Spotify Alarm failed."
        }
    }
}
