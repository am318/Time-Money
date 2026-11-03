import XCTest
@testable import TimeMoney

final class RateHistoryTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func day(_ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h))!
    }

    func testFirstReadingIsRecorded() {
        let log = RateHistory.recording(6.86, into: [], now: day(1), calendar: calendar)
        XCTAssertEqual(log, [RatePoint(date: day(1), rate: 6.86)])
    }

    func testNoiseAndNonsenseAreIgnored() {
        let log = [RatePoint(date: day(1), rate: 6.86)]
        XCTAssertNil(RateHistory.recording(6.861, into: log, now: day(2), calendar: calendar))
        XCTAssertNil(RateHistory.recording(0, into: log, now: day(2), calendar: calendar))
        XCTAssertNil(RateHistory.recording(.nan, into: log, now: day(2), calendar: calendar))
    }

    func testSeveralEditsInADayAreOneReading() {
        let log = [RatePoint(date: day(1, 9), rate: 6.86)]
        let updated = RateHistory.recording(8, into: log, now: day(1, 18), calendar: calendar)
        XCTAssertEqual(updated, [RatePoint(date: day(1, 18), rate: 8)])
    }

    func testANewDayAppends() {
        let log = [RatePoint(date: day(1), rate: 6.86)]
        XCTAssertEqual(RateHistory.recording(8, into: log, now: day(2), calendar: calendar)?.count, 2)
    }

    func testCappedAtMaxPoints() {
        let log = (0..<RateHistory.maxPoints).map { RatePoint(date: day(1).addingTimeInterval(Double($0) * 86_400), rate: Double($0) + 1) }
        let updated = RateHistory.recording(9_999, into: log, now: day(1).addingTimeInterval(1_000 * 86_400), calendar: calendar)
        XCTAssertEqual(updated?.count, RateHistory.maxPoints)
        XCTAssertEqual(updated?.last?.rate, 9_999)
        XCTAssertEqual(updated?.first?.rate, 2)
    }

    func testChangeOverAWindow() throws {
        let log = [RatePoint(date: day(1), rate: 10), RatePoint(date: day(10), rate: 12)]
        XCTAssertEqual(try XCTUnwrap(RateHistory.change(in: log, since: day(1))), 0.2, accuracy: 1e-9)
        XCTAssertNil(RateHistory.change(in: log, since: day(5)), "one reading in the window is not a trend")
    }

    func testMonthlyTotalsAgreeWithLifetimeSaved() {
        var a = Fixture.uberVsBus(); a.isSaved = true
        a.createdAt = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        var b = Fixture.uberVsBus(uber: 25); b.isSaved = true
        b.createdAt = calendar.date(from: DateComponents(year: 2026, month: 2, day: 9))!
        var unsaved = Fixture.uberVsBus()
        unsaved.createdAt = b.createdAt
        let months = Trends.monthly(decisions: [b, a, unsaved], profile: Fixture.profile,
                                    rate: Fixture.rate, calendar: calendar)
        XCTAssertEqual(months.map(\.decisions), [1, 1])
        XCTAssertLessThan(months[0].month, months[1].month)
        // Uber vs bus at £6.86/hr: the bus wins, avoiding the £15.50 difference and the time it costs.
        XCTAssertEqual(months[0].moneyAvoided, 15.5, accuracy: 0.001)
    }
}
