import XCTest
@testable import TimeMoney

final class FormatTests: XCTestCase {

    func testMoneyShowsPenceOnlyForSmallNonRoundSums() {
        XCTAssertEqual(Fmt.money(2.5), "£2.50")
        XCTAssertEqual(Fmt.money(120), "£120")
        XCTAssertEqual(Fmt.money(99.5), "£99.50")
        XCTAssertEqual(Fmt.money(1_234.56), "£1,235")
        XCTAssertEqual(Fmt.money(1_234.5), "£1,235", "halves round up, not to even")
        XCTAssertEqual(Fmt.money(100.5), "£101")
        XCTAssertEqual(Fmt.money(0), "£0")
    }

    func testNegativeMoneyKeepsItsSign() {
        XCTAssertEqual(Fmt.money(-3.2), "-£3.20")
    }

    func testPenceCanBeForcedOnOrOff() {
        XCTAssertEqual(Fmt.money(1_234.56, decimals: true), "£1,234.56")
        XCTAssertEqual(Fmt.moneyRounded(2.5.nextUp), "£3")
    }

    func testRates() {
        XCTAssertEqual(Fmt.rate(6.858), "£6.86/hr")
        XCTAssertEqual(Fmt.rate(150), "£150/hr")
    }

    func testDurations() {
        XCTAssertEqual(Fmt.duration(hours: 0), "no time")
        XCTAssertEqual(Fmt.duration(hours: 0.25), "15 min")
        XCTAssertEqual(Fmt.duration(hours: 1), "1 hour")
        XCTAssertEqual(Fmt.duration(hours: 1.5), "1h 30m")
        XCTAssertEqual(Fmt.duration(hours: 2), "2 hours")
        XCTAssertEqual(Fmt.duration(hours: 12), "12 hours")
        XCTAssertEqual(Fmt.duration(hours: 72), "3.0 days")
        XCTAssertEqual(Fmt.minutes(55), "55 min")
    }

    func testDurationRoundsSixtyMinutesUpRatherThanSayingSixty() {
        // 2h 59.7m must read "3 hours", never "2h 60m".
        XCTAssertEqual(Fmt.duration(hours: 2 + 59.7 / 60), "3 hours")
    }

    func testDaysAndMonths() {
        XCTAssertEqual(Fmt.days(0.5), "0.5 days")
        XCTAssertEqual(Fmt.days(1.2), "1 day")
        XCTAssertEqual(Fmt.days(20), "3 weeks")
        XCTAssertEqual(Fmt.months(1), "1 month")
        XCTAssertEqual(Fmt.months(6), "6 months")
        XCTAssertEqual(Fmt.months(24), "2 years")
        XCTAssertEqual(Fmt.months(18), "1.5 years")
    }

    func testPluralisation() {
        XCTAssertEqual(Fmt.plural(1, "month"), "1 month")
        XCTAssertEqual(Fmt.plural(3, "month"), "3 months")
        XCTAssertEqual(Fmt.plural(2, "person", "people"), "2 people")
    }

    func testSentenceStartOnlyTouchesTheFirstLetter() {
        XCTAssertEqual(Fmt.sentenceStart("the bus"), "The bus")
        XCTAssertEqual(Fmt.sentenceStart("iPhone"), "IPhone")
        XCTAssertEqual(Fmt.sentenceStart(""), "")
    }

    func testTheHeadlineNamesTheWinnerAndTheMargin() {
        let d = Fixture.uberVsBus()
        let e = DecisionEngine.evaluate(d, profile: Fixture.profile)
        XCTAssertTrue(VerdictText.headline(for: e, decision: d).hasPrefix("The bus"))
    }
}
