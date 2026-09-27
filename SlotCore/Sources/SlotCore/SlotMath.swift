/// Exact expected return of a slot machine, per unit of total bet.
public struct SlotReturn: Sendable, Equatable {
    public let lineReturn: Double
    public let scatterReturn: Double
    /// Chance that one spin shows enough scatters to award free spins.
    public let freeSpinTriggerProbability: Double
    /// Expected free spins per trigger, counting retriggers.
    public let expectedFreeSpinsPerTrigger: Double
    public let freeSpinsReturn: Double

    public var total: Double { lineReturn + scatterReturn + freeSpinsReturn }
}

extension SlotMachine {
    /// Computes the return from the strips, lines and paytable — no simulation and no stored constant.
    ///
    /// Each reel's stop is uniform and independent, so on any payline the symbol on reel `r`
    /// follows that strip's composition. Enumerating every symbol combination weighted by those
    /// probabilities gives the exact line return; the scatter count distribution comes from
    /// sliding the 3-row window over each strip.
    public func exactReturn() -> SlotReturn {
        let marginals: [[(SlotSymbol, Double)]] = strips.map { strip in
            var counts = [SlotSymbol: Int]()
            for symbol in strip { counts[symbol, default: 0] += 1 }
            return counts
                .sorted { $0.key.rawValue < $1.key.rawValue }
                .map { ($0.key, Double($0.value) / Double(strip.count)) }
        }

        var expectedLineMultiplier = 0.0
        var combo = [SlotSymbol](repeating: .s1, count: SlotMachine.reelCount)
        func enumerate(reel: Int, probability: Double) {
            if reel == SlotMachine.reelCount {
                if let (symbol, count) = bestCombination(symbolAt: { combo[$0] }) {
                    expectedLineMultiplier += probability * Double(paytable.lineMultiplier(symbol, count: count))
                }
                return
            }
            for (symbol, p) in marginals[reel] {
                combo[reel] = symbol
                enumerate(reel: reel + 1, probability: probability * p)
            }
        }
        enumerate(reel: 0, probability: 1)

        // Every line carries totalBet / lines and has the same distribution, so the line return
        // per unit of total bet equals the expected multiplier of a single line.
        let lineReturn = expectedLineMultiplier

        var scatterDistribution = [1.0]
        for strip in strips {
            var reelDistribution = [Double](repeating: 0, count: SlotMachine.rowCount + 1)
            for stop in strip.indices {
                let visible = (0..<SlotMachine.rowCount).filter { strip[(stop + $0) % strip.count] == .scatter }.count
                reelDistribution[visible] += 1 / Double(strip.count)
            }
            var combined = [Double](repeating: 0, count: scatterDistribution.count + SlotMachine.rowCount)
            for (have, p) in scatterDistribution.enumerated() {
                for (add, q) in reelDistribution.enumerated() where q > 0 {
                    combined[have + add] += p * q
                }
            }
            scatterDistribution = combined
        }

        var scatterReturn = 0.0
        var triggerProbability = 0.0
        for (count, p) in scatterDistribution.enumerated() {
            scatterReturn += p * Double(paytable.scatterMultiplier(count: count))
            if count >= freeSpinRules.triggerCount { triggerProbability += p }
        }

        let retriggerRate = triggerProbability * Double(freeSpinRules.retriggerSpins)
        precondition(retriggerRate < 1, "free spins would never end")
        let expectedFreeSpins = Double(freeSpinRules.initialSpins) / (1 - retriggerRate)
        let freeSpinsReturn = triggerProbability * expectedFreeSpins
            * Double(freeSpinRules.winMultiplier) * (lineReturn + scatterReturn)

        return SlotReturn(
            lineReturn: lineReturn,
            scatterReturn: scatterReturn,
            freeSpinTriggerProbability: triggerProbability,
            expectedFreeSpinsPerTrigger: expectedFreeSpins,
            freeSpinsReturn: freeSpinsReturn
        )
    }
}
