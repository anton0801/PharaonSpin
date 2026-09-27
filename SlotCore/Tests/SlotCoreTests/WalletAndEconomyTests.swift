import XCTest
import SlotCore

final class WalletTests: XCTestCase {
    func testWalletNeverGoesNegative() {
        var wallet = Wallet(balance: -50)
        XCTAssertEqual(wallet.balance, 0)
        XCTAssertThrowsError(try wallet.debit(1)) { XCTAssertEqual($0 as? WalletError, .insufficientFunds) }
        XCTAssertThrowsError(try wallet.debit(-5)) { XCTAssertEqual($0 as? WalletError, .invalidAmount) }
        XCTAssertThrowsError(try wallet.credit(-5)) { XCTAssertEqual($0 as? WalletError, .invalidAmount) }
        XCTAssertNoThrow(try wallet.credit(1_000))
        XCTAssertNoThrow(try wallet.debit(1_000))
        XCTAssertEqual(wallet.balance, 0)
    }

    func testCreditSaturatesInsteadOfOverflowing() throws {
        var wallet = Wallet(balance: Int.max - 1)
        try wallet.credit(10)
        XCTAssertEqual(wallet.balance, Int.max)
    }

    func testBetLadder() {
        let ladder = BetLadder.standard
        XCTAssertEqual(ladder.steps, [1_000, 5_000, 10_000, 50_000, 100_000, 380_000, 1_000_000])
        XCTAssertEqual(ladder.increased(from: 10_000, balance: 1_000_000), 50_000)
        XCTAssertNil(ladder.increased(from: 10_000, balance: 49_999), "+ is disabled when the next bet exceeds the balance")
        XCTAssertNil(ladder.increased(from: 1_000_000, balance: .max))
        XCTAssertEqual(ladder.decreased(from: 380_000), 100_000)
        XCTAssertNil(ladder.decreased(from: 1_000))
        XCTAssertEqual(ladder.clamped(380_000, balance: 60_000), 50_000)
        XCTAssertEqual(ladder.clamped(5_000, balance: 5_000), 5_000)
        XCTAssertEqual(ladder.clamped(5_000, balance: 10), 1_000)
        for step in ladder.steps {
            XCTAssertEqual(step % 20, 0, "every bet splits evenly across 20 lines")
            XCTAssertEqual(step % 4, 0, "every bet pays ×0.25 exactly")
        }
    }
}

final class EconomyTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func testDailyBonusAccumulatesUpToThreeDays() {
        let rules = EconomyRules.standard
        XCTAssertEqual(DailyBonus.claimableDays(lastClaim: nil, now: date(1, 9), calendar: calendar, maxDays: rules.dailyBonusMaxDays), 1)
        XCTAssertEqual(DailyBonus.claimableDays(lastClaim: date(1, 9), now: date(1, 23), calendar: calendar, maxDays: 3), 0)
        XCTAssertEqual(DailyBonus.claimableDays(lastClaim: date(1, 23), now: date(2, 1), calendar: calendar, maxDays: 3), 1)
        XCTAssertEqual(DailyBonus.claimableDays(lastClaim: date(1, 9), now: date(3, 9), calendar: calendar, maxDays: 3), 2)
        XCTAssertEqual(DailyBonus.claimableDays(lastClaim: date(1, 9), now: date(20, 9), calendar: calendar, maxDays: 3), 3)
        XCTAssertEqual(DailyBonus.nextAvailable(after: date(1, 15), calendar: calendar), date(2, 0))
    }

    func testRefillPaysTwentyThousandAfterTwentyMinutesBelowMinimumBet() {
        let rules = EconomyRules.standard
        var timer = RefillTimer()
        let start = date(5, 12)
        XCTAssertEqual(timer.update(balance: 500, minimumBet: 1_000, freeSpinsPending: false, now: start, rules: rules), 0)
        XCTAssertEqual(timer.startedAt, start)
        XCTAssertEqual(timer.update(balance: 500, minimumBet: 1_000, freeSpinsPending: false, now: start.addingTimeInterval(19 * 60), rules: rules), 0)
        XCTAssertEqual(timer.update(balance: 500, minimumBet: 1_000, freeSpinsPending: false, now: start.addingTimeInterval(20 * 60), rules: rules), 20_000)
        XCTAssertNil(timer.startedAt)
    }

    func testRefillCancelsWhenBalanceRecoversOrFreeSpinsPending() {
        let rules = EconomyRules.standard
        var timer = RefillTimer()
        _ = timer.update(balance: 0, minimumBet: 1_000, freeSpinsPending: false, now: date(5, 12), rules: rules)
        XCTAssertNotNil(timer.startedAt)
        _ = timer.update(balance: 25_000, minimumBet: 1_000, freeSpinsPending: false, now: date(5, 13), rules: rules)
        XCTAssertNil(timer.startedAt)
        _ = timer.update(balance: 0, minimumBet: 1_000, freeSpinsPending: true, now: date(5, 14), rules: rules)
        XCTAssertNil(timer.startedAt)
    }

    func testWheelBonusEveryFourHours() {
        let last = date(6, 8)
        XCTAssertTrue(WheelBonus.isAvailable(lastSpin: nil, now: last, interval: 4 * 3600))
        XCTAssertFalse(WheelBonus.isAvailable(lastSpin: last, now: date(6, 11), interval: 4 * 3600))
        XCTAssertTrue(WheelBonus.isAvailable(lastSpin: last, now: date(6, 12), interval: 4 * 3600))
        XCTAssertEqual(EconomyRules.standard.wheelBonusStake % 4, 0)
    }
}
