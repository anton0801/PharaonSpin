public enum WheelPrize: Sendable, Equatable {
    /// Pays `bet × quarters ÷ 4` (quarters of the bet keep ×0.25 and ×0.5 exact in integers).
    case multiplier(quarters: Int)
    /// Awards this many free spins of the wheel at the same bet.
    case freeSpins(Int)

    public var multiplier: Double? {
        if case let .multiplier(quarters) = self { return Double(quarters) / 4 }
        return nil
    }
}

/// Artwork printed on the sector in the wheel image. The prize comes from the table, never from the art.
public enum WheelArtwork: String, Sendable, Equatable {
    case gift, plus100, vip, bell, freeSpins, plus50, medal
}

public struct WheelSector: Sendable, Equatable, Identifiable {
    /// Zero-based, clockwise from the sector at the top of the artwork.
    public let id: Int
    public let artwork: WheelArtwork
    public let prize: WheelPrize
    public let weight: Int
}

/// 12-sector weighted wheel with an exactly computed return.
public struct FortuneWheel: Sendable {
    public let sectors: [WheelSector]

    public init(sectors: [WheelSector]) {
        precondition(!sectors.isEmpty && sectors.allSatisfy { $0.weight > 0 })
        self.sectors = sectors
    }

    /// Clockwise from the top of the artwork. The multipliers are the spec's; the weights were
    /// recomputed because the specified ones (which sum to 134, not 154) return ~158%.
    public static let standard = FortuneWheel(sectors: [
        WheelSector(id: 0, artwork: .gift, prize: .multiplier(quarters: 8), weight: 6),
        WheelSector(id: 1, artwork: .plus100, prize: .multiplier(quarters: 4), weight: 24),
        WheelSector(id: 2, artwork: .vip, prize: .multiplier(quarters: 40), weight: 1),
        WheelSector(id: 3, artwork: .gift, prize: .multiplier(quarters: 8), weight: 6),
        WheelSector(id: 4, artwork: .bell, prize: .multiplier(quarters: 2), weight: 24),
        WheelSector(id: 5, artwork: .plus100, prize: .multiplier(quarters: 4), weight: 24),
        WheelSector(id: 6, artwork: .freeSpins, prize: .freeSpins(5), weight: 1),
        WheelSector(id: 7, artwork: .bell, prize: .multiplier(quarters: 2), weight: 24),
        WheelSector(id: 8, artwork: .plus50, prize: .multiplier(quarters: 1), weight: 24),
        WheelSector(id: 9, artwork: .freeSpins, prize: .freeSpins(5), weight: 1),
        WheelSector(id: 10, artwork: .plus100, prize: .multiplier(quarters: 4), weight: 24),
        WheelSector(id: 11, artwork: .medal, prize: .multiplier(quarters: 20), weight: 1),
    ])

    public var totalWeight: Int { sectors.reduce(0) { $0 + $1.weight } }

    public func probability(ofSector index: Int) -> Double {
        Double(sectors[index].weight) / Double(totalWeight)
    }

    /// Weighted pick of a sector index. Decided before any animation starts.
    public func spin(using random: RandomSource) -> Int {
        var ticket = random.uniform(totalWeight)
        for sector in sectors {
            if ticket < sector.weight { return sector.id }
            ticket -= sector.weight
        }
        preconditionFailure("weights exhausted")
    }

    public func payout(sector index: Int, bet: Int) -> Int {
        guard case let .multiplier(quarters) = sectors[index].prize else { return 0 }
        return bet * quarters / 4
    }

    /// Expected payout per unit bet from multiplier sectors alone.
    public var returnWithoutFreeSpins: Double {
        let weighted = sectors.reduce(0.0) { sum, sector in
            sum + Double(sector.weight) * (sector.prize.multiplier ?? 0)
        }
        return weighted / Double(totalWeight)
    }

    /// Probability that a spin lands on a free-spins sector.
    public var freeSpinProbability: Double {
        let weight = sectors.reduce(0) { sum, sector in
            if case .freeSpins = sector.prize { return sum + sector.weight }
            return sum
        }
        return Double(weight) / Double(totalWeight)
    }

    /// Expected free spins awarded per spin (probability × spins per hit, summed over FS sectors).
    public var expectedFreeSpinsPerSpin: Double {
        sectors.reduce(0.0) { sum, sector in
            if case let .freeSpins(count) = sector.prize {
                return sum + Double(sector.weight) / Double(totalWeight) * Double(count)
            }
            return sum
        }
    }

    /// Exact return to player, counting free spins won during free spins.
    ///
    /// A free spin is worth `v = R₀ + e·v` (R₀ the multiplier return, e the expected free spins
    /// per spin), so `v = R₀ / (1 − e)`; a paid spin is worth the same.
    public var exactRTP: Double {
        let e = expectedFreeSpinsPerSpin
        precondition(e < 1, "free spins would never end")
        return returnWithoutFreeSpins / (1 - e)
    }
}

public enum WheelSpinKind: String, Codable, Sendable {
    /// Charged at the selected bet.
    case paid
    /// One of the free spins won on an FS sector.
    case freeSpin
    /// The periodic free bonus spin, played at a fixed stake.
    case bonus
}

public struct WheelRound: Sendable, Equatable {
    public let sector: Int
    public let kind: WheelSpinKind
    public let stake: Int
    public let payout: Int
    public let freeSpinsAwarded: Int
    public let freeSpinsRemaining: Int
}

/// Wheel session: charges the bet, pays the prize and tracks free spins.
public struct WheelGame: Codable, Equatable, Sendable {
    public private(set) var freeSpinsRemaining: Int
    public private(set) var freeSpinStake: Int

    public init(freeSpinsRemaining: Int = 0, freeSpinStake: Int = 0) {
        self.freeSpinsRemaining = freeSpinsRemaining
        self.freeSpinStake = freeSpinStake
    }

    /// Plays one spin. Pending free spins are always played first, at the stake that won them.
    /// `bonusStake` plays the periodic free bonus spin instead of a paid spin.
    @discardableResult
    public mutating func play(
        wheel: FortuneWheel,
        bet: Int,
        ladder: BetLadder,
        bonusStake: Int? = nil,
        wallet: inout Wallet,
        using random: RandomSource
    ) throws -> WheelRound {
        let kind: WheelSpinKind
        let stake: Int
        if freeSpinsRemaining > 0 {
            kind = .freeSpin
            stake = freeSpinStake
            freeSpinsRemaining -= 1
        } else if let bonusStake {
            kind = .bonus
            stake = bonusStake
        } else {
            guard ladder.steps.contains(bet) else { throw SpinError.invalidBet }
            guard wallet.canAfford(bet) else { throw SpinError.insufficientFunds }
            try wallet.debit(bet)
            kind = .paid
            stake = bet
        }

        let sector = wheel.spin(using: random)
        let payout = wheel.payout(sector: sector, bet: stake)
        try wallet.credit(payout)

        var awarded = 0
        if case let .freeSpins(count) = wheel.sectors[sector].prize {
            awarded = count
            freeSpinsRemaining += count
            freeSpinStake = stake
        }
        if freeSpinsRemaining == 0 { freeSpinStake = 0 }

        return WheelRound(
            sector: sector,
            kind: kind,
            stake: stake,
            payout: payout,
            freeSpinsAwarded: awarded,
            freeSpinsRemaining: freeSpinsRemaining
        )
    }
}

/// Maps a decided sector to a rotation of the wheel artwork, for a pointer fixed at the top.
public struct WheelGeometry: Sendable {
    public let sectorCount: Int
    /// Clockwise angle from the top of the artwork to the centre of sector 0, in degrees.
    public let firstSectorCenter: Double

    public init(sectorCount: Int, firstSectorCenter: Double) {
        self.sectorCount = sectorCount
        self.firstSectorCenter = firstSectorCenter
    }

    public var sectorWidth: Double { 360 / Double(sectorCount) }

    public func center(ofSector index: Int) -> Double {
        firstSectorCenter + Double(index) * sectorWidth
    }

    /// Cumulative clockwise rotation that makes at least `turns` full revolutions from
    /// `current` and stops with `sector` under the pointer, `offset` sector-widths off centre.
    public func targetRotation(from current: Double, sector: Int, turns: Int, offset: Double) -> Double {
        let landing = -(center(ofSector: sector) + offset * sectorWidth)
        let base = current + Double(turns) * 360
        let delta = (landing - base).truncatingRemainder(dividingBy: 360)
        return base + (delta < 0 ? delta + 360 : delta)
    }

    /// The sector under the pointer for a given rotation.
    public func sector(atRotation rotation: Double) -> Int {
        var angle = (-rotation - firstSectorCenter + sectorWidth / 2).truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return Int(angle / sectorWidth) % sectorCount
    }
}
