import XCTest
@testable import GameCore

@MainActor
final class ShopStatusSnapshotTests: XCTestCase {

    private var suiteName: String!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "ShopStatusSnapshotTests.\(UUID().uuidString)"
        store = GameStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        try await super.tearDown()
    }

    func test_freshStall_hasNoCrewAndOnlyFirstMenu() {
        let status = store.shopStatus
        XCTAssertFalse(status.cashierPresent)
        XCTAssertEqual(status.cashierEnergy, 0)
        XCTAssertFalse(status.cookPresent)
        XCTAssertEqual(status.cookEnergy, 0)
        XCTAssertEqual(status.stocks.map(\.menuIndex), [0])
    }

    func test_cashierPresent_reportsEnergy() {
        store.stall.cashierCount = 1
        store.stall.cashierEnergy = 0.4
        let status = store.shopStatus
        XCTAssertTrue(status.cashierPresent)
        XCTAssertEqual(status.cashierEnergy, 0.4, accuracy: 0.0001)
    }

    func test_warehouseAtCap() {
        store.stall.warehouse = store.stall.warehouseCapacity
        let status = store.shopStatus
        XCTAssertEqual(status.warehouseCount, status.warehouseCap)
    }

    func test_lockedMenusAreOmitted_andUnlockedKeepStock() {
        store.stall.menuStock = [3, 7, 9]
        XCTAssertEqual(store.shopStatus.stocks, [.init(menuIndex: 0, count: 3)])

        store.stall.menuTier = 1
        XCTAssertEqual(store.shopStatus.stocks, [.init(menuIndex: 0, count: 3), .init(menuIndex: 1, count: 7)])
        XCTAssertEqual(store.shopStatus.totalStock, 10)
    }

    func test_cookEnergy_isLowestAssigned() {
        store.stall.menuTier = 1
        store.stall.menuCooks = [1, 2, 0]
        store.stall.menuCookEnergy = [0.9, 0.3, 0.1]
        let status = store.shopStatus
        XCTAssertTrue(status.cookPresent)
        XCTAssertEqual(status.cookEnergy, 0.3, accuracy: 0.0001)
    }
}
