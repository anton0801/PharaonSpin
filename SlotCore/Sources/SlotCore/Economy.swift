import Foundation

/// Free coin sources. None of this touches spin outcomes; the current time is always passed in.
public struct EconomyRules: Sendable, Equatable {
    public var startingBalance: Int
    public var dailyBonus: Int
    /// Unclaimed daily bonuses stack up to this many days.
    public var dailyBonusMaxDays: Int
    public var refillAmount: Int
    /// Wait before a refill is paid once the balance drops below the minimum bet.
    public var refillDelay: TimeInterval
    public var wheelBonusInterval: TimeInterval
    /// Stake used for the periodic free wheel spin (no coins are charged).
    public var wheelBonusStake: Int

    public static let standard = EconomyRules(
        startingBalance: 100_000,
        dailyBonus: 25_000,
        dailyBonusMaxDays: 3,
        refillAmount: 20_000,
        refillDelay: 20 * 60,
        wheelBonusInterval: 4 * 60 * 60,
        wheelBonusStake: 25_000
    )
}

public enum DailyBonus {
    /// Calendar days of bonus waiting to be claimed, capped at `maxDays`. The first ever claim is available immediately.
    public static func claimableDays(lastClaim: Date?, now: Date, calendar: Calendar, maxDays: Int) -> Int {
        guard let lastClaim else { return 1 }
        let from = calendar.startOfDay(for: lastClaim)
        let to = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return min(max(days, 0), maxDays)
    }

    /// When the next day of bonus becomes available after a claim at `lastClaim`.
    public static func nextAvailable(after lastClaim: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: lastClaim)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? lastClaim.addingTimeInterval(86_400)
    }
}

/// Timer that refills an empty balance.
public struct RefillTimer: Codable, Equatable, Sendable {
    /// When the balance was first seen below the minimum bet; nil when no refill is pending.
    public private(set) var startedAt: Date?

    public init(startedAt: Date? = nil) {
        self.startedAt = startedAt
    }

    public func dueDate(delay: TimeInterval) -> Date? {
        startedAt?.addingTimeInterval(delay)
    }

    /// Advances the timer and returns the coins to credit now (0 when nothing is due).
    /// Refills never start while free spins are pending, since those still pay out.
    public mutating func update(balance: Int, minimumBet: Int, freeSpinsPending: Bool, now: Date, rules: EconomyRules) -> Int {
        guard balance < minimumBet, !freeSpinsPending else {
            startedAt = nil
            return 0
        }
        guard let startedAt else {
            self.startedAt = now
            return 0
        }
        guard now >= startedAt.addingTimeInterval(rules.refillDelay) else { return 0 }
        self.startedAt = nil
        return rules.refillAmount
    }
}

public enum WheelBonus {
    public static func isAvailable(lastSpin: Date?, now: Date, interval: TimeInterval) -> Bool {
        guard let lastSpin else { return true }
        return now >= lastSpin.addingTimeInterval(interval)
    }

    public static func nextAvailable(lastSpin: Date?, interval: TimeInterval) -> Date? {
        lastSpin?.addingTimeInterval(interval)
    }
}
