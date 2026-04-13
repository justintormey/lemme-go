import XCTest
@testable import LemmeGo

final class NFCChipTests: XCTestCase {

    // MARK: - NFCChip Model

    func testChipInitialization() {
        let chip = NFCChip(id: "AABB0011", name: "Work Tag")
        XCTAssertEqual(chip.id, "AABB0011")
        XCTAssertEqual(chip.name, "Work Tag")
        XCTAssertNotNil(chip.registeredAt)
    }

    func testChipCodableRoundTrip() throws {
        let chip = NFCChip(id: "CCDD0022", name: "Study Tag")
        let data = try JSONEncoder().encode(chip)
        let decoded = try JSONDecoder().decode(NFCChip.self, from: data)

        XCTAssertEqual(decoded.id, chip.id)
        XCTAssertEqual(decoded.name, chip.name)
    }

    func testChipHashability() {
        let chip1 = NFCChip(id: "AAA", name: "Tag 1")
        let chip2 = NFCChip(id: "BBB", name: "Tag 2")
        let chip3 = NFCChip(id: "AAA", name: "Tag 1 Renamed")

        var set: Set<NFCChip> = [chip1, chip2]
        XCTAssertEqual(set.count, 2)

        // chip3 shares the same id as chip1 but has a different name and
        // registeredAt timestamp. The synthesized Hashable conformance uses
        // all stored properties, so chip3 is a distinct element — set grows to 3.
        set.insert(chip3)
        XCTAssertEqual(set.count, 3)
    }
}

// MARK: - NFCChipStore Tests

final class NFCChipStoreTests: XCTestCase {

    private let testSuiteKey = "registeredNFCChips"

    override func setUp() {
        super.setUp()
        // Clear UserDefaults for clean test state
        UserDefaults.standard.removeObject(forKey: testSuiteKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testSuiteKey)
        super.tearDown()
    }

    func testRegisterChip() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "Test Tag")

        XCTAssertEqual(store.registeredChips.count, 1)
        XCTAssertEqual(store.registeredChips.first?.id, "CHIP001")
        XCTAssertEqual(store.registeredChips.first?.name, "Test Tag")
    }

    func testIsChipRegistered() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "Tag")

        XCTAssertTrue(store.isChipRegistered(id: "CHIP001"))
        XCTAssertFalse(store.isChipRegistered(id: "UNKNOWN"))
    }

    func testGetChip() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "My Tag")

        let chip = store.getChip(id: "CHIP001")
        XCTAssertNotNil(chip)
        XCTAssertEqual(chip?.name, "My Tag")

        XCTAssertNil(store.getChip(id: "MISSING"))
    }

    func testDeleteChip() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "Tag 1")
        store.registerChip(id: "CHIP002", name: "Tag 2")

        store.deleteChip(id: "CHIP001")

        XCTAssertEqual(store.registeredChips.count, 1)
        XCTAssertFalse(store.isChipRegistered(id: "CHIP001"))
        XCTAssertTrue(store.isChipRegistered(id: "CHIP002"))
    }

    func testUpdateChipName() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "Old Name")

        store.updateChipName(id: "CHIP001", newName: "New Name")

        XCTAssertEqual(store.getChip(id: "CHIP001")?.name, "New Name")
    }

    func testUpdateNonexistentChipIsNoOp() {
        let store = NFCChipStore()
        store.registerChip(id: "CHIP001", name: "Tag")

        // Should not crash or modify anything
        store.updateChipName(id: "MISSING", newName: "Nope")
        XCTAssertEqual(store.registeredChips.count, 1)
    }

    func testPersistenceAcrossInstances() {
        let store1 = NFCChipStore()
        store1.registerChip(id: "PERSIST001", name: "Persistent Tag")

        // New instance should load from UserDefaults
        let store2 = NFCChipStore()
        XCTAssertTrue(store2.isChipRegistered(id: "PERSIST001"))
        XCTAssertEqual(store2.getChip(id: "PERSIST001")?.name, "Persistent Tag")
    }
}
