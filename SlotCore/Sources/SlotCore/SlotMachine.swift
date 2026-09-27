/// One winning payline.
public struct LineWin: Sendable, Equatable {
    /// Zero-based index into the machine's paylines (L1 is 0).
    public let lineIndex: Int
    public let symbol: SlotSymbol
    /// Number of matching reels counted from reel 1.
    public let count: Int
    public let payout: Int
    /// Flat cell indices (`reel * 3 + row`) that form the win.
    public let cells: [Int]
}

/// The complete, already-decided result of one spin.
public struct SpinOutcome: Sendable, Equatable {
    public let totalBet: Int
    public let isFreeSpin: Bool
    /// Start position on each strip; the visible rows are `stop`, `stop + 1`, `stop + 2`.
    public let stops: [Int]
    /// Visible symbols, flat: index `reel * rows + row`.
    public let grid: [SlotSymbol]
    public let lineWins: [LineWin]
    public let scatterCells: [Int]
    public let scatterWin: Int
    /// 1 in the base game, the free-spin multiplier during free spins. Already applied to every payout.
    public let winMultiplier: Int
    public let freeSpinsAwarded: Int

    public var scatterCount: Int { scatterCells.count }
    public var totalWin: Int { lineWins.reduce(scatterWin) { $0 + $1.payout } }

    public func symbol(reel: Int, row: Int) -> SlotSymbol {
        grid[reel * SlotMachine.rowCount + row]
    }
}

/// 5×3 line slot. Pure: the outcome is a function of the random source and nothing else.
public struct SlotMachine: Sendable {
    public static let reelCount = 5
    public static let rowCount = 3

    public let strips: [[SlotSymbol]]
    public let paylines: [[Int]]
    public let paytable: Paytable
    public let freeSpinRules: FreeSpinRules

    public init(strips: [[SlotSymbol]], paylines: [[Int]], paytable: Paytable, freeSpinRules: FreeSpinRules) {
        precondition(strips.count == SlotMachine.reelCount, "a machine needs \(SlotMachine.reelCount) strips")
        precondition(paylines.allSatisfy { $0.count == SlotMachine.reelCount && $0.allSatisfy { (0..<SlotMachine.rowCount).contains($0) } })
        self.strips = strips
        self.paylines = paylines
        self.paytable = paytable
        self.freeSpinRules = freeSpinRules
    }

    public static let standard = SlotMachine(
        strips: ReelStrips.standard,
        paylines: Paylines.standard,
        paytable: .standard,
        freeSpinRules: .standard
    )

    /// Picks a uniformly random stop on every strip and evaluates it.
    public func spin(totalBet: Int, isFreeSpin: Bool, using random: RandomSource) -> SpinOutcome {
        var stops = [Int](repeating: 0, count: SlotMachine.reelCount)
        for reel in 0..<SlotMachine.reelCount {
            stops[reel] = random.uniform(strips[reel].count)
        }
        return evaluate(stops: stops, totalBet: totalBet, isFreeSpin: isFreeSpin)
    }

    public func visibleSymbols(stops: [Int]) -> [SlotSymbol] {
        var grid = [SlotSymbol]()
        grid.reserveCapacity(SlotMachine.reelCount * SlotMachine.rowCount)
        for reel in 0..<SlotMachine.reelCount {
            let strip = strips[reel]
            for row in 0..<SlotMachine.rowCount {
                grid.append(strip[(stops[reel] + row) % strip.count])
            }
        }
        return grid
    }

    public func evaluate(stops: [Int], totalBet: Int, isFreeSpin: Bool) -> SpinOutcome {
        precondition(totalBet % paylines.count == 0, "total bet must split evenly across \(paylines.count) lines")
        let grid = visibleSymbols(stops: stops)
        let multiplier = isFreeSpin ? freeSpinRules.winMultiplier : 1
        let lineBet = totalBet / paylines.count

        var lineWins: [LineWin] = []
        for (index, line) in paylines.enumerated() {
            guard let (symbol, count) = bestCombination(symbolAt: { grid[$0 * SlotMachine.rowCount + line[$0]] }) else { continue }
            let cells = (0..<count).map { $0 * SlotMachine.rowCount + line[$0] }
            let payout = lineBet * paytable.lineMultiplier(symbol, count: count) * multiplier
            lineWins.append(LineWin(lineIndex: index, symbol: symbol, count: count, payout: payout, cells: cells))
        }

        let scatterCells = grid.indices.filter { grid[$0] == .scatter }
        let scatterWin = totalBet * paytable.scatterMultiplier(count: scatterCells.count) * multiplier
        let triggered = scatterCells.count >= freeSpinRules.triggerCount
        let awarded = triggered ? (isFreeSpin ? freeSpinRules.retriggerSpins : freeSpinRules.initialSpins) : 0

        return SpinOutcome(
            totalBet: totalBet,
            isFreeSpin: isFreeSpin,
            stops: stops,
            grid: grid,
            lineWins: lineWins,
            scatterCells: scatterCells,
            scatterWin: scatterWin,
            winMultiplier: multiplier,
            freeSpinsAwarded: awarded
        )
    }

    /// The highest paying left-to-right combination on one line, or nil when the line pays nothing.
    /// WILD stands in for any symbol except SCATTER. `symbolAt(reel)` returns the line's symbol on that reel.
    func bestCombination(symbolAt: (Int) -> SlotSymbol) -> (SlotSymbol, Int)? {
        let first = symbolAt(0)
        if first == .scatter { return nil }
        if first != .wild {
            let count = matchLength(of: first, symbolAt: symbolAt)
            return paytable.lineMultiplier(first, count: count) > 0 ? (first, count) : nil
        }
        // Leading wilds: try every paying symbol and keep the best.
        var best: (SlotSymbol, Int)?
        var bestMultiplier = 0
        for symbol in SlotSymbol.paying {
            let count = matchLength(of: symbol, symbolAt: symbolAt)
            let multiplier = paytable.lineMultiplier(symbol, count: count)
            if multiplier > bestMultiplier {
                bestMultiplier = multiplier
                best = (symbol, count)
            }
        }
        return best
    }

    private func matchLength(of symbol: SlotSymbol, symbolAt: (Int) -> SlotSymbol) -> Int {
        var count = 0
        for reel in 0..<SlotMachine.reelCount {
            let cell = symbolAt(reel)
            guard cell == symbol || cell == .wild else { break }
            count += 1
        }
        return count
    }
}
