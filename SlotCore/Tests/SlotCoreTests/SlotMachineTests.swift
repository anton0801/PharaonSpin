import XCTest
import SlotCore

final class ReelStripTests: XCTestCase {
    func testStripCompositionMatchesDocumentedTable() {
        let expected: [SlotSymbol: [Int]] = [
            .s1: [3, 3, 3, 3, 3],
            .s2: [4, 2, 2, 2, 4],
            .s3: [12, 14, 14, 14, 12],
            .s4: [5, 5, 5, 5, 5],
            .s5: [5, 4, 4, 4, 5],
            .s6: [4, 4, 4, 4, 4],
            .s7: [3, 3, 3, 3, 3],
            .s8: [2, 2, 2, 2, 2],
            .s9: [1, 1, 1, 1, 1],
            .wild: [0, 1, 1, 1, 0],
            .scatter: [1, 1, 1, 1, 1],
        ]
        for (reel, strip) in ReelStrips.standard.enumerated() {
            XCTAssertEqual(strip.count, 40, "reel \(reel + 1) length")
            for symbol in SlotSymbol.allCases {
                XCTAssertEqual(strip.filter { $0 == symbol }.count, expected[symbol]![reel], "\(symbol) on reel \(reel + 1)")
            }
        }
    }

    func testNoSymbolRepeatsMoreThanTwiceInARowIncludingWrapAround() {
        for (reel, strip) in ReelStrips.standard.enumerated() {
            for i in strip.indices {
                let run = [strip[i], strip[(i + 1) % strip.count], strip[(i + 2) % strip.count]]
                XCTAssertFalse(run.allSatisfy { $0 == run[0] }, "reel \(reel + 1) has three \(run[0]) from stop \(i)")
            }
        }
    }

    func testTwentyDistinctPaylines() {
        XCTAssertEqual(Paylines.standard.count, 20)
        XCTAssertEqual(Set(Paylines.standard.map { $0.map(String.init).joined() }).count, 20)
    }
}

final class SlotEvaluationTests: XCTestCase {
    /// Reels where stop 0 shows rows [a, b, c] so tests can place symbols exactly.
    private func machine(columns: [[SlotSymbol]]) -> SlotMachine {
        let filler: [SlotSymbol] = [.s4, .s5, .s6, .s7]
        let strips = columns.map { $0 + filler }
        return SlotMachine(strips: strips, paylines: Paylines.standard, paytable: .standard, freeSpinRules: .standard)
    }

    func testThreeOfAKindOnMiddleLinePaysLineBetTimesMultiplier() {
        let m = machine(columns: [
            [.s6, .s9, .s6],
            [.s7, .s9, .s7],
            [.s4, .s9, .s4],
            [.s5, .s2, .s5],
            [.s6, .s3, .s6],
        ])
        let outcome = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 20_000, isFreeSpin: false)
        let middle = outcome.lineWins.first { $0.lineIndex == 0 }
        XCTAssertEqual(middle?.symbol, .s9)
        XCTAssertEqual(middle?.count, 3)
        XCTAssertEqual(middle?.payout, 1_000 * 60)
        XCTAssertEqual(middle?.cells, [1, 4, 7])
    }

    func testWildSubstitutesButNotForScatterAndOnlyBestCombinationPays() {
        let m = machine(columns: [
            [.s1, .s8, .s1],
            [.s2, .wild, .s2],
            [.s3, .s8, .s3],
            [.s4, .wild, .s4],
            [.s5, .scatter, .s5],
        ])
        let outcome = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 20_000, isFreeSpin: false)
        let middle = outcome.lineWins.first { $0.lineIndex == 0 }
        XCTAssertEqual(middle?.symbol, .s8)
        XCTAssertEqual(middle?.count, 4, "scatter on reel 5 must not be substituted")
        XCTAssertEqual(middle?.payout, 1_000 * 150)
    }

    func testLeadingWildPicksHighestPayingInterpretation() {
        let m = machine(columns: [
            [.s6, .wild, .s6],
            [.s7, .wild, .s7],
            [.s4, .wild, .s4],
            [.s5, .s1, .s5],
            [.s6, .s2, .s6],
        ])
        let outcome = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 20_000, isFreeSpin: false)
        let middle = outcome.lineWins.first { $0.lineIndex == 0 }
        // WILD WILD WILD S1: S9×3 (60) beats S1×4 (15).
        XCTAssertEqual(middle?.symbol, .s9)
        XCTAssertEqual(middle?.count, 3)
    }

    func testScatterPaysAnywhereFromTotalBetAndAwardsTenFreeSpins() {
        let m = machine(columns: [
            [.scatter, .s1, .s2],
            [.s3, .s4, .scatter],
            [.s5, .scatter, .s6],
            [.s7, .s8, .s1],
            [.s2, .s3, .s4],
        ])
        let base = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 10_000, isFreeSpin: false)
        XCTAssertEqual(base.scatterCount, 3)
        XCTAssertEqual(base.scatterWin, 20_000)
        XCTAssertEqual(base.freeSpinsAwarded, 10)

        let free = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 10_000, isFreeSpin: true)
        XCTAssertEqual(free.scatterWin, 40_000, "free-spin wins are doubled")
        XCTAssertEqual(free.freeSpinsAwarded, 5, "retrigger adds five")
    }

    func testWinsOnSeveralLinesAreSummed() {
        let m = machine(columns: [
            [.s9, .s9, .s9],
            [.s9, .s9, .s9],
            [.s9, .s9, .s9],
            [.s1, .s2, .s3],
            [.s4, .s5, .s6],
        ])
        let outcome = m.evaluate(stops: [0, 0, 0, 0, 0], totalBet: 20_000, isFreeSpin: false)
        XCTAssertEqual(outcome.lineWins.count, 20, "every line crosses three S9 on reels 1-3")
        XCTAssertEqual(outcome.totalWin, 20 * 1_000 * 60)
    }
}

final class FreeSpinSessionTests: XCTestCase {
    func testFreeSpinsAreNotChargedUseLockedBetAndReportCompletion() throws {
        let machine = SlotMachine.standard
        // Find stops showing three scatters on the standard strips.
        let scatterStops = machine.strips.map { strip in strip.firstIndex(of: .scatter)! }
        var stops = scatterStops
        stops[3] = (scatterStops[3] + 20) % 40
        stops[4] = (scatterStops[4] + 20) % 40
        let trigger = machine.evaluate(stops: stops, totalBet: 10_000, isFreeSpin: false)
        XCTAssertGreaterThanOrEqual(trigger.scatterCount, 3)

        var game = SlotGame()
        var wallet = Wallet(balance: 50_000)
        let script = ScriptedRandomSource(stops.map { ($0, 40) })
        let round = try game.play(machine: machine, bet: 10_000, ladder: .standard, wallet: &wallet, using: script)
        XCTAssertTrue(round.triggeredFreeSpins)
        XCTAssertEqual(game.freeSpins?.remaining, 10)
        XCTAssertEqual(game.freeSpins?.bet, 10_000)
        XCTAssertEqual(wallet.balance, 50_000 - 10_000 + round.outcome.totalWin)

        let random = SeededRandomSource(seed: 7)
        var played = 0
        var completed: FreeSpinSession?
        while game.isInFreeSpins {
            let before = wallet.balance
            // A different bet argument must be ignored while free spins run.
            let r = try game.play(machine: machine, bet: 1_000_000, ladder: .standard, wallet: &wallet, using: random)
            XCTAssertTrue(r.outcome.isFreeSpin)
            XCTAssertEqual(r.outcome.totalBet, 10_000)
            XCTAssertEqual(wallet.balance, before + r.outcome.totalWin, "free spins never charge")
            played += 1
            completed = r.completedFreeSpins
        }
        XCTAssertGreaterThanOrEqual(played, 10)
        XCTAssertEqual(completed?.played, played)
    }

    func testSpinRejectsBetsOffTheLadderAndBetsAboveBalance() {
        var game = SlotGame()
        var wallet = Wallet(balance: 4_000)
        let random = SeededRandomSource(seed: 1)
        XCTAssertThrowsError(try game.play(machine: .standard, bet: 1_234, ladder: .standard, wallet: &wallet, using: random))
        XCTAssertThrowsError(try game.play(machine: .standard, bet: 5_000, ladder: .standard, wallet: &wallet, using: random))
        XCTAssertEqual(wallet.balance, 4_000)
    }
}
