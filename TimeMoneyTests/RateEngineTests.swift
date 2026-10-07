import XCTest
@testable import TimeMoney

final class RateEngineTests: XCTestCase {

    private func breakdown(_ profile: Profile = Fixture.profile, committed: Double = 0) -> RateBreakdown {
        RateEngine.breakdown(for: profile, recentlyCommitted: committed)
    }

    func testDefaultProfileWorkedExample() {
        // 52/12 weeks a month × (37.5 paid + 5 commute) = 184.17 hours of work.
        let b = breakdown()
        XCTAssertEqual(b.effectiveEarnedRate, 2_400 / (42.5 * 52 / 12), accuracy: 1e-9)   // £13.03
        XCTAssertEqual(b.earnedRate, 2_400 / (37.5 * 52 / 12), accuracy: 1e-9)             // £14.77
        // 168 - 56 sleep - 37.5 work - 5 commute - 14 admin
        XCTAssertEqual(b.freeHoursWeekly, 55.5, accuracy: 1e-9)
        XCTAssertEqual(b.discretionaryMonthly, 850, accuracy: 1e-9)
        XCTAssertEqual(b.leisureRate, 850 / (55.5 * 52 / 12), accuracy: 1e-9)              // £3.53
        XCTAssertEqual(b.personalHourlyRate, 6.858, accuracy: 0.001)
    }

    func testBlendIsThirtyFiveSixtyFive() {
        let b = breakdown()
        XCTAssertEqual(RateEngine.earnedRateWeight, 0.35)
        XCTAssertEqual(b.leisureBlend, 0.35 * b.effectiveEarnedRate + 0.65 * b.leisureRate, accuracy: 1e-9)
    }

    func testScarcityMultipliesTheBaseRate() {
        let neutral = breakdown().personalHourlyRate
        var timePoor = Fixture.profile; timePoor.stance = .moreMoneyThanTime
        var timeRich = Fixture.profile; timeRich.stance = .moreTimeThanMoney
        XCTAssertEqual(breakdown(timePoor).personalHourlyRate, neutral * 1.4, accuracy: 1e-9)
        XCTAssertEqual(breakdown(timeRich).personalHourlyRate, neutral * 0.7, accuracy: 1e-9)
    }

    func testBusyWeekLiftsTheRateAndExpiresAfterSevenDays() {
        let neutral = breakdown().personalHourlyRate
        var busy = Fixture.profile
        busy.loadLevel = .busier
        busy.loadSetAt = Date()
        XCTAssertEqual(breakdown(busy).personalHourlyRate, neutral * 1.25, accuracy: 1e-9)

        busy.loadSetAt = Date().addingTimeInterval(-8 * 86_400)
        XCTAssertEqual(breakdown(busy).personalHourlyRate, neutral, accuracy: 1e-9,
                       "a pressure setting must lapse by itself")
    }

    func testDeadlinePressureLowersTheRateButNeverBelowSixtyPercent() {
        let neutral = breakdown().personalHourlyRate
        var profile = Fixture.profile
        var commitment = Commitment()
        commitment.name = "Deposit"
        commitment.amount = 5_000
        commitment.dueDate = Date().addingTimeInterval(60 * 86_400)
        profile.commitments = [commitment]

        let b = breakdown(profile)
        XCTAssertGreaterThan(b.goalPressure, 0)
        XCTAssertLessThan(b.personalHourlyRate, neutral)
        XCTAssertGreaterThanOrEqual(b.pressureMultiplier, 0.6)
        XCTAssertEqual(b.pressureMultiplier, 1 - 0.4 * b.goalPressure, accuracy: 1e-9)
    }

    func testRecentlyCommittedMoneyTightensTheNextDecision() {
        // The README's example: £700 committed takes £6.86 to £4.97.
        XCTAssertEqual(breakdown(committed: 700).personalHourlyRate, 4.966, accuracy: 0.001)
    }

    func testOverspendingPushesTheLeisureRateToZeroNotNegative() {
        var profile = Fixture.profile
        profile.monthlyRent = 3_000          // more than the take-home
        let b = breakdown(profile)
        XCTAssertLessThan(b.discretionaryMonthly, 0)
        XCTAssertEqual(b.leisureRate, 0)
        XCTAssertGreaterThanOrEqual(b.personalHourlyRate, 1, "the £1 guard stops a zero rate dividing into everything")
    }

    func testHourlyBillersLeanOnTheirBillingRate() {
        var freelance = Fixture.profile
        freelance.earningFlexibility = .flexible
        freelance.marginalHourlyRate = 35
        let b = breakdown(freelance)
        XCTAssertEqual(b.baseRate, 0.7 * 35 + 0.3 * b.leisureBlend, accuracy: 1e-9)
        XCTAssertGreaterThan(b.personalHourlyRate, breakdown().personalHourlyRate)
    }

    func testGrossSalaryGoesThroughTheTaxEstimate() {
        var profile = Fixture.profile
        profile.incomeMode = .grossAnnual
        profile.grossAnnualSalary = 38_000
        let expected = UKTax.takeHome(for: profile).netMonthly
        XCTAssertEqual(breakdown(profile).netMonthlyIncome, expected, accuracy: 1e-9)
    }

    func testOverrideReplacesTheDerivedRate() {
        var profile = Fixture.profile
        profile.rateOverride = 40
        let b = breakdown(profile)
        XCTAssertTrue(b.isOverridden)
        XCTAssertEqual(b.personalHourlyRate, 40)
    }

    func testWorkHoursForMoneyUsesTheEffectiveRate() {
        let b = breakdown()
        XCTAssertEqual(b.workHours(for: b.effectiveEarnedRate * 3), 3, accuracy: 1e-9)
    }
}
