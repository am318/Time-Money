import XCTest
@testable import TimeMoney

final class LivingWageTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testRatesAreStoredAsWholePence() {
        let latest = LivingWage.london.last!
        XCTAssertEqual(latest.pence, 1_480)
        XCTAssertEqual(latest.hourly, 14.80)
        XCTAssertEqual(latest.label, "2025/26")
    }

    func testAnnualFigureUsesTheFoundationsThirtySevenAndAHalfHourWeek() {
        XCTAssertEqual(LivingWage.hoursPerYear, 1_950)
        XCTAssertEqual(LivingWage.london.last!.annualGross, 14.80 * 1_950, accuracy: 1e-6)
    }

    func testADateBetweenAnnouncementsGetsTheOlderRate() {
        let before = LivingWage.london(on: date(2025, 10, 1), calendar: calendar)
        let after = LivingWage.london(on: date(2025, 10, 22), calendar: calendar)
        XCTAssertEqual(before.announcedIn, 2024, "the line had not moved yet")
        XCTAssertEqual(after.announcedIn, 2025)
    }

    func testDatesBeforeTheSeriesFallBackToTheFirstRowAndSayTheyDo() {
        let early = date(2010, 1, 1)
        XCTAssertFalse(LivingWage.covers(early, calendar: calendar))
        XCTAssertEqual(LivingWage.london(on: early, calendar: calendar).announcedIn, 2018)
        XCTAssertTrue(LivingWage.covers(date(2020, 1, 1), calendar: calendar))
    }

    func testChangeBetweenRates() {
        let rates = LivingWage.london
        let r2024 = rates.first { $0.announcedIn == 2024 }!
        let r2025 = rates.first { $0.announcedIn == 2025 }!
        XCTAssertEqual(LivingWage.change(from: r2024, to: r2025), 95.0 / 1_385, accuracy: 1e-9)   // 6.9%
    }

    func testAnnualisedChangeDependsOnWhereYouStartCounting() {
        let rates = LivingWage.london
        let r2018 = rates.first { $0.announcedIn == 2018 }!
        let r2021 = rates.first { $0.announcedIn == 2021 }!
        let r2025 = rates.first { $0.announcedIn == 2025 }!
        XCTAssertEqual(LivingWage.annualisedChange(from: r2018, to: r2025), 0.050, accuracy: 0.001)
        XCTAssertEqual(LivingWage.annualisedChange(from: r2021, to: r2025), 0.076, accuracy: 0.001)
        XCTAssertEqual(LivingWage.annualisedChange(from: r2025, to: r2025), 0)
    }

    func testEmployersHaveUntilTheFirstOfMay() {
        let r2025 = LivingWage.london.last!
        XCTAssertEqual(r2025.inForceBy(calendar: calendar), date(2026, 5, 1))
    }

    func testNextAnnouncementIsOnlyDueOnceTheTableHasCaughtUp() {
        XCTAssertEqual(LivingWage.nextAnnouncementDue(after: date(2026, 1, 1), calendar: calendar), date(2026, 11, 1))
        XCTAssertNil(LivingWage.nextAnnouncementDue(after: date(2026, 12, 1), calendar: calendar),
                     "past the due date the table is simply stale, not 'due'")
    }

    func testLondonSeriesIsStrictlyIncreasing() {
        let pence = LivingWage.london.map(\.pence)
        XCTAssertEqual(pence, pence.sorted())
        XCTAssertEqual(Set(pence).count, pence.count)
    }
}
