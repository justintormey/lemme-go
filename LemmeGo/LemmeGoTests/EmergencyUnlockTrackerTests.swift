import XCTest
@testable import LemmeGo

final class EmergencyUnlockTrackerTests: XCTestCase {

    private let unlockKey = "emergencyUnlocks"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: unlockKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: unlockKey)
        super.tearDown()
    }

    // MARK: - Limit Enforcement

    func testInitialStateHasFiveRemainingUnlocks() {
        let tracker = EmergencyUnlockTracker()
        XCTAssertEqual(tracker.remainingUnlocks, 5)
        XCTAssertTrue(tracker.canUseEmergencyUnlock)
    }

    func testRecordUnlockDecrementsRemaining() {
        let tracker = EmergencyUnlockTracker()
        let sessionId = UUID()

        let success = tracker.recordEmergencyUnlock(sessionId: sessionId, reason: "test")
        XCTAssertTrue(success)
        XCTAssertEqual(tracker.remainingUnlocks, 4)
    }

    func testCannotExceedWeeklyLimit() {
        let tracker = EmergencyUnlockTracker()

        // Use all 5 unlocks
        for i in 0..<5 {
            let success = tracker.recordEmergencyUnlock(sessionId: UUID(), reason: "unlock \(i)")
            XCTAssertTrue(success, "Unlock \(i) should succeed")
        }

        XCTAssertEqual(tracker.remainingUnlocks, 0)
        XCTAssertFalse(tracker.canUseEmergencyUnlock)

        // 6th attempt should fail
        let denied = tracker.recordEmergencyUnlock(sessionId: UUID(), reason: "too many")
        XCTAssertFalse(denied)
    }

    func testRecordWithNilReason() {
        let tracker = EmergencyUnlockTracker()
        let success = tracker.recordEmergencyUnlock(sessionId: UUID(), reason: nil)
        XCTAssertTrue(success)
        XCTAssertEqual(tracker.remainingUnlocks, 4)
    }

    // MARK: - Persistence

    func testUnlocksPersistAcrossInstances() {
        let tracker1 = EmergencyUnlockTracker()
        _ = tracker1.recordEmergencyUnlock(sessionId: UUID(), reason: "persist test")

        let tracker2 = EmergencyUnlockTracker()
        XCTAssertEqual(tracker2.remainingUnlocks, 4)
    }
}

// MARK: - Calendar.startOfWeek Tests

final class CalendarStartOfWeekTests: XCTestCase {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    func testStartOfWeekIsMonday() {
        // Wednesday 2026-04-08 12:00 UTC
        let components = DateComponents(year: 2026, month: 4, day: 8, hour: 12)
        let wednesday = calendar.date(from: components)!

        let weekStart = calendar.startOfWeek(for: wednesday)
        let weekday = calendar.component(.weekday, from: weekStart)

        // weekday 2 = Monday in Gregorian calendar
        XCTAssertEqual(weekday, 2, "Start of week should be Monday")
    }

    func testStartOfWeekFromMondayReturnsSameMonday() {
        // Monday 2026-04-06 09:30 UTC
        let components = DateComponents(year: 2026, month: 4, day: 6, hour: 9, minute: 30)
        let monday = calendar.date(from: components)!

        let weekStart = calendar.startOfWeek(for: monday)
        let startDay = calendar.component(.day, from: weekStart)

        XCTAssertEqual(startDay, 6, "Monday should return the same Monday as start of week")
    }

    func testStartOfWeekFromSundayReturnsPreviousMonday() {
        // Sunday 2026-04-12 15:00 UTC
        let components = DateComponents(year: 2026, month: 4, day: 12, hour: 15)
        let sunday = calendar.date(from: components)!

        let weekStart = calendar.startOfWeek(for: sunday)
        let startDay = calendar.component(.day, from: weekStart)

        // The Monday before April 12 (Sunday) is April 6
        XCTAssertEqual(startDay, 6, "Sunday should return the previous Monday")
    }

    func testStartOfWeekIsMidnight() {
        let components = DateComponents(year: 2026, month: 4, day: 10, hour: 18, minute: 45)
        let friday = calendar.date(from: components)!

        let weekStart = calendar.startOfWeek(for: friday)
        let hour = calendar.component(.hour, from: weekStart)
        let minute = calendar.component(.minute, from: weekStart)

        XCTAssertEqual(hour, 0, "Week start should be at midnight")
        XCTAssertEqual(minute, 0, "Week start should be at midnight")
    }

    // MARK: - Regression: locale-independent Monday anchoring
    //
    // The original implementation derived the week from .yearForWeekOfYear/.weekOfYear,
    // which anchors on the calendar's firstWeekday. In an en_US calendar that is Sunday,
    // so a Sunday resolved to the FOLLOWING Monday and the 5-per-week emergency-unlock
    // budget refilled a day early. These pin the behaviour for every weekday and for a
    // calendar that explicitly starts its weeks on Sunday.

    /// Every day of the week 2026-04-06 (Mon) through 2026-04-12 (Sun) belongs to the
    /// week that starts Monday 2026-04-06.
    func testEveryDayOfWeekResolvesToTheSameMonday() {
        for day in 6...12 {
            let date = calendar.date(from: DateComponents(year: 2026, month: 4, day: day, hour: 13))!
            let weekStart = calendar.startOfWeek(for: date)

            XCTAssertEqual(
                calendar.component(.day, from: weekStart), 6,
                "2026-04-\(day) should anchor to Monday the 6th"
            )
            XCTAssertEqual(
                calendar.component(.weekday, from: weekStart), 2,
                "week start should always be a Monday (weekday 2)"
            )
        }
    }

    /// The Monday anchor must not move when the calendar's own firstWeekday is Sunday.
    func testStartOfWeekIgnoresCalendarFirstWeekday() {
        var sundayFirst = Calendar(identifier: .gregorian)
        sundayFirst.timeZone = TimeZone(identifier: "UTC")!
        sundayFirst.firstWeekday = 1  // Sunday, the en_US default

        // Sunday 2026-04-12 belongs to the week that began Monday 2026-04-06.
        let sunday = sundayFirst.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 15))!
        let weekStart = sundayFirst.startOfWeek(for: sunday)

        XCTAssertEqual(sundayFirst.component(.day, from: weekStart), 6)
        XCTAssertEqual(sundayFirst.component(.month, from: weekStart), 4)
    }

    /// Crossing a month boundary backwards must still land on the right Monday.
    func testStartOfWeekCrossesMonthBoundary() {
        // Wednesday 2026-04-01. The Monday of that week is Monday 2026-03-30.
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1, hour: 9))!
        let weekStart = calendar.startOfWeek(for: wednesday)

        XCTAssertEqual(calendar.component(.month, from: weekStart), 3)
        XCTAssertEqual(calendar.component(.day, from: weekStart), 30)
    }

    /// Two consecutive Sundays must resolve to different weeks. Under the old bug both a
    /// Sunday and the Monday after it mapped to the same Monday, which is what handed the
    /// user a second budget.
    func testSundayAndFollowingMondayAreDifferentWeeks() {
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 23))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 4, day: 13, hour: 1))!

        XCTAssertNotEqual(
            calendar.startOfWeek(for: sunday),
            calendar.startOfWeek(for: monday),
            "Sunday and the next day must fall in different budget weeks"
        )
    }
}
