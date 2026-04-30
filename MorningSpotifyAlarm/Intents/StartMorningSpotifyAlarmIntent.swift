import AppIntents
import Foundation

struct StartMorningSpotifyAlarmIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Morning Spotify Alarm"
    static var description = IntentDescription("After Spotify has been prewarmed, verifies this iPhone as the active Spotify device and starts the configured playlist with an explicit device ID.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await SpotifyAlarmRouteManager().startAlarm(source: .shortcut, shortcutPrewarmExpected: true)
        return .result(dialog: "\(result.shortMessage)")
    }
}

struct CheckSpotifyIPhoneDeviceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Spotify iPhone Device"
    static var description = IntentDescription("Lists visible Spotify Connect devices and reports whether the preferred iPhone is available.")
    static var openAppWhenRun = false

    @Parameter(title: "Bind Visible iPhone")
    var bindVisibleIPhone: Bool

    init() {
        bindVisibleIPhone = false
    }

    init(bindVisibleIPhone: Bool) {
        self.bindVisibleIPhone = bindVisibleIPhone
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = AlarmConfigStore.shared
        var configuration = store.loadConfiguration()
        let token = try await SpotifyAuthService().validAccessToken()
        let devices = try await SpotifyAPIClient(accessToken: token).devices()
        let selection = SpotifyDeviceSelector.selectDevice(from: devices, preference: configuration.devicePreference)
        let visibleIPhone = selection.selectedDevice.flatMap { device in
            SpotifyDeviceSelector.isEligibleIPhoneAlarmDevice(device, preference: configuration.devicePreference) ? device : nil
        }

        if bindVisibleIPhone, let device = visibleIPhone {
            configuration.devicePreference.save(device: device)
            store.saveConfiguration(configuration)
        } else if selection.preferredDeviceVisible {
            configuration.devicePreference.preferredDeviceLastSeenAt = Date()
            store.saveConfiguration(configuration)
        }

        let visibleText = devices.isEmpty
            ? "No Spotify Connect devices are visible."
            : SpotifyDeviceSelector.visibleDeviceSummary(devices)
        let preferredText: String
        if let selected = visibleIPhone {
            preferredText = bindVisibleIPhone
                ? "Bound \(selected.name) as the alarm iPhone."
                : "Preferred iPhone is visible: \(selected.name)."
        } else {
            preferredText = "Preferred iPhone is not visible. Spotify playback will fail closed."
        }

        return .result(dialog: "\(preferredText) Devices: \(visibleText)")
    }
}

struct MarkPrewarmStartedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Spotify Prewarm Started"
    static var description = IntentDescription("Records that the Shortcut is about to open Spotify and silently prewarm this iPhone.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AlarmConfigStore.shared.markPrewarmStarted()
        return .result(dialog: "Spotify prewarm marked. Open Spotify, play briefly at volume 0, then run Start Morning Spotify Alarm.")
    }
}
