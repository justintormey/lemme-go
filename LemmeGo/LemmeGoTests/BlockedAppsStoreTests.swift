import XCTest
import FamilyControls
@testable import LemmeGo

// MARK: - BlockedAppsStore Tests
//
// FamilyActivitySelection uses opaque NSKeyedArchiver tokens that require real
// Screen Time authorisation to populate. These tests therefore use only empty
// selections, which still exercise hasBlockedApps, plist round-trips, and the
// corrupted-data recovery paths — the parts we can actually control in CI.

final class BlockedAppsStoreTests: XCTestCase {

    private let plistKey = "blockedAppsSelection_plist"
    private let legacyKey = "blockedAppsSelection"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: plistKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: plistKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialSelectionIsEmpty() {
        let store = BlockedAppsStore()
        XCTAssertTrue(store.selection.applicationTokens.isEmpty)
        XCTAssertTrue(store.selection.categoryTokens.isEmpty)
        XCTAssertTrue(store.selection.webDomainTokens.isEmpty)
    }

    func testHasBlockedAppsIsFalseForEmptySelection() {
        let store = BlockedAppsStore()
        XCTAssertFalse(store.hasBlockedApps)
    }

    // MARK: - Persistence

    func testSaveSelectionWritesToUserDefaults() {
        let store = BlockedAppsStore()
        store.saveSelection()

        let data = UserDefaults.standard.data(forKey: plistKey)
        XCTAssertNotNil(data, "saveSelection() should write plist data to UserDefaults")
    }

    func testSaveAndLoadRoundTripPreservesEmptySelection() {
        let store1 = BlockedAppsStore()
        store1.saveSelection()

        let store2 = BlockedAppsStore()
        XCTAssertFalse(store2.hasBlockedApps,
                       "Loaded empty selection should still report no blocked apps")
    }

    func testLoadHandlesCorruptedPlistGracefully() {
        // Write non-plist bytes under the plist key
        let garbage = "not-a-valid-plist".data(using: .utf8)!
        UserDefaults.standard.set(garbage, forKey: plistKey)

        // Should not crash — bad plist data is silently recovered
        let store = BlockedAppsStore()
        XCTAssertFalse(store.hasBlockedApps)
    }

    func testCorruptedLegacyJsonKeyIsRemovedOnLoad() {
        // Write garbage under the legacy JSON key to simulate an old corrupted record
        let garbage = "{bad json".data(using: .utf8)!
        UserDefaults.standard.set(garbage, forKey: legacyKey)

        _ = BlockedAppsStore()

        XCTAssertNil(UserDefaults.standard.data(forKey: legacyKey),
                     "Corrupted legacy JSON data should be removed from UserDefaults after load")
    }

    // MARK: - Reload

    func testReloadSelectionDoesNotCrashWithNoPersistedData() {
        let store = BlockedAppsStore()
        // reloadSelection() with nothing stored should silently succeed
        store.reloadSelection()
        XCTAssertFalse(store.hasBlockedApps)
    }

    func testReloadSelectionDoesNotCrashWithPersistedData() {
        let store = BlockedAppsStore()
        store.saveSelection()
        store.reloadSelection()
        XCTAssertFalse(store.hasBlockedApps)
    }
}
