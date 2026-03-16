import XCTest
@testable import GameCore

@MainActor
final class GameStoreTests: XCTestCase {

    private var suiteName: String!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        // Isolate each test with its own UserDefaults suite so tests don't bleed state
        suiteName = "GameStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        store = GameStore(defaults: defaults)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func test_tick_increasesStock() {
        let before = store.stall.stock
        store.tick(deltaTime: 1.0)
        XCTAssertGreaterThan(store.stall.stock, before)
    }

    func test_collectCoins_movesToBalance() {
        store.stall.pendingCoins = 100
        store.collectCoins()
        XCTAssertEqual(store.stall.coins, 100, accuracy: 0.001)
        XCTAssertEqual(store.stall.pendingCoins, 0, accuracy: 0.001)
        XCTAssertEqual(store.progress.totalEarned, 100, accuracy: 0.001)
    }

    func test_applyOfflineEarnings_updatesCoins() {
        // Set lastActiveDate to 1 hour ago so OfflineProgressSystem produces earnings
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.applyOfflineEarnings()
        XCTAssertGreaterThan(store.offlineEarnings, 0)
    }

    func test_purchaseUpgrade_staff_deductsCoins() {
        store.stall.coins = 1000
        store.purchaseUpgrade(.staff)
        let staffCost = UpgradeDefinitions.staff[0].coinCost
        XCTAssertEqual(store.stall.coins, 1000 - staffCost, accuracy: 0.001)
        XCTAssertEqual(store.stall.staffTier, 1)
    }

    func test_purchaseUpgrade_insufficientCoins_doesNothing() {
        store.stall.coins = 10
        store.purchaseUpgrade(.staff)
        XCTAssertEqual(store.stall.coins, 10, accuracy: 0.001)
        XCTAssertEqual(store.stall.staffTier, 0)
    }
}
