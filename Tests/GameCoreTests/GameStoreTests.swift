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
        store.farm.plots[0].workerType = .alba
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
        store.calculateOfflineEarnings()
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

    // MARK: - Manual (tap) cook

    func test_startManualCook_thenTick_landsOnePortionAfterTenSeconds() {
        // The default save's plot 0 auto-harvests on its own (see
        // `FarmState.init`) and would add back to the warehouse mid-test,
        // masking the manual cook's own -1 — unassign it so this test
        // isolates the manual-cook path.
        store.farm.plots[0].workerType = .none
        let stockBefore = store.stall.menuStock[0]
        let warehouseBefore = store.stall.warehouse

        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        store.tick(deltaTime: 5.0)
        // Halfway through the 10s cook — nothing has landed yet
        XCTAssertEqual(store.stall.menuStock[0], stockBefore)
        XCTAssertEqual(store.cookProgress(menuIndex: 0), 0.5, accuracy: 0.001)

        store.tick(deltaTime: 5.0)
        XCTAssertEqual(store.stall.menuStock[0], stockBefore + 1)
        XCTAssertEqual(store.stall.warehouse, warehouseBefore - 1)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    func test_startManualCook_calledTwice_onlyOnePortionLands() {
        store.farm.plots[0].workerType = .none   // isolate from farm auto-harvest — see previous test
        let stockBefore = store.stall.menuStock[0]

        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        // Already running — a second start (e.g. a repeat tap) is a no-op
        XCTAssertFalse(store.startManualCook(menuIndex: 0))

        store.tick(deltaTime: 10.0)
        XCTAssertEqual(store.stall.menuStock[0], stockBefore + 1)

        // No second cook was queued behind the first, so a further tick
        // produces nothing more
        store.tick(deltaTime: 10.0)
        XCTAssertEqual(store.stall.menuStock[0], stockBefore + 1)
    }

    func test_startManualCook_warehouseEmptiesBeforeCompletion_producesNothing() {
        store.farm.plots[0].workerType = .none   // isolate from farm auto-harvest — see first test
        store.stall.warehouse = 1
        let stockBefore = store.stall.menuStock[0]

        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        store.stall.warehouse = 0   // drained by something else mid-cook
        store.tick(deltaTime: 10.0)

        XCTAssertEqual(store.stall.menuStock[0], stockBefore)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    func test_startManualCook_menuIndex1_thenTick_landsOnePortionInMenuStock1() {
        store.farm.plots[0].workerType = .none   // isolate from farm auto-harvest — see first test
        store.stall.menuTier = 1                  // unlocks the large bowl (menu index 1)
        let stockBefore = store.stall.menuStock[1]
        let warehouseBefore = store.stall.warehouse

        XCTAssertTrue(store.startManualCook(menuIndex: 1))
        XCTAssertTrue(store.isCooking(menuIndex: 1))

        store.tick(deltaTime: 10.0)
        XCTAssertEqual(store.stall.menuStock[1], stockBefore + 1)
        XCTAssertEqual(store.stall.warehouse, warehouseBefore - 1)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 1))
    }

    func test_startManualCook_menuIndex1_tierLocked_refuses() {
        store.stall.menuTier = 0   // large bowl not yet unlocked
        XCTAssertFalse(store.startManualCook(menuIndex: 1))
        XCTAssertFalse(store.isCooking(menuIndex: 1))
    }

    // MARK: - isCooking

    func test_isCooking_noCookNoManual_isFalse() {
        XCTAssertFalse(store.isCooking(menuIndex: 0))
    }

    func test_isCooking_manualCookStarted_isTrue() {
        store.farm.plots[0].workerType = .none   // isolate from farm auto-harvest — see manual-cook tests above
        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        XCTAssertTrue(store.isCooking(menuIndex: 0))
    }

    func test_isCooking_cookHiredButWarehouseEmpty_isFalse() {
        store.stall.menuCooks[0] = 1
        store.stall.warehouse = 0
        XCTAssertFalse(store.isCooking(menuIndex: 0))
    }

    func test_isCooking_cookHiredWithWarehouseAndStockBelowMax_isTrue() {
        store.stall.menuCooks[0] = 1
        store.stall.warehouse = 5
        store.stall.menuStock[0] = 0
        XCTAssertTrue(store.isCooking(menuIndex: 0))
    }

    func test_isCooking_stockAtMax_isFalse() {
        store.stall.menuCooks[0] = 1
        store.stall.warehouse = 5
        store.stall.menuStock[0] = EarningsSystem.maxStock(for: store.stall)
        XCTAssertFalse(store.isCooking(menuIndex: 0))
    }
}
