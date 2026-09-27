public struct FreeSpinSession: Codable, Equatable, Sendable {
    /// Spins still to play.
    public var remaining: Int
    /// Total bet locked in when the free spins were triggered.
    public let bet: Int
    public var played: Int
    public var totalWin: Int

    public init(remaining: Int, bet: Int, played: Int = 0, totalWin: Int = 0) {
        self.remaining = remaining
        self.bet = bet
        self.played = played
        self.totalWin = totalWin
    }
}

/// What one call to `SlotGame.play` did.
public struct SlotRound: Sendable, Equatable {
    public let outcome: SpinOutcome
    /// Free spins still pending after this spin, if any.
    public let freeSpinsAfter: FreeSpinSession?
    /// Set on the spin that finished a free-spin session, with its final totals.
    public let completedFreeSpins: FreeSpinSession?
    /// True when this spin started a new free-spin session.
    public var triggeredFreeSpins: Bool { !outcome.isFreeSpin && outcome.freeSpinsAwarded > 0 }
}

public enum SpinError: Error, Equatable {
    case invalidBet
    case insufficientFunds
}

/// Runs a slot session: charges the bet, pays wins and tracks free spins.
///
/// The wallet is only touched after the machine has produced its outcome, and the machine
/// never sees the wallet, so the balance cannot influence what lands.
public struct SlotGame: Codable, Equatable, Sendable {
    public private(set) var freeSpins: FreeSpinSession?

    public init(freeSpins: FreeSpinSession? = nil) {
        self.freeSpins = freeSpins
    }

    public var isInFreeSpins: Bool { freeSpins != nil }

    /// Plays one spin. During free spins the locked bet is used and nothing is charged.
    @discardableResult
    public mutating func play(
        machine: SlotMachine,
        bet: Int,
        ladder: BetLadder,
        wallet: inout Wallet,
        using random: RandomSource
    ) throws -> SlotRound {
        if var session = freeSpins {
            let outcome = machine.spin(totalBet: session.bet, isFreeSpin: true, using: random)
            session.remaining += outcome.freeSpinsAwarded - 1
            session.played += 1
            session.totalWin += outcome.totalWin
            try wallet.credit(outcome.totalWin)
            if session.remaining > 0 {
                freeSpins = session
                return SlotRound(outcome: outcome, freeSpinsAfter: session, completedFreeSpins: nil)
            }
            freeSpins = nil
            return SlotRound(outcome: outcome, freeSpinsAfter: nil, completedFreeSpins: session)
        }

        guard ladder.steps.contains(bet) else { throw SpinError.invalidBet }
        guard wallet.canAfford(bet) else { throw SpinError.insufficientFunds }
        try wallet.debit(bet)
        let outcome = machine.spin(totalBet: bet, isFreeSpin: false, using: random)
        try wallet.credit(outcome.totalWin)
        if outcome.freeSpinsAwarded > 0 {
            freeSpins = FreeSpinSession(remaining: outcome.freeSpinsAwarded, bet: bet)
        }
        return SlotRound(outcome: outcome, freeSpinsAfter: freeSpins, completedFreeSpins: nil)
    }
}
