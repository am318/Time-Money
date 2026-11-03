import XCTest
@testable import TimeMoney

final class RateWhatIfTests: XCTestCase {

    private func whatIf() -> (RateWhatIf, Evaluation) {
        let decision = Fixture.uberVsBus()
        let evaluation = DecisionEngine.evaluate(decision, profile: Fixture.profile)
        return (RateWhatIf(decision: decision, profile: Fixture.profile, evaluation: evaluation), evaluation)
    }

    func testBaseRateReproducesTheShownVerdict() {
        let (w, e) = whatIf()
        XCTAssertEqual(w.outcome(atRate: w.baseRate).winner, e.winner)
        XCTAssertFalse(w.flips(atRate: w.baseRate))
    }

    func testCrossingTheTippingPointFlipsTheAnswer() throws {
        let (w, e) = whatIf()
        let tip = try XCTUnwrap(e.breakEvenRate)
        XCTAssertEqual(w.outcome(atRate: 0).winner, .b, "the bus wins when time is worth nothing")
        XCTAssertEqual(w.outcome(atRate: tip * 1.5).winner, .a, "the Uber wins well above the tipping point")
        XCTAssertTrue(w.flips(atRate: tip * 1.5))
    }

    func testRangeSpansBothSidesOfTheTippingPoint() throws {
        let (w, e) = whatIf()
        let tip = try XCTUnwrap(e.breakEvenRate)
        XCTAssertEqual(w.range.lowerBound, 0)
        XCTAssertGreaterThan(w.range.upperBound, max(tip, w.baseRate))
    }

    func testNegativeRatesAreClampedToZero() {
        let (w, _) = whatIf()
        XCTAssertEqual(w.outcome(atRate: -5), w.outcome(atRate: 0))
    }
}
