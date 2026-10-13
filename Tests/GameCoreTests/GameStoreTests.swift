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
        store.stall.coins = 0   // default save starts with 50 coins; isolate the transfer
        store.stall.pendingCoins = 100
        store.collectCoins()
        XCTAssertEqual(store.stall.coins, 100, accuracy: 0.001)
        XCTAssertEqual(store.stall.pendingCoins, 0, accuracy: 0.001)
        XCTAssertEqual(store.progress.totalEarned, 100, accuracy: 0.001)
    }

    func test_applyOfflineEarnings_updatesCoins() {
        // Offline earnings come from the recorded rolling earningRate, which is 0 on a fresh save
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = 10
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.calculateOfflineEarnings()
        // 10 coins/s x 3600 s x offlineEfficiency
        XCTAssertEqual(store.offlineEarnings, 10 * 3600 * GameStore.offlineEfficiency, accuracy: 1)
    }

    func test_offlineEarnings_cappedAtMaxOfflineHours() {
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = 10
        store.progress.lastActiveDate = Date().addingTimeInterval(-20 * 3600)
        store.calculateOfflineEarnings()
        let cap = 10 * GameStore.maxOfflineHours * 3600 * GameStore.offlineEfficiency
        XCTAssertEqual(store.offlineEarnings, cap, accuracy: 1)
    }

    func test_purchaseUpgrade_menu_deductsCoins() {
        store.stall.coins = 5000
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.coins, 5000 - UpgradeDefinitions.menu[1].coinCost, accuracy: 0.001)
        XCTAssertEqual(store.stall.menuTier, 1)
    }

    func test_purchaseUpgrade_insufficientCoins_doesNothing() {
        store.stall.coins = 10
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.coins, 10, accuracy: 0.001)
        XCTAssertEqual(store.stall.menuTier, 0)
    }

    // MARK: - Hiring gate

    func test_hireWorker_lockedTier_isRefusedByTheStore() {
        store.stall.coins = 1_000_000
        store.stall.stallTier = 0
        let before = store.stall

        store.hireWorker(tier: 2)   // 이모님 needs 봄동 식당
        store.hireWorker(tier: 3)   // 봄동 요리사 needs 봄동 전문점
        XCTAssertEqual(store.stall.coins, before.coins, accuracy: 0.001)
        XCTAssertEqual(store.stall.tier2Count, before.tier2Count)
        XCTAssertEqual(store.stall.tier3Count, before.tier3Count)
        XCTAssertEqual(store.stall.staffTier, before.staffTier)

        store.stall.stallTier = 1
        store.hireWorker(tier: 3)
        XCTAssertEqual(store.stall.tier3Count, 0, "tier 3 stays locked at stall tier 1")
    }

    func test_hireWorker_unlockedTier_hires() {
        store.stall.coins = 10_000
        store.stall.stallTier = 1
        store.hireWorker(tier: 2)
        XCTAssertEqual(store.stall.tier2Count, 1)
        XCTAssertEqual(store.stall.staffTier, 2)
        XCTAssertEqual(store.stall.coins, 10_000 - UpgradeDefinitions.staff[1].coinCost, accuracy: 0.001)
    }

    func test_hireWorker_firstTier_isNeverGated() {
        store.stall.coins = 1_000
        XCTAssertEqual(store.stall.stallTier, 0)
        let before = store.stall.tier1Count
        store.hireWorker(tier: 1)
        XCTAssertEqual(store.stall.tier1Count, before + 1)
        XCTAssertEqual(store.stall.coins, 1_000 - UpgradeDefinitions.staff[0].coinCost, accuracy: 0.001)
    }

    func test_hireWorker_outOfRangeTier_isRefused() {
        store.stall.coins = 1_000_000
        store.hireWorker(tier: 0)
        store.hireWorker(tier: 4)
        XCTAssertEqual(store.stall.coins, 1_000_000, accuracy: 0.001)
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

    func test_startManualCook_menuIndex2_thenTick_landsOnePortionInMenuStock2() {
        store.farm.plots[0].workerType = .none   // isolate from farm auto-harvest — see first test
        store.stall.menuTier = 2                  // unlocks the daejeop bowl (menu index 2)
        let stockBefore = store.stall.menuStock[2]
        let warehouseBefore = store.stall.warehouse

        XCTAssertTrue(store.startManualCook(menuIndex: 2))
        XCTAssertTrue(store.isCooking(menuIndex: 2))

        store.tick(deltaTime: 10.0)
        XCTAssertEqual(store.stall.menuStock[2], stockBefore + 1)
        XCTAssertEqual(store.stall.warehouse, warehouseBefore - 1)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 2))
    }

    func test_startManualCook_menuIndex2_tierLocked_refuses() {
        store.stall.menuTier = 1   // daejeop bowl not yet unlocked
        XCTAssertFalse(store.startManualCook(menuIndex: 2))
        XCTAssertFalse(store.isCooking(menuIndex: 2))
    }

    // MARK: - Tier-0 economy

    func test_tick_noCashier_autoCollectsPendingCoins() {
        XCTAssertEqual(store.stall.cashierCount, 0)
        store.farm.plots[0].workerType = .none
        store.stall.coins = 0
        store.stall.menuStock[0] = 1
        let price = store.sellItem(menuIndex: 0)
        XCTAssertNotNil(price)
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(store.stall.coins, price ?? -1, accuracy: 0.001)
        XCTAssertEqual(store.stall.pendingCoins, 0, accuracy: 0.001)
    }

    func test_tick_replant_neverGoesBelowZeroCoins() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = false
        store.stall.coins = FarmSystem.seedCost - 1
        store.tick(deltaTime: 1.0)
        XCTAssertEqual(store.stall.coins, FarmSystem.seedCost - 1, accuracy: 0.001)
        XCTAssertFalse(store.farm.plots[0].isPlanted)

        store.stall.coins = 0
        for _ in 0..<100 { store.tick(deltaTime: 1.0) }
        XCTAssertGreaterThanOrEqual(store.stall.coins, 0)
    }

    func test_idle90s_withCustomersBuying_coinsStayAtOrAboveStart() {
        let start = store.stall.coins
        for second in 0..<90 {
            // One customer every 10 s buys a bowl if one is in stock; the
            // player taps a cook right after, as in the play-test.
            if second % 10 == 0 {
                _ = store.sellItem(menuIndex: 0)
                _ = store.startManualCook(menuIndex: 0)
            }
            store.tick(deltaTime: 1.0)
        }
        XCTAssertGreaterThanOrEqual(store.stall.coins, start)
        XCTAssertEqual(store.stall.pendingCoins, 0, accuracy: 0.001)
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
