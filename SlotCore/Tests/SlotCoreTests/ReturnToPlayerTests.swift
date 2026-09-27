import XCTest
import SlotCore

final class SlotRTPTests: XCTestCase {
    func testExactSlotReturnIsInsideTargetRange() {
        let result = SlotMachine.standard.exactReturn()
        print(String(
            format: "[SlotCore] slot exact RTP %.4f%% (lines %.4f%%, scatter %.4f%%, free spins %.4f%%; trigger 1 in %.0f, %.2f spins per trigger)",
            result.total * 100, result.lineReturn * 100, result.scatterReturn * 100, result.freeSpinsReturn * 100,
            1 / result.freeSpinTriggerProbability, result.expectedFreeSpinsPerTrigger
        ))
        XCTAssertGreaterThanOrEqual(result.total, 0.93)
        XCTAssertLessThanOrEqual(result.total, 0.96)
    }

    /// 10,000,000 paid spins through the same `SlotGame` path the app uses, free spins included.
    func testSimulatedSlotRTPOverTenMillionSpins() throws {
        let machine = SlotMachine.standard
        let ladder = BetLadder.standard
        let random = SeededRandomSource(seed: 0x5EED_2026)
        let bet = 1_000
        let paidSpins = 10_000_000
        var game = SlotGame()
        var wallet = Wallet(balance: Int.max / 2)
        var wagered = 0
        var won = 0
        var sumSquares = 0.0
        var roundWin = 0
        var freeSpinsPlayed = 0

        var paid = 0
        while paid < paidSpins || game.isInFreeSpins {
            let round = try game.play(machine: machine, bet: bet, ladder: ladder, wallet: &wallet, using: random)
            if round.outcome.isFreeSpin {
                freeSpinsPlayed += 1
            } else {
                // Close the previous round (paid spin + its free spins) for the variance estimate.
                if paid > 0 { sumSquares += pow(Double(roundWin) / Double(bet), 2) }
                roundWin = 0
                paid += 1
                wagered += bet
            }
            roundWin += round.outcome.totalWin
            won += round.outcome.totalWin
        }
        sumSquares += pow(Double(roundWin) / Double(bet), 2)

        let rtp = Double(won) / Double(wagered)
        let mean = rtp
        let variance = sumSquares / Double(paidSpins) - mean * mean
        let standardError = (variance / Double(paidSpins)).squareRoot()
        let exact = machine.exactReturn().total
        print(String(
            format: "[SlotCore] slot simulated RTP over %d spins: %.4f%% (±%.4f%% at 1σ, σ per spin %.2f×bet); exact %.4f%%; free spins played %d",
            paidSpins, rtp * 100, standardError * 100, variance.squareRoot(), exact * 100, freeSpinsPlayed
        ))
        XCTAssertGreaterThanOrEqual(rtp, 0.93)
        XCTAssertLessThanOrEqual(rtp, 0.96)
        XCTAssertLessThan(abs(rtp - exact), 4 * standardError, "simulation disagrees with the exact return")
    }
}

final class WheelRTPTests: XCTestCase {
    func testExactWheelReturnIsInsideTargetRange() {
        let wheel = FortuneWheel.standard
        XCTAssertEqual(wheel.sectors.count, 12)
        XCTAssertEqual(wheel.sectors.map(\.id), Array(0..<12))
        let probabilities = wheel.sectors.indices.map(wheel.probability(ofSector:))
        XCTAssertEqual(probabilities.reduce(0, +), 1, accuracy: 1e-12)
        print(String(
            format: "[SlotCore] wheel exact RTP %.4f%% (multipliers %.4f%%, FS chance %.3f%%, total weight %d)",
            wheel.exactRTP * 100, wheel.returnWithoutFreeSpins * 100, wheel.freeSpinProbability * 100, wheel.totalWeight
        ))
        XCTAssertGreaterThanOrEqual(wheel.exactRTP, 0.92)
        XCTAssertLessThanOrEqual(wheel.exactRTP, 0.96)
    }

    func testSimulatedWheelAgreesWithExactReturn() throws {
        let wheel = FortuneWheel.standard
        let random = SeededRandomSource(seed: 42)
        var game = WheelGame()
        var wallet = Wallet(balance: Int.max / 2)
        let bet = 1_000
        let paidSpins = 2_000_000
        var paid = 0
        var won = 0
        var sumSquares = 0.0
        var roundWin = 0
        while paid < paidSpins || game.freeSpinsRemaining > 0 {
            let round = try game.play(wheel: wheel, bet: bet, ladder: .standard, wallet: &wallet, using: random)
            if round.kind == .paid {
                if paid > 0 { sumSquares += pow(Double(roundWin) / Double(bet), 2) }
                roundWin = 0
                paid += 1
            }
            roundWin += round.payout
            won += round.payout
        }
        sumSquares += pow(Double(roundWin) / Double(bet), 2)
        let rtp = Double(won) / Double(paidSpins * bet)
        let variance = sumSquares / Double(paidSpins) - rtp * rtp
        let standardError = (variance / Double(paidSpins)).squareRoot()
        print(String(format: "[SlotCore] wheel simulated RTP over %d spins: %.4f%% (±%.4f%%)", paidSpins, rtp * 100, standardError * 100))
        XCTAssertLessThan(abs(rtp - wheel.exactRTP), 4 * standardError)
    }

    func testPayoutsAreExactIntegers() {
        let wheel = FortuneWheel.standard
        for bet in BetLadder.standard.steps {
            for sector in wheel.sectors {
                if let multiplier = sector.prize.multiplier {
                    XCTAssertEqual(Double(wheel.payout(sector: sector.id, bet: bet)), Double(bet) * multiplier)
                }
            }
        }
        XCTAssertEqual(wheel.payout(sector: 8, bet: 380_000), 95_000)
    }

    func testBonusSpinIsFreeAndFreeSpinsKeepTheirStake() throws {
        let wheel = FortuneWheel.standard
        var game = WheelGame()
        var wallet = Wallet(balance: 0)
        // Sector 6 is FS: land on it with the bonus stake.
        let fsTicket = wheel.sectors.prefix(6).reduce(0) { $0 + $1.weight }
        let script = ScriptedRandomSource([(fsTicket, wheel.totalWeight)])
        let bonus = try game.play(wheel: wheel, bet: 1_000, ladder: .standard, bonusStake: 25_000, wallet: &wallet, using: script)
        XCTAssertEqual(bonus.kind, .bonus)
        XCTAssertEqual(bonus.sector, 6)
        XCTAssertEqual(bonus.freeSpinsAwarded, 5)
        XCTAssertEqual(wallet.balance, 0)
        let next = try game.play(wheel: wheel, bet: 1_000, ladder: .standard, wallet: &wallet, using: SeededRandomSource(seed: 3))
        XCTAssertEqual(next.kind, .freeSpin)
        XCTAssertEqual(next.stake, 25_000)
    }

    func testGeometryLandsOnTheChosenSector() {
        let geometry = WheelGeometry(sectorCount: 12, firstSectorCenter: -15)
        let random = SeededRandomSource(seed: 9)
        var rotation = 123.0
        for _ in 0..<2_000 {
            let sector = random.uniform(12)
            let turns = 5 + random.uniform(3)
            let offset = random.unitInterval() * 0.8 - 0.4
            let target = geometry.targetRotation(from: rotation, sector: sector, turns: turns, offset: offset)
            XCTAssertGreaterThanOrEqual(target - rotation, Double(turns) * 360)
            XCTAssertLessThan(target - rotation, Double(turns + 1) * 360)
            XCTAssertEqual(geometry.sector(atRotation: target), sector)
            rotation = target
        }
    }
}
