import CryptoKit
import Foundation

enum SpotifyDeviceSelector {
    static let preferredMissingMessage = "Preferred iPhone is not visible. Run the Shortcut prewarm, or open Spotify on this iPhone and play briefly, then try again."

    static func selectDevice(from devices: [SpotifyDevice], preference: DevicePreference) -> DeviceSelectionResult {
        let preferredDevice = devices.first { device in
            guard let preferredID = preference.preferredDeviceId, let deviceID = device.id else {
                return false
            }
            return deviceID == preferredID
        }
        let preferredDeviceVisible = preferredDevice != nil

        if let preferredDevice,
           isEligibleIPhoneAlarmDevice(preferredDevice, preference: preference) {
            return DeviceSelectionResult(
                selectedDevice: preferredDevice,
                reason: .preferredDeviceVisible,
                preferredDeviceVisible: true,
                usedFallbackDevice: false,
                visibleDevices: devices,
                failureMessage: nil
            )
        }

        if preference.allowAutomaticIPhoneFallback,
           let iPhoneDevice = strictSingleIPhoneFallback(from: devices, preference: preference) {
            return DeviceSelectionResult(
                selectedDevice: iPhoneDevice,
                reason: .automaticIPhoneFallback,
                preferredDeviceVisible: preferredDeviceVisible,
                usedFallbackDevice: true,
                visibleDevices: devices,
                failureMessage: nil
            )
        }

        if preference.requirePreferredDevice {
            return DeviceSelectionResult(
                selectedDevice: nil,
                reason: .preferredMissingRequirePreferredFailed,
                preferredDeviceVisible: preferredDeviceVisible,
                usedFallbackDevice: false,
                visibleDevices: devices,
                failureMessage: preferredMissingMessage
            )
        }

        if let iPhoneDevice = bestIPhoneLikeDevice(from: devices, preference: preference) {
            return DeviceSelectionResult(
                selectedDevice: iPhoneDevice,
                reason: .automaticIPhoneFallback,
                preferredDeviceVisible: preferredDeviceVisible,
                usedFallbackDevice: true,
                visibleDevices: devices,
                failureMessage: nil
            )
        }

        if preference.allowNonIPhoneFallback,
           let fallbackDevice = bestFallbackDevice(from: devices) {
            return DeviceSelectionResult(
                selectedDevice: fallbackDevice,
                reason: .nonIPhoneFallback,
                preferredDeviceVisible: preferredDeviceVisible,
                usedFallbackDevice: true,
                visibleDevices: devices,
                failureMessage: nil
            )
        }

        return DeviceSelectionResult(
            selectedDevice: nil,
            reason: .noEligibleDevice,
            preferredDeviceVisible: preferredDeviceVisible,
            usedFallbackDevice: false,
            visibleDevices: devices,
            failureMessage: "No eligible Spotify device is visible. Open Spotify on iPhone and choose This iPhone, then try again."
        )
    }

    static func visibleDeviceSummary(_ devices: [SpotifyDevice]) -> String {
        guard !devices.isEmpty else { return "none" }
        return devices.map { device in
            let id = idHash(device.id)
            return "\(device.name) (\(device.type), idHash=\(id), active=\(device.isActive), restricted=\(device.isRestricted), supportsVolume=\(device.supportsVolume), iPhoneLike=\(device.isIPhoneLike))"
        }
        .joined(separator: "; ")
    }

    static func redactID(_ id: String?) -> String {
        idHash(id)
    }

    static func idHash(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "nil" }
        let digest = SHA256.hash(data: Data(id.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    static func isEligibleIPhoneAlarmDevice(_ device: SpotifyDevice, preference: DevicePreference) -> Bool {
        guard device.id != nil, !device.isRestricted else { return false }
        return isStrictIPhoneCandidate(device, preference: preference)
    }

    private static func strictSingleIPhoneFallback(from devices: [SpotifyDevice], preference: DevicePreference) -> SpotifyDevice? {
        let candidates = devices.filter { isEligibleIPhoneAlarmDevice($0, preference: preference) }
        guard candidates.count == 1 else { return nil }
        return candidates.first
    }

    private static func bestIPhoneLikeDevice(from devices: [SpotifyDevice], preference: DevicePreference) -> SpotifyDevice? {
        devices
            .filter { isEligibleIPhoneAlarmDevice($0, preference: preference) }
            .sorted { lhs, rhs in
                sortKey(lhs, iPhoneOnly: true) > sortKey(rhs, iPhoneOnly: true)
            }
            .first
    }

    private static func bestFallbackDevice(from devices: [SpotifyDevice]) -> SpotifyDevice? {
        devices
            .filter { !$0.isRestricted && $0.id != nil }
            .sorted { lhs, rhs in
                sortKey(lhs, iPhoneOnly: false) > sortKey(rhs, iPhoneOnly: false)
            }
            .first
    }

    private static func isStrictIPhoneCandidate(_ device: SpotifyDevice, preference: DevicePreference) -> Bool {
        let typeIsSmartphone = device.type.localizedCaseInsensitiveCompare("Smartphone") == .orderedSame
        let nameContainsIPhone = device.name.localizedCaseInsensitiveContains("iphone")
        let savedNameMatches = namesMatch(device.name, preference.preferredDeviceName)
        return typeIsSmartphone && (nameContainsIPhone || savedNameMatches)
    }

    private static func namesMatch(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs, !rhs.isEmpty else { return false }
        let left = normalizedName(lhs)
        let right = normalizedName(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func sortKey(_ device: SpotifyDevice, iPhoneOnly: Bool) -> String {
        var score = 0
        if device.isActive { score += 100 }
        if device.name.localizedCaseInsensitiveContains("iphone") { score += 50 }
        if device.type.localizedCaseInsensitiveContains("smartphone") { score += 25 }
        if !iPhoneOnly && device.type.localizedCaseInsensitiveContains("computer") { score += 10 }

        let normalizedName = device.name.lowercased()
        let normalizedType = device.type.lowercased()
        let normalizedID = device.id ?? ""
        return String(format: "%03d", score) + "|" + normalizedName + "|" + normalizedType + "|" + normalizedID
    }
}
