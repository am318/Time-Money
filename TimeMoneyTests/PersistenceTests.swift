import XCTest
@testable import TimeMoney

/// The on-disk state file: versioning, legacy files, and refusing newer ones.
final class PersistenceTests: XCTestCase {
    typealias State = Store.PersistedState

    private func fixedDecision() -> Decision {
        var d = Fixture.uberVsBus()
        d.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        return d
    }

    func testMissingOrEmptyDataIsAFirstLaunch() {
        XCTAssertEqual(State.load(from: nil), .empty)
        XCTAssertEqual(State.load(from: Data()), .empty)
    }

    func testGarbageIsUnreadable() {
        XCTAssertEqual(State.load(from: Data("not json".utf8)), .unreadable)
        XCTAssertEqual(State.load(from: Data("[1,2,3]".utf8)), .unreadable)
    }

    func testCurrentStateRoundTrips() throws {
        let state = State(profile: Profile(), decisions: [fixedDecision()])
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(State.load(from: data), .loaded(state))
    }

    func testNewFilesCarryTheCurrentSchemaVersion() throws {
        let data = try JSONEncoder().encode(State(profile: Profile(), decisions: []))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, State.currentSchemaVersion)
    }

    func testAFileFromBeforeVersioningStillOpens() throws {
        // What the app wrote before schemaVersion existed: no version key at all.
        let legacy = #"{"profile": {"netMonthlyIncome": 3100, "monthlyRent": 1200}, "decisions": [{"title": "Old decision"}]}"#
        guard case .loaded(let state) = State.load(from: Data(legacy.utf8)) else {
            return XCTFail("a legacy file should load")
        }
        XCTAssertEqual(state.schemaVersion, State.currentSchemaVersion)
        XCTAssertEqual(state.profile.netMonthlyIncome, 3_100)
        XCTAssertEqual(state.decisions.first?.title, "Old decision")
    }

    func testAFileFromANewerAppIsRefusedNotMisread() {
        let future = #"{"schemaVersion": 99, "profile": {}, "decisions": []}"#
        XCTAssertEqual(State.load(from: Data(future.utf8)), .tooNew(99))
    }

    func testOneHalfFailingDoesNotLoseTheOther() {
        let json = #"{"schemaVersion": 1, "profile": "broken", "decisions": [{"title": "Kept"}]}"#
        guard case .loaded(let state) = State.load(from: Data(json.utf8)) else {
            return XCTFail("should still load")
        }
        XCTAssertEqual(state.profile, Profile())
        XCTAssertEqual(state.decisions.first?.title, "Kept")
    }
}
