import Foundation

final class AlarmConfigStore {
    static let shared = AlarmConfigStore()

    private let defaults = UserDefaults.standard
    private let configurationKey = "alarmConfiguration.v1"
    private let authStateKey = "spotifyAuthState.v1"
    private let logsKey = "alarmRunLogs.v1"
    private let maxLogs = 100

    private init() {}

    func loadConfiguration() -> AlarmConfiguration {
        guard let data = defaults.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(AlarmConfiguration.self, from: data) else {
            return AlarmConfiguration()
        }
        return configuration
    }

    func saveConfiguration(_ configuration: AlarmConfiguration) {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: configurationKey)
        }
    }

    func loadAuthState() -> SpotifyAuthState? {
        guard let data = defaults.data(forKey: authStateKey) else { return nil }
        return try? JSONDecoder().decode(SpotifyAuthState.self, from: data)
    }

    func saveAuthState(_ state: SpotifyAuthState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: authStateKey)
        }
    }

    func clearAuthState() {
        defaults.removeObject(forKey: authStateKey)
    }

    func loadLogs() -> [AlarmRunLog] {
        guard let data = defaults.data(forKey: logsKey),
              let logs = try? JSONDecoder().decode([AlarmRunLog].self, from: data) else {
            return []
        }
        return logs.sorted { $0.startedAt > $1.startedAt }
    }

    func appendLog(_ log: AlarmRunLog) {
        var logs = loadLogs()
        logs.insert(log, at: 0)
        logs = Array(logs.prefix(maxLogs))
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: logsKey)
        }
    }
}
