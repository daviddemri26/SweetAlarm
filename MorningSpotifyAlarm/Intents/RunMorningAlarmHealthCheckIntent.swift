import AppIntents
import Foundation

struct RunMorningAlarmHealthCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Morning Alarm Health Check"
    static var description = IntentDescription("Checks Spotify authentication, playlist setup, device visibility, and fallback readiness.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await HealthCheckService().run()
        return .result(dialog: "\(result.message)")
    }
}
