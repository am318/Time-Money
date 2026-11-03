import XCTest
@testable import TimeMoney

final class ReviewRemindersTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ d: Int, _ h: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: h))!
    }

    private func decision(created: Date, saved: Bool = true, reviewed: Bool = false, title: String = "Uber") -> Decision {
        var d = Fixture.uberVsBus()
        d.createdAt = created
        d.isSaved = saved
        d.title = title
        if reviewed { d.review = ReviewOutcome.allCases.first }
        return d
    }

    func testAsksADayLater() {
        XCTAssertEqual(ReviewReminders.fireDate(for: at(1, 12), calendar: calendar), at(2, 12))
    }

    func testNeverAtNight() {
        XCTAssertEqual(ReviewReminders.fireDate(for: at(1, 3), calendar: calendar), at(2, 9), "3am becomes 9am")
        XCTAssertEqual(ReviewReminders.fireDate(for: at(1, 22), calendar: calendar), at(3, 9), "10pm tomorrow waits to the next morning")
    }

    func testOffMeansNothing() {
        XCTAssertTrue(ReviewReminders.plan(decisions: [decision(created: at(1, 12))],
                                           enabled: false, now: at(1, 13), calendar: calendar).isEmpty)
    }

    func testOnlySavedUnreviewedFutureDecisionsGetOne() {
        let ds = [
            decision(created: at(1, 12), title: "keep"),
            decision(created: at(1, 12), saved: false, title: "unsaved"),
            decision(created: at(1, 12), reviewed: true, title: "reviewed"),
            decision(created: at(1, 9), title: "earlier")
        ]
        let plan = ReviewReminders.plan(decisions: ds, enabled: true, now: at(1, 13), calendar: calendar)
        XCTAssertEqual(plan.map(\.title), ["earlier", "keep"], "soonest first; unsaved and reviewed are skipped")
    }

    func testPastDueAndAncientDecisionsAreLeftToTheInAppQueue() {
        let ds = [decision(created: at(1, 12), title: "past"),
                  decision(created: calendar.date(byAdding: .day, value: -30, to: at(1, 12))!, title: "ancient")]
        XCTAssertTrue(ReviewReminders.plan(decisions: ds, enabled: true, now: at(5, 12), calendar: calendar).isEmpty)
    }

    func testCappedAndSoonestFirst() {
        let ds = (0..<30).map { decision(created: at(1, 12).addingTimeInterval(Double($0) * 60), title: "d\($0)") }
        let plan = ReviewReminders.plan(decisions: ds, enabled: true, now: at(1, 12), calendar: calendar)
        XCTAssertEqual(plan.count, ReviewReminders.maxPending)
        XCTAssertEqual(plan, plan.sorted { $0.fireDate < $1.fireDate })
    }
}
