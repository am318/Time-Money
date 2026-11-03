import XCTest
@testable import TimeMoney

@MainActor
final class AppLockTests: XCTestCase {

    func testStartsLockedAndLocksAgain() {
        let lock = AppLock()
        XCTAssertFalse(lock.isUnlocked)
        lock.lock()
        XCTAssertFalse(lock.isUnlocked)
    }

    func testABiometryNameIsAlwaysAvailableForTheSettingsRow() {
        XCTAssertFalse(AppLock.biometryName.isEmpty)
    }
}
