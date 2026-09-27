import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.sound) } }
    @Published var vibrationOn: Bool { didSet { defaults.set(vibrationOn, forKey: Keys.vibration) } }
    /// Parental switch: off hides the store and every purchase button.
    @Published var storeOn: Bool { didSet { defaults.set(storeOn, forKey: Keys.store) } }
    @Published var sessionReminderOn: Bool { didSet { defaults.set(sessionReminderOn, forKey: Keys.reminder) } }

    private let defaults: UserDefaults

    private enum Keys {
        static let sound = "settings.sound"
        static let vibration = "settings.vibration"
        static let store = "settings.store"
        static let reminder = "settings.sessionReminder"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Keys.sound: true, Keys.vibration: true, Keys.store: true, Keys.reminder: true])
        soundOn = defaults.bool(forKey: Keys.sound)
        vibrationOn = defaults.bool(forKey: Keys.vibration)
        storeOn = defaults.bool(forKey: Keys.store)
        sessionReminderOn = defaults.bool(forKey: Keys.reminder)
    }

    /// Store entry points are visible only when the build flag and the parental switch allow it.
    var storeVisible: Bool { AppConfig.storeEnabled && storeOn }

    func reset() {
        soundOn = true
        vibrationOn = true
        storeOn = true
        sessionReminderOn = true
    }
}
