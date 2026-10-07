import XCTest
@testable import TimeMoney

/// The decoders have to stay lenient: a profile or decision saved by an older version
/// must still open, whatever fields have been added since.
final class DecoderLeniencyTests: XCTestCase {

    func testAnEmptyProfileObjectDecodesToTheDefaults() throws {
        let profile = try JSONDecoder().decode(Profile.self, from: Data("{}".utf8))
        XCTAssertEqual(profile, Profile())
    }

    func testAProfileWithOnlyOldFieldsKeepsThemAndDefaultsTheRest() throws {
        let json = #"{"netMonthlyIncome": 3100, "monthlyRent": 1200}"#
        let profile = try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.netMonthlyIncome, 3_100)
        XCTAssertEqual(profile.monthlyRent, 1_200)
        XCTAssertEqual(profile.monthlyBills, Profile().monthlyBills)
    }

    func testADecisionRoundTrips() throws {
        let d = Fixture.uberVsBus()
        let data = try JSONEncoder().encode(d)
        XCTAssertEqual(try JSONDecoder().decode(Decision.self, from: data), d)
    }

    func testADecisionMissingEveryOptionalFieldStillDecodes() throws {
        let data = Data(#"{"title": "Old decision"}"#.utf8)
        let d = try JSONDecoder().decode(Decision.self, from: data)
        XCTAssertEqual(d.title, "Old decision")
        XCTAssertEqual(d.optionA, DecisionOption().with(id: d.optionA.id))
    }
}

private extension DecisionOption {
    func with(id: UUID) -> DecisionOption { var copy = self; copy.id = id; return copy }
}
