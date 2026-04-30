import Foundation

enum AlarmRunStatus: String, Codable {
    case success
    case partial
    case failed
}

enum AlarmRunSource: String, Codable {
    case shortcut
    case testNow
    case healthCheck
}

enum AlarmRouteFinalStatus: String, Codable {
    case success
    case failedMissingIPhone = "failed_missing_iphone"
    case failedTransferNotConfirmed = "failed_transfer_not_confirmed"
    case failedWrongDevice = "failed_wrong_device"
    case failedToken = "failed_token"
    case failedAPI = "failed_api"
    case failedUnknown = "failed_unknown"
}

struct AlarmRunLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var source: AlarmRunSource
    var startedAt: Date
    var completedAt: Date?
    var status: AlarmRunStatus
    var playlistUri: String
    var targetVolume: Int
    var preferredDeviceId: String?
    var preferredDeviceName: String?
    var selectedDeviceId: String?
    var selectedDeviceName: String?
    var selectedDeviceSupportsVolume: Bool?
    var deviceSelectionReason: DeviceSelectionReason?
    var usedFallbackDevice: Bool
    var visibleDeviceSummary: String?
    var errorMessage: String?
    var retryCount: Int
    var scheduledAlarmTime: String?
    var shortcutPrewarmExpected: Bool
    var prewarmStartedAt: Date?
    var appIntentStartedAt: Date?
    var tokenRefreshResult: String?
    var devicesFetchAttempts: Int
    var selectedDeviceIdHash: String?
    var selectedDeviceType: String?
    var transferResult: String?
    var activeDeviceAfterTransfer: String?
    var playResult: String?
    var activeDeviceAfterPlay: String?
    var isPlayingAfterPlay: Bool?
    var finalStatus: AlarmRouteFinalStatus?

    var summary: String {
        switch status {
        case .success:
            "Success on \(selectedDeviceName ?? "device")"
        case .partial:
            "Command sent, playback not fully confirmed"
        case .failed:
            errorMessage ?? "Failed"
        }
    }

    init(
        id: UUID = UUID(),
        source: AlarmRunSource,
        startedAt: Date,
        completedAt: Date?,
        status: AlarmRunStatus,
        playlistUri: String,
        targetVolume: Int,
        preferredDeviceId: String? = nil,
        preferredDeviceName: String? = nil,
        selectedDeviceId: String? = nil,
        selectedDeviceName: String? = nil,
        selectedDeviceSupportsVolume: Bool? = nil,
        deviceSelectionReason: DeviceSelectionReason? = nil,
        usedFallbackDevice: Bool = false,
        visibleDeviceSummary: String? = nil,
        errorMessage: String?,
        retryCount: Int,
        scheduledAlarmTime: String? = nil,
        shortcutPrewarmExpected: Bool = false,
        prewarmStartedAt: Date? = nil,
        appIntentStartedAt: Date? = nil,
        tokenRefreshResult: String? = nil,
        devicesFetchAttempts: Int = 0,
        selectedDeviceIdHash: String? = nil,
        selectedDeviceType: String? = nil,
        transferResult: String? = nil,
        activeDeviceAfterTransfer: String? = nil,
        playResult: String? = nil,
        activeDeviceAfterPlay: String? = nil,
        isPlayingAfterPlay: Bool? = nil,
        finalStatus: AlarmRouteFinalStatus? = nil
    ) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.playlistUri = playlistUri
        self.targetVolume = targetVolume
        self.preferredDeviceId = preferredDeviceId
        self.preferredDeviceName = preferredDeviceName
        self.selectedDeviceId = selectedDeviceId
        self.selectedDeviceName = selectedDeviceName
        self.selectedDeviceSupportsVolume = selectedDeviceSupportsVolume
        self.deviceSelectionReason = deviceSelectionReason
        self.usedFallbackDevice = usedFallbackDevice
        self.visibleDeviceSummary = visibleDeviceSummary
        self.errorMessage = errorMessage
        self.retryCount = retryCount
        self.scheduledAlarmTime = scheduledAlarmTime
        self.shortcutPrewarmExpected = shortcutPrewarmExpected
        self.prewarmStartedAt = prewarmStartedAt
        self.appIntentStartedAt = appIntentStartedAt
        self.tokenRefreshResult = tokenRefreshResult
        self.devicesFetchAttempts = devicesFetchAttempts
        self.selectedDeviceIdHash = selectedDeviceIdHash
        self.selectedDeviceType = selectedDeviceType
        self.transferResult = transferResult
        self.activeDeviceAfterTransfer = activeDeviceAfterTransfer
        self.playResult = playResult
        self.activeDeviceAfterPlay = activeDeviceAfterPlay
        self.isPlayingAfterPlay = isPlayingAfterPlay
        self.finalStatus = finalStatus
    }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case startedAt
        case completedAt
        case status
        case playlistUri
        case targetVolume
        case preferredDeviceId
        case preferredDeviceName
        case selectedDeviceId
        case selectedDeviceName
        case selectedDeviceSupportsVolume
        case deviceSelectionReason
        case usedFallbackDevice
        case visibleDeviceSummary
        case errorMessage
        case retryCount
        case scheduledAlarmTime
        case shortcutPrewarmExpected
        case prewarmStartedAt
        case appIntentStartedAt
        case tokenRefreshResult
        case devicesFetchAttempts
        case selectedDeviceIdHash
        case selectedDeviceType
        case transferResult
        case activeDeviceAfterTransfer
        case playResult
        case activeDeviceAfterPlay
        case isPlayingAfterPlay
        case finalStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        source = try container.decode(AlarmRunSource.self, forKey: .source)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        status = try container.decode(AlarmRunStatus.self, forKey: .status)
        playlistUri = try container.decode(String.self, forKey: .playlistUri)
        targetVolume = try container.decode(Int.self, forKey: .targetVolume)
        preferredDeviceId = try container.decodeIfPresent(String.self, forKey: .preferredDeviceId)
        preferredDeviceName = try container.decodeIfPresent(String.self, forKey: .preferredDeviceName)
        selectedDeviceId = try container.decodeIfPresent(String.self, forKey: .selectedDeviceId)
        selectedDeviceName = try container.decodeIfPresent(String.self, forKey: .selectedDeviceName)
        selectedDeviceSupportsVolume = try container.decodeIfPresent(Bool.self, forKey: .selectedDeviceSupportsVolume)
        deviceSelectionReason = try container.decodeIfPresent(DeviceSelectionReason.self, forKey: .deviceSelectionReason)
        usedFallbackDevice = try container.decodeIfPresent(Bool.self, forKey: .usedFallbackDevice) ?? false
        visibleDeviceSummary = try container.decodeIfPresent(String.self, forKey: .visibleDeviceSummary)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        scheduledAlarmTime = try container.decodeIfPresent(String.self, forKey: .scheduledAlarmTime)
        shortcutPrewarmExpected = try container.decodeIfPresent(Bool.self, forKey: .shortcutPrewarmExpected) ?? false
        prewarmStartedAt = try container.decodeIfPresent(Date.self, forKey: .prewarmStartedAt)
        appIntentStartedAt = try container.decodeIfPresent(Date.self, forKey: .appIntentStartedAt)
        tokenRefreshResult = try container.decodeIfPresent(String.self, forKey: .tokenRefreshResult)
        devicesFetchAttempts = try container.decodeIfPresent(Int.self, forKey: .devicesFetchAttempts) ?? retryCount
        selectedDeviceIdHash = try container.decodeIfPresent(String.self, forKey: .selectedDeviceIdHash)
        selectedDeviceType = try container.decodeIfPresent(String.self, forKey: .selectedDeviceType)
        transferResult = try container.decodeIfPresent(String.self, forKey: .transferResult)
        activeDeviceAfterTransfer = try container.decodeIfPresent(String.self, forKey: .activeDeviceAfterTransfer)
        playResult = try container.decodeIfPresent(String.self, forKey: .playResult)
        activeDeviceAfterPlay = try container.decodeIfPresent(String.self, forKey: .activeDeviceAfterPlay)
        isPlayingAfterPlay = try container.decodeIfPresent(Bool.self, forKey: .isPlayingAfterPlay)
        finalStatus = try container.decodeIfPresent(AlarmRouteFinalStatus.self, forKey: .finalStatus)
    }
}
