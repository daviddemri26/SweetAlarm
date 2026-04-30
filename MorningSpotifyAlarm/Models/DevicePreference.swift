import Foundation

struct DevicePreference: Codable, Equatable {
    var preferredDeviceId: String?
    var preferredDeviceName: String?
    var preferredDeviceType: String?
    var preferredDeviceSupportsVolume: Bool?
    var preferredDeviceLastSeenAt: Date?
    var requirePreferredDevice: Bool = true
    var allowAutomaticIPhoneFallback: Bool = true
    var allowNonIPhoneFallback: Bool = false
    var lastSuccessfulPreferredDeviceTestAt: Date?

    var hasPreferredDevice: Bool {
        guard let preferredDeviceId else { return false }
        return !preferredDeviceId.isEmpty
    }

    var displayName: String {
        guard let preferredDeviceName, !preferredDeviceName.isEmpty else {
            return "No preferred device"
        }
        if let preferredDeviceType, !preferredDeviceType.isEmpty {
            return "\(preferredDeviceName) / \(preferredDeviceType)"
        }
        return preferredDeviceName
    }

    mutating func save(device: SpotifyDevice, seenAt: Date = Date()) {
        preferredDeviceId = device.id
        preferredDeviceName = device.name
        preferredDeviceType = device.type
        preferredDeviceSupportsVolume = device.supportsVolume
        preferredDeviceLastSeenAt = seenAt
    }

    enum CodingKeys: String, CodingKey {
        case preferredDeviceId
        case preferredDeviceName
        case preferredDeviceType
        case preferredDeviceSupportsVolume
        case preferredDeviceLastSeenAt
        case requirePreferredDevice
        case allowAutomaticIPhoneFallback
        case allowNonIPhoneFallback
        case lastSuccessfulPreferredDeviceTestAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredDeviceId = try container.decodeIfPresent(String.self, forKey: .preferredDeviceId)
        preferredDeviceName = try container.decodeIfPresent(String.self, forKey: .preferredDeviceName)
        preferredDeviceType = try container.decodeIfPresent(String.self, forKey: .preferredDeviceType)
        preferredDeviceSupportsVolume = try container.decodeIfPresent(Bool.self, forKey: .preferredDeviceSupportsVolume)
        preferredDeviceLastSeenAt = try container.decodeIfPresent(Date.self, forKey: .preferredDeviceLastSeenAt)
        requirePreferredDevice = try container.decodeIfPresent(Bool.self, forKey: .requirePreferredDevice) ?? true
        allowAutomaticIPhoneFallback = try container.decodeIfPresent(Bool.self, forKey: .allowAutomaticIPhoneFallback) ?? true
        allowNonIPhoneFallback = try container.decodeIfPresent(Bool.self, forKey: .allowNonIPhoneFallback) ?? false
        lastSuccessfulPreferredDeviceTestAt = try container.decodeIfPresent(Date.self, forKey: .lastSuccessfulPreferredDeviceTestAt)
    }
}

enum DeviceSelectionReason: String, Codable {
    case preferredDeviceVisible
    case preferredMissingRequirePreferredFailed
    case automaticIPhoneFallback
    case nonIPhoneFallback
    case noEligibleDevice
}

struct DeviceSelectionResult: Equatable {
    let selectedDevice: SpotifyDevice?
    let reason: DeviceSelectionReason
    let preferredDeviceVisible: Bool
    let usedFallbackDevice: Bool
    let visibleDevices: [SpotifyDevice]
    let failureMessage: String?
}
