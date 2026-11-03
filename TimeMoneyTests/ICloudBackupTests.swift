import XCTest
@testable import TimeMoney

final class ICloudBackupTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ICloudBackupTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    private func source(_ name: String, contents: String = "{}") throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func testCopiesIntoTheFolderAndCreatesIt() throws {
        let folder = root.appendingPathComponent("cloud/Backups")
        let file = try source("TimeMoney-2026-03-01.json", contents: "one")
        XCTAssertTrue(ICloudBackup.mirror(file, to: folder, keep: 8))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent(file.lastPathComponent), encoding: .utf8), "one")
    }

    func testReplacesASameNamedCopy() throws {
        let folder = root.appendingPathComponent("cloud")
        let file = try source("TimeMoney-2026-03-01.json", contents: "new")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: folder.appendingPathComponent(file.lastPathComponent))
        XCTAssertTrue(ICloudBackup.mirror(file, to: folder, keep: 8))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent(file.lastPathComponent), encoding: .utf8), "new")
    }

    func testKeepsOnlyTheNewestAndLeavesOtherFilesAlone() throws {
        let folder = root.appendingPathComponent("cloud")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let other = folder.appendingPathComponent("notes.txt")
        try Data("mine".utf8).write(to: other)
        for day in 1...4 {
            let f = try source("TimeMoney-2026-03-0\(day).json")
            XCTAssertTrue(ICloudBackup.mirror(f, to: folder, keep: 99))
            let copy = folder.appendingPathComponent(f.lastPathComponent)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400)],
                ofItemAtPath: copy.path)
        }
        ICloudBackup.prune(folder, keep: 2)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names, ["TimeMoney-2026-03-03.json", "TimeMoney-2026-03-04.json", "notes.txt"])
    }

    func testAMissingSourceFailsWithoutThrowing() {
        XCTAssertFalse(ICloudBackup.mirror(root.appendingPathComponent("nope.json"),
                                           to: root.appendingPathComponent("cloud"), keep: 8))
    }

    func testIsOffInThisBuild() {
        XCTAssertFalse(ICloudBackup.isAvailable, "the default build is not signed for iCloud")
    }
}
