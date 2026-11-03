import XCTest
@testable import TimeMoney

final class WidgetSnapshotTests: XCTestCase {

    func testRoundTripsThroughTheSharedEncoding() throws {
        var s = TimeMoneyWidgetSnapshot()
        s.generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        s.hourlyRate = 6.86
        s.effectiveEarnedRate = 13.03
        s.discretionaryMonthly = 850
        s.freeHoursWeekly = 24
        s.stance = "Time-poor"
        s.usingPortfolioFigures = true
        s.awaitingReview = 2
        let data = try TimeMoneyWidgetSnapshot.encoder().encode(s)
        XCTAssertEqual(try TimeMoneyWidgetSnapshot.decoder().decode(TimeMoneyWidgetSnapshot.self, from: data), s)
    }

    func testAnOldSnapshotMissingNewerFieldsStillDraws() throws {
        let json = #"{"hourlyRate": 7.5}"#
        let s = try TimeMoneyWidgetSnapshot.decoder().decode(TimeMoneyWidgetSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(s.hourlyRate, 7.5)
        XCTAssertEqual(s.awaitingReview, 0)
        XCTAssertTrue(s.hasRate)
    }

    func testAnEmptySnapshotHasNoRate() throws {
        let s = try TimeMoneyWidgetSnapshot.decoder().decode(TimeMoneyWidgetSnapshot.self, from: Data("{}".utf8))
        XCTAssertFalse(s.hasRate)
    }
}
