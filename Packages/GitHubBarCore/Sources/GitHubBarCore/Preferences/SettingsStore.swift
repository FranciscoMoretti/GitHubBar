import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedLogin: String?
    public var repositoryScope: RepositoryScope
    public var refreshCadence: RefreshCadence
    public var launchAtLogin: Bool

    public init(
        selectedLogin: String? = nil,
        repositoryScope: RepositoryScope = .all,
        refreshCadence: RefreshCadence = .fiveMinutes,
        launchAtLogin: Bool = false
    ) {
        self.selectedLogin = selectedLogin
        self.repositoryScope = repositoryScope
        self.refreshCadence = refreshCadence
        self.launchAtLogin = launchAtLogin
    }
}

public protocol SettingsStore: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async
}

public actor InMemorySettingsStore: SettingsStore {
    private var settings: AppSettings

    public init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    public func load() async -> AppSettings { settings }

    public func save(_ settings: AppSettings) async {
        self.settings = settings
    }
}

public actor UserDefaultsSettingsStore: SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "githubbar.settings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() async -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) async {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
