import XCTest
@testable import TimeMoney

final class AutoBackupTests: XCTestCase {

    private var folder: URL!
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoBackupTests-\(UUID().uuidString)", isDirectory: true)
        AutoBackup.folderOverride = folder
    }

    override func tearDown() {
        AutoBackup.folderOverride = nil
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func backup(rent: Double = 900) -> TimeMoneyBackup {
        var p = Profile()
        p.monthlyRent = rent
        return TimeMoneyBackup(profile: p, decisions: [])
    }

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d, hour: 12))!
    }

    /// Stamps a file's modification date, since snapshots sort by it and a test that
    /// writes five files in a millisecond would otherwise tie.
    private func age(_ url: URL, to date: Date) {
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func testWritesASnapshot() {
        guard case .wrote(let url) = AutoBackup.write(backup(), now: day(1)) else {
            return XCTFail("expected a write")
        }
        XCTAssertTrue(url.lastPathComponent.hasPrefix(AutoBackup.prefix))
        XCTAssertEqual(AutoBackup.existing().count, 1)
        XCTAssertEqual(AutoBackup.snapshots().first?.decisions, 0)
    }

    func testAnIdenticalStateDoesNotSpendASlot() {
        _ = AutoBackup.write(backup(), now: day(1))
        XCTAssertEqual(AutoBackup.write(backup(), now: day(2)), .unchanged)
        XCTAssertEqual(AutoBackup.existing().count, 1)
    }

    func testAChangedStateWritesASecondSnapshotEvenOnTheSameDay() {
        _ = AutoBackup.write(backup(rent: 900), now: day(1))
        guard case .wrote(let url) = AutoBackup.write(backup(rent: 950), now: day(1)) else {
            return XCTFail("expected a write")
        }
        XCTAssertTrue(url.lastPathComponent.hasSuffix("-2.json"), "must not overwrite the morning's")
        XCTAssertEqual(AutoBackup.existing().count, 2)
    }

    func testOffAndNotDue() {
        XCTAssertEqual(AutoBackup.runIfDue(backup(), everyDays: 0), .off)
        guard case .wrote(let url) = AutoBackup.runIfDue(backup(), everyDays: 7, now: day(1), calendar: calendar) else {
            return XCTFail("the first run is always due")
        }
        age(url, to: day(1))
        XCTAssertEqual(AutoBackup.runIfDue(backup(rent: 1), everyDays: 7, now: day(3), calendar: calendar), .notDue)
        if case .wrote = AutoBackup.runIfDue(backup(rent: 1), everyDays: 7, now: day(9), calendar: calendar) {} else {
            XCTFail("a week on, it is due")
        }
    }

    func testPruneKeepsTheNewest() {
        var urls: [URL] = []
        for i in 1...5 {
            if case .wrote(let url) = AutoBackup.write(backup(rent: Double(i)), keep: 99, now: day(i)) {
                age(url, to: day(i))
                urls.append(url)
            }
        }
        XCTAssertEqual(urls.count, 5)
        AutoBackup.prune(keep: 2)
        let left = AutoBackup.existing()
        XCTAssertEqual(left.count, 2)
        XCTAssertEqual(left.first, urls[4], "newest first")
        XCTAssertEqual(left.last, urls[3])
    }

    func testUnreadableFilesAreSkippedInTheSnapshotList() throws {
        _ = AutoBackup.write(backup(), now: day(1))
        try Data("garbage".utf8).write(to: folder.appendingPathComponent("\(AutoBackup.prefix)broken.json"))
        XCTAssertEqual(AutoBackup.existing().count, 2)
        XCTAssertEqual(AutoBackup.snapshots().count, 1)
    }

    func testDayDifferenceCountsDatesNotHours() {
        let late = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 23))!
        let early = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 1))!
        XCTAssertEqual(AutoBackup.dayDifference(from: late, to: early, calendar: calendar), 1)
    }
}
