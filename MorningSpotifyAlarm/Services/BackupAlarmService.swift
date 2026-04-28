import ActivityKit
import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
struct BackupAlarmMetadata: AlarmMetadata {
    let label: String
}

@available(iOS 26.0, *)
final class BackupAlarmService {
    func scheduleBackup(for configuration: AlarmConfiguration) async throws -> String {
        let authorization = try await AlarmManager.shared.requestAuthorization()
        guard authorization == .authorized else {
            throw UserFacingError.spotifyAPI("AlarmKit permission was not granted.")
        }

        let backupTime = backupHourMinute(for: configuration)
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: "Backup alarm",
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
            )
        )
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: BackupAlarmMetadata(label: "Morning Spotify backup"),
            tintColor: .red
        )
        let alarmConfiguration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .relative(
                Alarm.Schedule.Relative(
                    time: Alarm.Schedule.Relative.Time(hour: backupTime.hour, minute: backupTime.minute),
                    repeats: recurrence(for: configuration.repeatDays)
                )
            ),
            attributes: attributes,
            sound: .default
        )

        _ = try await AlarmManager.shared.schedule(id: configuration.id, configuration: alarmConfiguration)
        return String(format: "Backup alarm scheduled for %02d:%02d.", backupTime.hour, backupTime.minute)
    }

    func cancelBackup(id: UUID) throws {
        try AlarmManager.shared.cancel(id: id)
    }

    private func backupHourMinute(for configuration: AlarmConfiguration) -> (hour: Int, minute: Int) {
        let total = configuration.hour * 60 + configuration.minute + configuration.fallbackDelayMinutes
        return ((total / 60) % 24, total % 60)
    }

    private func recurrence(for weekdays: [Weekday]) -> Alarm.Schedule.Relative.Recurrence {
        guard !weekdays.isEmpty else { return .never }
        let mapped = weekdays.compactMap { weekday -> Locale.Weekday? in
            switch weekday {
            case .sunday: .sunday
            case .monday: .monday
            case .tuesday: .tuesday
            case .wednesday: .wednesday
            case .thursday: .thursday
            case .friday: .friday
            case .saturday: .saturday
            }
        }
        return .weekly(mapped)
    }
}
