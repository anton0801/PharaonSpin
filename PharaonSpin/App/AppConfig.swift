import Foundation

enum AppConfig {
    /// Master switch for purchases. When false the store and every buy button are hidden,
    /// and only the free coin sources remain.
    static let storeEnabled = false

    /// Show Restore Purchases in Settings. Only meaningful once non-consumable products exist.
    static let hasNonConsumables = false

    static let sessionReminderInterval: TimeInterval = 60 * 60
    /// SKIP on the notification pre-prompt keeps it away this long.
    static let notificationPromptSnooze: TimeInterval = 7 * 24 * 60 * 60

    // Placeholders: replace with the published pages before submission.
    static let privacyPolicyURL = URL(string: "https://docs.google.com/document/d/1XFPL31oQNbTrDWxCTABWPtDSZ-I_TeW-ySehMI6FyuI/edit?usp=sharing")!
    static let termsURL = URL(string: "https://docs.google.com/document/d/1XFPL31oQNbTrDWxCTABWPtDSZ-I_TeW-ySehMI6FyuI/")!
    /// National Council on Problem Gambling — help and treatment finder.
    static let responsiblePlayURL = URL(string: "https://www.ncpgambling.org/help-treatment/")!

    static let coinPacks: [CoinPack] = [
        CoinPack(id: "app.PharaonSpin.coins.starter", name: "Starter", coins: 250_000),
        CoinPack(id: "app.PharaonSpin.coins.stack", name: "Stack", coins: 1_000_000),
        CoinPack(id: "app.PharaonSpin.coins.vault", name: "Vault", coins: 3_000_000),
        CoinPack(id: "app.PharaonSpin.coins.pharaoh", name: "Pharaoh", coins: 10_000_000),
    ]
}

struct CoinPack: Identifiable, Hashable {
    let id: String
    let name: String
    let coins: Int
}
