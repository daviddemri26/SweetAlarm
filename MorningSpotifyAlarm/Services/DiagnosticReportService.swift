import Foundation
import UIKit

struct DiagnosticReportResult {
    let reportText: String
    let succeeded: Bool
}

final class DiagnosticReportService {
    private let store = AlarmConfigStore.shared
    private let authService = SpotifyAuthService()

    func runFullPlaybackDiagnostic() async -> DiagnosticReportResult {
        var lines: [String] = []
        var hardFailure = false

        func add(_ line: String = "") {
            lines.append(line)
        }

        func pass(_ label: String, _ value: String = "") {
            add("[PASS] \(label)\(value.isEmpty ? "" : ": \(value)")")
        }

        func warn(_ label: String, _ value: String = "") {
            add("[WARN] \(label)\(value.isEmpty ? "" : ": \(value)")")
        }

        func fail(_ label: String, _ value: String = "") {
            hardFailure = true
            add("[FAIL] \(label)\(value.isEmpty ? "" : ": \(value)")")
        }

        let startedAt = Date()
        var configuration = store.loadConfiguration()

        add("Morning Spotify Alarm Diagnostic Report")
        add("Generated: \(DateHelpers.displayDateTime.string(from: startedAt))")
        add("App bundle: \(Bundle.main.bundleIdentifier ?? "unknown")")
        add("iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        let deviceModel = await MainActor.run { UIDevice.current.model }
        add("Device model: \(deviceModel)")
        add("")

        add("CONFIGURATION")
        add("Alarm enabled: \(configuration.enabled)")
        add("Alarm time: \(configuration.timeText)")
        add("Repeat days: \(configuration.repeatDaysText)")
        add("Playlist URI: \(configuration.playlistUri)")
        add("Target Shortcut volume: \(configuration.targetVolume)%")
        add("Spotify playback enabled: \(configuration.spotifyPlaybackEnabled)")
        add("Retry enabled: \(configuration.retryEnabled)")
        add("Require preferred device: \(configuration.devicePreference.requirePreferredDevice)")
        add("Allow automatic iPhone fallback: \(configuration.devicePreference.allowAutomaticIPhoneFallback)")
        add("Allow non-iPhone fallback: \(configuration.devicePreference.allowNonIPhoneFallback)")
        add("Advanced Spotify volume enabled: \(configuration.advancedSpotifyVolumeEnabled)")
        add("Shortcut volume step confirmed manually: \(configuration.shortcutVolumeStepConfirmed)")
        add("Backup alarm configured manually: \(configuration.backupAlarmConfigured)")
        add("")

        add("PREFERRED SPOTIFY DEVICE")
        add("Saved preferred id: \(redactID(configuration.devicePreference.preferredDeviceId))")
        add("Saved preferred name: \(configuration.devicePreference.preferredDeviceName ?? "nil")")
        add("Saved preferred type: \(configuration.devicePreference.preferredDeviceType ?? "nil")")
        add("Saved preferred supportsVolume: \(configuration.devicePreference.preferredDeviceSupportsVolume.map(String.init) ?? "nil")")
        add("Saved preferred last seen: \(DateHelpers.timeString(configuration.devicePreference.preferredDeviceLastSeenAt))")
        add("Last successful preferred-device test: \(DateHelpers.timeString(configuration.devicePreference.lastSuccessfulPreferredDeviceTestAt))")
        add("")

        guard configuration.spotifyPlaybackEnabled else {
            fail("Spotify playback setting", "Disabled in app settings")
            return finish(lines: lines, succeeded: !hardFailure)
        }

        guard let playlistID = SpotifyURIParser.playlistID(from: configuration.playlistUri) else {
            fail("Playlist URI", "Invalid or missing")
            return finish(lines: lines, succeeded: !hardFailure)
        }
        pass("Playlist URI", "Valid playlist ID \(playlistID)")

        add("")
        add("AUTHENTICATION")
        if let authState = store.loadAuthState() {
            pass("Stored auth state", "expiresAt=\(DateHelpers.displayDateTime.string(from: authState.expiresAt)), scopes=\(authState.scopes.joined(separator: ","))")
            if authState.isExpired {
                warn("Access token cache", "Expired or expiring soon; refresh will be attempted")
            } else {
                pass("Access token cache", "Not expired")
            }
        } else {
            fail("Stored auth state", "Missing")
        }

        if authService.hasRefreshToken() {
            pass("Refresh token", "Present in Keychain")
        } else {
            fail("Refresh token", "Missing from Keychain")
        }

        let token: String
        do {
            token = try await authService.validAccessToken()
            pass("Access token refresh/validation", "OK; token value redacted")
        } catch {
            fail("Access token refresh/validation", error.localizedDescription)
            return finish(lines: lines, succeeded: !hardFailure)
        }

        let client = SpotifyAPIClient(accessToken: token)

        add("")
        add("SPOTIFY API")
        do {
            let metadata = try await client.playlistMetadata(playlistID: playlistID)
            pass("Playlist metadata", "\(metadata.name), owner=\(metadata.owner.displayName ?? "unknown")")
        } catch {
            warn("Playlist metadata", error.localizedDescription)
        }

        add("")
        add("PLAYER STATE BEFORE PLAYBACK")
        do {
            if let state = try await client.playbackState() {
                add("Current state: isPlaying=\(state.isPlaying), device=\(state.device?.name ?? "nil"), type=\(state.device?.type ?? "nil"), deviceId=\(redactID(state.device?.id)), context=\(state.context?.uri ?? "nil")")
            } else {
                add("Current state: Spotify returned 204 no active playback")
            }
        } catch {
            warn("GET /v1/me/player before playback", error.localizedDescription)
        }

        let devices: [SpotifyDevice]
        do {
            devices = try await client.devices()
            pass("GET /v1/me/player/devices", "\(devices.count) device(s)")
        } catch {
            fail("GET /v1/me/player/devices", error.localizedDescription)
            return finish(lines: lines, succeeded: !hardFailure)
        }

        if devices.isEmpty {
            fail("Spotify devices", "No visible device. Open Spotify on the iPhone and retry.")
            return finish(lines: lines, succeeded: !hardFailure)
        }

        add("")
        add("DEVICES")
        for (index, device) in devices.enumerated() {
            add("Device \(index + 1): name=\(device.name), type=\(device.type), id=\(redactID(device.id)), active=\(device.isActive), restricted=\(device.isRestricted), privateSession=\(device.isPrivateSession), supportsVolume=\(device.supportsVolume), volumePercent=\(device.volumePercent.map(String.init) ?? "nil"), iPhoneLike=\(device.isIPhoneLike)")
        }

        let selectionResult = SpotifyDeviceSelector.selectDevice(from: devices, preference: configuration.devicePreference)
        if selectionResult.preferredDeviceVisible {
            configuration.devicePreference.preferredDeviceLastSeenAt = Date()
            store.saveConfiguration(configuration)
        }

        add("")
        add("DEVICE SELECTION")
        add("Preferred device currently visible: \(selectionResult.preferredDeviceVisible)")
        add("Selection reason: \(selectionResult.reason.rawValue)")

        guard let selectedDevice = selectionResult.selectedDevice,
              let selectedDeviceID = selectedDevice.id else {
            fail("Device selection", selectionResult.failureMessage ?? "No eligible Spotify device found")
            add("Playback skipped: true")
            add("")
            add("DEVICE PREPARATION STEPS")
            add("1. Tap Open Spotify to Prepare iPhone in this screen.")
            add("2. In Spotify, play any track for a few seconds.")
            add("3. Open Spotify Connect devices and choose This iPhone, not Living Room TV.")
            add("4. Return here and run the diagnostic again.")
            add("5. Save the iPhone as Preferred Alarm Device before relying on the Shortcut automation.")
            return finish(lines: lines, succeeded: !hardFailure)
        }
        add("Playback skipped: false")
        pass("Selected device", "name=\(selectedDevice.name), type=\(selectedDevice.type), id=\(redactID(selectedDevice.id)), supportsVolume=\(selectedDevice.supportsVolume)")

        guard SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(selectedDevice, preference: configuration.devicePreference) else {
            fail("Selected device", "Not an unrestricted iPhone. Playback skipped to avoid TV/speaker/desktop fallback.")
            return finish(lines: lines, succeeded: !hardFailure)
        }

        if selectionResult.usedFallbackDevice {
            warn("iPhone name fallback used", "reason=\(selectionResult.reason.rawValue)")
        }

        if selectedDevice.supportsVolume {
            warn("Spotify volume support", "Selected device supports Spotify volume; advanced option may be tested separately")
        } else {
            pass("Spotify volume skip", "Selected iPhone reports supports_volume=false, so app must rely on Shortcuts Set Volume")
        }

        add("")
        add("PLAYBACK TEST")
        let routeManager = SpotifyAlarmRouteManager()
        add("Request: PUT /v1/me/player")
        add("Body: {\"device_ids\":[\"\(redactID(selectedDevice.id))\"],\"play\":false}")

        do {
            try await routeManager.transferPlaybackToDevice(client: client, deviceId: selectedDeviceID, play: false)
            pass("Transfer command", "Sent")
            try await Task.sleep(nanoseconds: 800_000_000)
            let transferState = try await client.playbackState()
            add("Transfer state: device=\(transferState?.device?.name ?? "nil"), type=\(transferState?.device?.type ?? "nil"), deviceId=\(redactID(transferState?.device?.id))")
            guard routeManager.verifyActiveDevice(transferState, deviceId: selectedDeviceID) else {
                fail("Transfer verification", "Spotify did not confirm this iPhone as active")
                return finish(lines: lines, succeeded: !hardFailure)
            }
            pass("Transfer verification", "Confirmed this iPhone")
        } catch {
            fail("Transfer command", error.localizedDescription)
            return finish(lines: lines, succeeded: !hardFailure)
        }

        add("Request: PUT /v1/me/player/play?device_id=\(redactID(selectedDevice.id))")
        add("Body: {\"context_uri\":\"\(configuration.playlistUri)\"}")

        do {
            try await routeManager.startAlarmPlaylist(client: client, deviceId: selectedDeviceID, playlistUri: configuration.playlistUri)
            pass("Playback command", "Sent")
        } catch {
            fail("Playback command", error.localizedDescription)
            return finish(lines: lines, succeeded: !hardFailure)
        }

        let maxAttempts = configuration.retryEnabled ? 3 : 1
        var verified = false
        var lastStateDescription = "No state read"

        for attempt in 1...maxAttempts {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                if let state = try await client.playbackState() {
                    let stateDeviceID = state.device?.id
                    let stateContextURI = state.context?.uri
                    lastStateDescription = "attempt=\(attempt), isPlaying=\(state.isPlaying), device=\(state.device?.name ?? "nil"), deviceId=\(redactID(stateDeviceID)), context=\(stateContextURI ?? "nil")"
                    add("Playback state: \(lastStateDescription)")

                    let deviceMatches = stateDeviceID == selectedDeviceID
                    let contextMatches = stateContextURI == nil || stateContextURI == configuration.playlistUri
                    if state.isPlaying && deviceMatches && contextMatches {
                        verified = true
                        pass("Playback verification", "Confirmed on attempt \(attempt)")
                        if selectionResult.reason == .preferredDeviceVisible {
                            configuration.devicePreference.lastSuccessfulPreferredDeviceTestAt = Date()
                            configuration.devicePreference.preferredDeviceLastSeenAt = Date()
                            store.saveConfiguration(configuration)
                        }
                        break
                    }
                } else {
                    lastStateDescription = "attempt=\(attempt), Spotify returned 204 no active playback"
                    add("Playback state: \(lastStateDescription)")
                }

                if attempt < maxAttempts {
                    warn("Playback verification retry", "Re-sending playback command")
                    try await routeManager.startAlarmPlaylist(client: client, deviceId: selectedDeviceID, playlistUri: configuration.playlistUri)
                }
            } catch {
                lastStateDescription = "attempt=\(attempt), error=\(error.localizedDescription)"
                warn("Playback verification attempt \(attempt)", error.localizedDescription)
            }
        }

        if !verified {
            fail("Playback verification", lastStateDescription)
        }

        add("")
        add("NEXT ACTIONS")
        if hardFailure {
            add("- Copy this whole report and paste it back to Codex.")
            add("- If device selection failed, open Spotify on the iPhone and run the diagnostic again.")
            add("- If redirect/login failed before this report, verify the Spotify dashboard redirect URI is exactly \(AppConfig.spotifyRedirectUri).")
        } else {
            add("- Core Spotify playback path is working.")
            add("- Make sure the Shortcut automation sets iPhone volume before running the App Intent.")
        }

        return finish(lines: lines, succeeded: !hardFailure)
    }

    private func finish(lines: [String], succeeded: Bool) -> DiagnosticReportResult {
        var output = lines
        output.append("")
        output.append("END OF REPORT")
        return DiagnosticReportResult(reportText: output.joined(separator: "\n"), succeeded: succeeded)
    }

    private func redactID(_ id: String?) -> String {
        SpotifyDeviceSelector.idHash(id)
    }
}
