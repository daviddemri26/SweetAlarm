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

struct AlarmRunLog: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var source: AlarmRunSource
    var startedAt: Date
    var completedAt: Date?
    var status: AlarmRunStatus
    var playlistUri: String
    var targetVolume: Int
    var selectedDeviceId: String?
    var selectedDeviceName: String?
    var selectedDeviceSupportsVolume: Bool?
    var errorMessage: String?
    var retryCount: Int

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
}
