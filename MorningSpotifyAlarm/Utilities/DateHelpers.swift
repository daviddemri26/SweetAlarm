import Foundation

enum DateHelpers {
    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func timeString(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return displayDateTime.string(from: date)
    }
}
