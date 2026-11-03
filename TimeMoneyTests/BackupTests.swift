import XCTest
@testable import TimeMoney

final class BackupTests: XCTestCase {

    private let stamp = Date(timeIntervalSince1970: 1_700_000_000)

    private func backup(decisions: Int = 2) -> TimeMoneyBackup {
        var list: [Decision] = []
        for i in 0..<decisions {
            var d = Fixture.uberVsBus(uber: 18 + Double(i))
            d.createdAt = stamp
            list.append(d)
        }
        var b = TimeMoneyBackup(profile: Profile(), decisions: list)
        b.exportedAt = stamp
        return b
    }

    func testRoundTrip() throws {
        let original = backup()
        XCTAssertEqual(try TimeMoneyBackup.decode(original.encoded()), original)
    }

    func testOutputIsDeterministicSoItCanBeDiffed() throws {
        XCTAssertEqual(try backup().encoded(), try backup().encoded())
    }

    func testANewerFormatIsRefused() throws {
        var newer = backup()
        newer.formatVersion = TimeMoneyBackup.currentVersion + 1
        let data = try newer.encoded()
        XCTAssertThrowsError(try TimeMoneyBackup.decode(data)) {
            XCTAssertEqual($0 as? BackupError, .tooNew)
        }
    }

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try TimeMoneyBackup.decode(Data("nope".utf8)))
    }

    func testSummaryCountsDecisionsAndReviews() {
        var b = backup(decisions: 3)
        XCTAssertEqual(b.summary.decisions, 3)
        XCTAssertEqual(b.summary.reviewed, 0)
        XCTAssertEqual(b.summary.rate, Fixture.rate, accuracy: 0.001)
        b.exportedAt = Date()
        XCTAssertEqual(b.summary.age, "today")
    }

    func testFilenameCarriesTheDate() {
        XCTAssertTrue(backup().suggestedFilename.hasPrefix("TimeMoney-2023-11-1"))
        XCTAssertTrue(backup().suggestedFilename.hasSuffix(".json"))
    }
}
