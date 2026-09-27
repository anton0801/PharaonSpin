public enum WalletError: Error, Equatable {
    case insufficientFunds
    case invalidAmount
}

/// In-game coin balance. Coins have no cash value and can never go below zero.
public struct Wallet: Codable, Equatable, Sendable {
    public private(set) var balance: Int

    public init(balance: Int) {
        self.balance = max(0, balance)
    }

    public func canAfford(_ amount: Int) -> Bool {
        amount >= 0 && amount <= balance
    }

    public mutating func debit(_ amount: Int) throws {
        guard amount >= 0 else { throw WalletError.invalidAmount }
        guard amount <= balance else { throw WalletError.insufficientFunds }
        balance -= amount
    }

    public mutating func credit(_ amount: Int) throws {
        guard amount >= 0 else { throw WalletError.invalidAmount }
        let (sum, overflow) = balance.addingReportingOverflow(amount)
        balance = overflow ? Int.max : sum
    }
}

/// The fixed bet steps shared by every game.
public struct BetLadder: Sendable, Equatable {
    public let steps: [Int]

    public init(steps: [Int]) {
        precondition(!steps.isEmpty && steps == steps.sorted(), "steps must be ascending")
        self.steps = steps
    }

    public static let standard = BetLadder(steps: [1_000, 5_000, 10_000, 50_000, 100_000, 380_000, 1_000_000])

    public var minimum: Int { steps[0] }

    /// The next step up, or nil when there is none or the balance cannot cover it.
    public func increased(from bet: Int, balance: Int) -> Int? {
        guard let next = steps.first(where: { $0 > bet }), next <= balance else { return nil }
        return next
    }

    /// The next step down, or nil at the minimum.
    public func decreased(from bet: Int) -> Int? {
        steps.last(where: { $0 < bet })
    }

    /// The bet itself if it is a valid step the balance covers, otherwise the largest step
    /// the balance covers (never below the minimum step).
    public func clamped(_ bet: Int, balance: Int) -> Int {
        if steps.contains(bet), bet <= balance { return bet }
        let affordable = steps.last(where: { $0 <= min(bet, balance) }) ?? minimum
        return affordable
    }
}
