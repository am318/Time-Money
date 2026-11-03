import XCTest
@testable import TimeMoney

final class QuickAnswerTests: XCTestCase {

    func testUberAgainstTheBusMatchesTheReadme() {
        let text = QuickAnswer.answer(fasterName: "Uber", fasterPrice: 18, fasterMinutes: 20,
                                      cheaperName: "the bus", cheaperPrice: 2.5, cheaperMinutes: 55,
                                      profile: Fixture.profile)
        XCTAssertTrue(text.lowercased().contains("bus"), text)
        XCTAssertTrue(text.contains("£6.86"), "states the user's rate: \(text)")
        XCTAssertTrue(text.contains("£27"), "states the tipping point: \(text)")
    }

    func testAMissingSavedFileFallsBackToDefaults() {
        XCTAssertEqual(Store.PersistedState.load(from: nil), .empty)
    }
}
