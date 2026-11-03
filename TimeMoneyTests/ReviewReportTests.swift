import XCTest
@testable import TimeMoney

final class ReviewReportTests: XCTestCase {

    private func decision(recommended: Side?, chosen: Side?, review: ReviewOutcome?) -> Decision {
        var d = Fixture.uberVsBus()
        d.recommendedSide = recommended?.rawValue
        d.chosenSide = chosen?.rawValue
        d.review = review
        return d
    }

    func testUnreviewedDecisionsAreIgnored() {
        let r = ReviewReport.make(from: [decision(recommended: .a, chosen: .a, review: nil)])
        XCTAssertEqual(r.reviewed, 0)
        XCTAssertFalse(r.hasEnough)
        XCTAssertNil(r.summary)
    }

    func testFollowedAndOverrodeAreSeparated() {
        let ds = [
            decision(recommended: .a, chosen: .a, review: .rightCall),
            decision(recommended: .a, chosen: .a, review: .rightCall),
            decision(recommended: .a, chosen: .a, review: .wrongCall),
            decision(recommended: .b, chosen: .a, review: .wrongCall),
            decision(recommended: .b, chosen: .a, review: .cantTell),
            decision(recommended: nil, chosen: nil, review: .rightCall)
        ]
        let r = ReviewReport.make(from: ds)
        XCTAssertEqual(r.followed, ReviewReport.Tally(right: 2, wrong: 1, cantTell: 0))
        XCTAssertEqual(r.overrode, ReviewReport.Tally(right: 0, wrong: 1, cantTell: 1))
        XCTAssertEqual(r.unrecorded.right, 1)
        XCTAssertEqual(r.reviewed, 6)
        XCTAssertEqual(try XCTUnwrap(r.followed.rightShare), 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(r.overrode.rightShare, 0)
    }

    func testATooCloseRecommendationIsNotAnOverride() {
        let r = ReviewReport.make(from: [decision(recommended: .tooClose, chosen: .a, review: .rightCall)])
        XCTAssertEqual(r.overrode.total, 0)
        XCTAssertEqual(r.unrecorded.total, 1)
    }

    func testSummaryNeedsEnoughReviewsAndSaysTheNumbers() throws {
        var ds = (0..<4).map { _ in decision(recommended: .a, chosen: .a, review: .rightCall) }
        XCTAssertNil(ReviewReport.make(from: ds).summary, "four is not enough")
        ds.append(decision(recommended: .b, chosen: .a, review: .wrongCall))
        let summary = try XCTUnwrap(ReviewReport.make(from: ds).summary)
        XCTAssertTrue(summary.contains("100%"))
        XCTAssertTrue(summary.contains("0%"))
    }

    func testCantTellNeverCountsForOrAgainst() {
        let t = ReviewReport.Tally(right: 0, wrong: 0, cantTell: 3)
        XCTAssertNil(t.rightShare)
    }
}
