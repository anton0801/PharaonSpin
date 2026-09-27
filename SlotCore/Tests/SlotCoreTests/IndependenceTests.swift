import XCTest
import SlotCore

final class IndependenceTests: XCTestCase {
    /// Buckets of total win as a multiple of the bet.
    private func bucket(win: Int, bet: Int) -> Int {
        let x = Double(win) / Double(bet)
        switch x {
        case 0: return 0
        case ..<0.5: return 1
        case ..<1: return 2
        case ..<2: return 3
        case ..<5: return 4
        case ..<20: return 5
        default: return 6
        }
    }

    private func slotHistogram(balance: Int, seed: UInt64, spins: Int) throws -> [Int] {
        let random = SeededRandomSource(seed: seed)
        var histogram = [Int](repeating: 0, count: 7)
        var game = SlotGame()
        let bet = 1_000
        for _ in 0..<spins {
            // Hold the balance fixed before every paid spin so it is the only thing that differs.
            var wallet = Wallet(balance: balance)
            var roundWin = try game.play(machine: .standard, bet: bet, ladder: .standard, wallet: &wallet, using: random).outcome.totalWin
            while game.isInFreeSpins {
                roundWin += try game.play(machine: .standard, bet: bet, ladder: .standard, wallet: &wallet, using: random).outcome.totalWin
            }
            histogram[bucket(win: roundWin, bet: bet)] += 1
        }
        return histogram
    }

    func testSlotPayoutDistributionDoesNotDependOnBalance() throws {
        let low = try slotHistogram(balance: 1_000, seed: 101, spins: 1_000_000)
        let high = try slotHistogram(balance: 100_000_000, seed: 202, spins: 1_000_000)
        let (statistic, degrees) = Statistics.chiSquareHomogeneity(low, high)
        let p = Statistics.chiSquarePValue(statistic, degrees: degrees)
        print("[SlotCore] slot balance 1,000 vs 100,000,000: χ²=\(String(format: "%.3f", statistic)) df=\(degrees) p=\(String(format: "%.4f", p))")
        print("[SlotCore]   low  \(low)")
        print("[SlotCore]   high \(high)")
        XCTAssertGreaterThan(p, 0.05)
    }

    func testWheelPayoutDistributionDoesNotDependOnBalance() throws {
        func histogram(balance: Int, seed: UInt64) throws -> [Int] {
            let random = SeededRandomSource(seed: seed)
            var counts = [Int](repeating: 0, count: 12)
            var game = WheelGame()
            for _ in 0..<1_000_000 {
                var wallet = Wallet(balance: balance)
                counts[try game.play(wheel: .standard, bet: 1_000, ladder: .standard, wallet: &wallet, using: random).sector] += 1
            }
            return counts
        }
        let low = try histogram(balance: 1_000, seed: 303)
        let high = try histogram(balance: 100_000_000, seed: 404)
        let (statistic, degrees) = Statistics.chiSquareHomogeneity(low, high)
        let p = Statistics.chiSquarePValue(statistic, degrees: degrees)
        print("[SlotCore] wheel balance 1,000 vs 100,000,000: χ²=\(String(format: "%.3f", statistic)) df=\(degrees) p=\(String(format: "%.4f", p))")
        XCTAssertGreaterThan(p, 0.05)
    }

    /// With identical random bits, the outcome is identical whatever the balance or how many
    /// spins came before — the stronger, deterministic form of the property above.
    func testSameRandomBitsGiveSameOutcomeRegardlessOfBalanceAndHistory() throws {
        var lowGame = SlotGame()
        var highGame = SlotGame()
        let a = SeededRandomSource(seed: 55)
        let b = SeededRandomSource(seed: 55)
        for _ in 0..<50_000 {
            var lowWallet = Wallet(balance: 1_000)
            var highWallet = Wallet(balance: 100_000_000)
            let low = try lowGame.play(machine: .standard, bet: 1_000, ladder: .standard, wallet: &lowWallet, using: a)
            let high = try highGame.play(machine: .standard, bet: 1_000, ladder: .standard, wallet: &highWallet, using: b)
            XCTAssertEqual(low.outcome.stops, high.outcome.stops)
            XCTAssertEqual(low.outcome.totalWin, high.outcome.totalWin)
        }

        let fixedStops = [(7, 40), (13, 40), (21, 40), (3, 40), (38, 40)]
        let fresh = SlotMachine.standard.spin(totalBet: 1_000, isFreeSpin: false, using: ScriptedRandomSource(fixedStops))
        let warm = SeededRandomSource(seed: 1)
        for _ in 0..<10_000 { _ = SlotMachine.standard.spin(totalBet: 1_000, isFreeSpin: false, using: warm) }
        let later = SlotMachine.standard.spin(totalBet: 1_000, isFreeSpin: false, using: ScriptedRandomSource(fixedStops))
        XCTAssertEqual(fresh, later, "spin count must not change the outcome")
    }

    /// Outcome code must not be able to see the clock: it may not import Foundation or name
    /// any time source, and the machine types carry no counters or balances.
    func testOutcomeSourcesDoNotReadClockBalanceOrSpinCount() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SlotCore")
        let outcomeFiles = ["RandomSource.swift", "SlotSymbol.swift", "SlotConfiguration.swift", "SlotMachine.swift", "FortuneWheel.swift"]
        let forbidden = ["import Foundation", "import Dispatch", "Date", "clock", "ProcessInfo", "CFAbsoluteTime",
                         "DispatchTime", "mach_absolute_time", "uptime", "balance", "spinCount", "spinsPlayed", "lossStreak"]
        for file in outcomeFiles {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            let code = text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            for token in forbidden {
                XCTAssertFalse(code.contains(token), "\(file) mentions \(token)")
            }
        }
    }
}
