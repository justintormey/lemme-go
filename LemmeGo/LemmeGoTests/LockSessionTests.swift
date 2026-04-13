import XCTest
@testable import LemmeGo

final class LockSessionTests: XCTestCase {

    // MARK: - Timed Session Tests

    func testTimedSessionEndTime() {
        let session = LockSession(chipId: "abc123", duration: 300)
        // endTime should be ~startTime + 300s
        let expected = session.startTime.addingTimeInterval(300)
        XCTAssertEqual(session.endTime, expected)
    }

    func testTimedSessionIsActiveWhenNotExpired() {
        // Session with 1-hour duration should be active immediately
        let session = LockSession(chipId: "abc123", duration: 3600)
        XCTAssertTrue(session.isActive)
    }

    func testTimedSessionRemainingTimeIsPositive() {
        let session = LockSession(chipId: "abc123", duration: 3600)
        XCTAssertGreaterThan(session.remainingTime, 0)
        XCTAssertLessThanOrEqual(session.remainingTime, 3600)
    }

    func testTimedSessionRemainingTimeNeverNegative() {
        // Zero-duration session should have 0 remaining time (not negative)
        let session = LockSession(chipId: "abc123", duration: 0)
        XCTAssertEqual(session.remainingTime, 0)
    }

    // MARK: - Unlimited Session Tests

    func testUnlimitedSessionEndTimeIsDistantFuture() {
        let session = LockSession(chipId: "abc123", duration: 0, isUnlimited: true)
        XCTAssertEqual(session.endTime, Date.distantFuture)
    }

    func testUnlimitedSessionIsAlwaysActive() {
        let session = LockSession(chipId: "abc123", duration: 0, isUnlimited: true)
        XCTAssertTrue(session.isActive)
    }

    func testUnlimitedSessionRemainingTimeIsInfinity() {
        let session = LockSession(chipId: "abc123", duration: 0, isUnlimited: true)
        XCTAssertEqual(session.remainingTime, .infinity)
    }

    // MARK: - Remote Activation

    func testRemoteActivatedSession() {
        let session = LockSession(chipId: "abc123", duration: 600, isRemoteActivated: true)
        XCTAssertTrue(session.isRemoteActivated)
        XCTAssertFalse(session.isUnlimited)
    }

    func testDefaultSessionIsNotRemoteActivated() {
        let session = LockSession(chipId: "abc123", duration: 600)
        XCTAssertFalse(session.isRemoteActivated)
        XCTAssertFalse(session.isUnlimited)
    }

    // MARK: - Codable

    func testSessionRoundTripEncoding() throws {
        let session = LockSession(chipId: "abc123", duration: 600, isRemoteActivated: true, isUnlimited: false)
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(LockSession.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.chipId, session.chipId)
        XCTAssertEqual(decoded.duration, session.duration)
        XCTAssertEqual(decoded.isRemoteActivated, session.isRemoteActivated)
        XCTAssertEqual(decoded.isUnlimited, session.isUnlimited)
    }

    func testSessionDecodesLegacyFormatWithoutOptionalFields() throws {
        // Simulate a legacy session JSON that lacks isRemoteActivated and isUnlimited
        let legacyJSON = """
        {
            "id": "12345678-1234-1234-1234-123456789012",
            "chipId": "legacyChip",
            "startTime": 0,
            "duration": 300
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LockSession.self, from: legacyJSON)
        XCTAssertEqual(decoded.chipId, "legacyChip")
        XCTAssertFalse(decoded.isRemoteActivated, "Legacy sessions should default to non-remote")
        XCTAssertFalse(decoded.isUnlimited, "Legacy sessions should default to non-unlimited")
    }
}
