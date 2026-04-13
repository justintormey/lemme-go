import XCTest
@testable import LemmeGo

final class FormatTimeTests: XCTestCase {

    private var lockManager: LockManager!

    override func setUp() {
        super.setUp()
        lockManager = LockManager()
    }

    override func tearDown() {
        lockManager = nil
        super.tearDown()
    }

    // MARK: - formatTime

    func testFormatTimeZeroSeconds() {
        XCTAssertEqual(lockManager.formatTime(0), "00:00")
    }

    func testFormatTimeSecondsOnly() {
        XCTAssertEqual(lockManager.formatTime(45), "00:45")
    }

    func testFormatTimeMinutesAndSeconds() {
        XCTAssertEqual(lockManager.formatTime(125), "02:05")
    }

    func testFormatTimeExactMinute() {
        XCTAssertEqual(lockManager.formatTime(60), "01:00")
    }

    func testFormatTimeWithHours() {
        // 1 hour, 30 minutes, 15 seconds = 5415
        XCTAssertEqual(lockManager.formatTime(5415), "01:30:15")
    }

    func testFormatTimeExactHour() {
        XCTAssertEqual(lockManager.formatTime(3600), "01:00:00")
    }

    func testFormatTimeLargeDuration() {
        // 23h 59m 59s = 86399
        XCTAssertEqual(lockManager.formatTime(86399), "23:59:59")
    }

    func testFormatTimeJustUnderOneHour() {
        // 59:59 (3599 seconds) — should be MM:SS format (no hours)
        XCTAssertEqual(lockManager.formatTime(3599), "59:59")
    }
}
