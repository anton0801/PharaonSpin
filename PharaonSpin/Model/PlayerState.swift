import Foundation
import SlotCore

/// Everything that survives a relaunch. Stored as one JSON blob in UserDefaults.
struct PlayerState: Codable, Equatable {
    var wallet: Wallet
    var lastDailyClaim: Date?
    var hasClaimedDailyBonus = false
    var refill = RefillTimer()
    var lastWheelBonus: Date?

    var slotGames: [SlotTheme: SlotGame] = [:]
    var wheelGame = WheelGame()
    var bets: [GameKind: Int] = [:]

    var disclosureAccepted = false
    /// The player said YES on the pre-prompt; the system prompt was shown.
    var notificationsRequested = false
    var notificationPromptSnoozedUntil: Date?

    /// StoreKit transaction ids already credited, so a replayed transaction never pays twice.
    var creditedTransactions: Set<UInt64> = []

    static func fresh(rules: EconomyRules) -> PlayerState {
        PlayerState(wallet: Wallet(balance: rules.startingBalance))
    }
}

final class PlayerStore {
    private let key = "player.state.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PlayerState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlayerState.self, from: data)
    }

    func save(_ state: PlayerState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func erase() {
        defaults.removeObject(forKey: key)
    }
}
