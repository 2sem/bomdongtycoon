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

    func test_tick_growsFarmPlots() {
        // Tick no longer auto-produces stock; it advances farm plot growth instead
        let activePlots = FarmSystem.activePlotCount(for: store.farm)
        let before = store.farm.plots[0].growth
        store.tick(deltaTime: 1.0)
        // At least the first active plot should have grown
        XCTAssertGreaterThan(store.farm.plots[0].growth, before)
        XCTAssertGreaterThan(activePlots, 0)
    }

    func test_tick_workerAutoHarvestsReadyPlot() {
        // Seed a plot as ready and assign a worker — tick should harvest into warehouse
        store.farm.plots[0].growth = 1.0
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].hasWorker = true
        let warehouseBefore = store.stall.warehouse
        store.tick(deltaTime: 0.0)  // deltaTime irrelevant — worker harvests on every tick
        XCTAssertGreaterThan(store.stall.warehouse, warehouseBefore)
        XCTAssertEqual(store.farm.plots[0].growth, 0, accuracy: 0.001)
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
