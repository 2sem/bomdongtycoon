import XCTest
@testable import GameCore

@MainActor
final class WarehouseExpansionTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "WarehouseExpansionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = GameStore(defaults: defaults)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        try await super.tearDown()
    }

    // MARK: Ladder

    func test_ladder_costsAndCaps() {
        var cap = WarehouseSystem.baseCapacity
        XCTAssertEqual(cap, 15)
        var seen: [(Int, Double)] = []
        while let next = WarehouseSystem.nextExpansion(current: cap) {
            seen.append((next.capacity, next.cost))
            cap = next.capacity
        }
        XCTAssertEqual(seen.map(\.0), [25, 35, 45, 55])
        XCTAssertEqual(seen.map(\.1), [300, 800, 2_000, 5_000])
        XCTAssertNil(WarehouseSystem.costForNextExpansion(current: 55))
    }

    func test_ladder_oldSaveShape_keepsItsPrices() {
        var cap = WarehouseSystem.legacyBaseCapacity
        var seen: [(Int, Double)] = []
        while let next = WarehouseSystem.nextExpansion(current: cap) {
            seen.append((next.capacity, next.cost))
            cap = next.capacity
        }
        XCTAssertEqual(seen.map(\.0), [20, 30, 40, 50])
        XCTAssertEqual(seen.map(\.1), [300, 800, 2_000, 5_000], "a save on 10/20/30/40 pays what it always paid")
        XCTAssertNil(WarehouseSystem.costForNextExpansion(current: 50))
    }

    func test_ladder_bothShapesPriceTheSameStep() {
        for (old, new) in [(10, 15), (20, 25), (30, 35), (40, 45)] {
            XCTAssertEqual(WarehouseSystem.costForNextExpansion(current: old),
                           WarehouseSystem.costForNextExpansion(current: new), "\(old) vs \(new)")
            XCTAssertNotNil(WarehouseSystem.costForNextExpansion(current: old))
        }
    }

    func test_oldSaveOnTen_expandsFromItsOwnShape() {
        store.stall.warehouseCapacity = 10
        store.stall.coins = 300
        store.expandWarehouse()
        XCTAssertEqual(store.stall.warehouseCapacity, 20)
        XCTAssertEqual(store.stall.coins, 0, accuracy: 0.001)
    }

    func test_newGameOpensOnFifteen() {
        XCTAssertEqual(StallState().warehouseCapacity, 15)
    }

    func test_expandWarehouse_spendsCoinsAndRaisesCap() {
        store.stall.coins = 1_000
        store.expandWarehouse()
        XCTAssertEqual(store.stall.warehouseCapacity, 25)
        XCTAssertEqual(store.stall.coins, 700, accuracy: 0.001)
        store.stall.coins = 800
        store.expandWarehouse()
        XCTAssertEqual(store.stall.warehouseCapacity, 35)
        XCTAssertEqual(store.stall.coins, 0, accuracy: 0.001)
    }

    func test_expandWarehouse_unaffordable_doesNothing() {
        store.stall.coins = 299
        store.expandWarehouse()
        XCTAssertEqual(store.stall.warehouseCapacity, 15)
        XCTAssertEqual(store.stall.coins, 299, accuracy: 0.001)
    }

    func test_purchaseUpgradeWarehouse_matchesExpand() {
        store.stall.coins = 300
        store.purchaseUpgrade(.warehouse)
        XCTAssertEqual(store.stall.warehouseCapacity, 25)
        XCTAssertEqual(store.stall.coins, 0, accuracy: 0.001)
    }

    func test_maxCap_isNotExceeded() {
        for max in [50, 55] {
            store.stall.warehouseCapacity = max
            store.stall.coins = 1_000_000
            store.expandWarehouse()
            store.purchaseUpgrade(.warehouse)
            XCTAssertEqual(store.stall.warehouseCapacity, max)
        }
        XCTAssertEqual(store.stall.coins, 1_000_000, accuracy: 0.001)
    }

    // MARK: Goal selection

    /// Menu/stall/staff maxed or locked would be noisy; instead zero coins and a
    /// cheapest competitor (알바생, 300) so the 300 warehouse wins only when offered.
    private func goalName(warehouse: Int, capacity: Int = 10) -> String? {
        var stall = StallState()
        stall.warehouse = warehouse
        stall.warehouseCapacity = capacity
        stall.menuCooks = [1, 0, 0]
        stall.recipeLevels = [RecipeSystem.maxLevel, RecipeSystem.maxLevel, RecipeSystem.maxLevel]
        return EarningsSystem.nextGoalUpgrade(for: stall)?.name
    }

    func test_goal_below80Percent_isNotWarehouse() {
        XCTAssertEqual(goalName(warehouse: 7), "알바생")   // 70%
        XCTAssertNotEqual(EarningsSystem.nextGoalType(for: stall(warehouse: 7)), .warehouse)
    }

    func test_goal_at80Percent_isWarehouse() {
        XCTAssertEqual(goalName(warehouse: 8), "창고 확장")  // 80% boundary, inclusive
        XCTAssertEqual(EarningsSystem.nextGoalType(for: stall(warehouse: 8)), .warehouse)
        XCTAssertEqual(EarningsSystem.nextGoalUpgrade(for: stall(warehouse: 8))?.coinCost, 300)
    }

    func test_goalLabel_namesTheWarehouseGoal() {
        XCTAssertEqual(EarningsSystem.nextGoalLabel(for: stall(warehouse: 8)), .warehouse)
        XCTAssertEqual(EarningsSystem.nextGoalLabel(for: stall(warehouse: 7)), .hire)
        var s = stall(warehouse: 7)
        s.staffTier = UpgradeDefinitions.staff.count
        XCTAssertEqual(EarningsSystem.nextGoalLabel(for: s), .upgrade)
    }

    func test_goal_boundaryScalesWithCapacity() {
        // 20 cap: 15/20 = 75% out, 16/20 = 80% in. Next cost is 800, which loses
        // cheapest-first to 알바생 (500), so strip the other goals to see it in isolation.
        func only(warehouse: Int) -> StallState {
            var s = stall(warehouse: warehouse, capacity: 20)
            s.staffTier = UpgradeDefinitions.staff.count
            s.menuTier = UpgradeDefinitions.menu.count - 1
            s.stallTier = UpgradeDefinitions.stall.count - 1
            s.locationTier = UpgradeDefinitions.location.count - 1
            s.recipeLevels = [RecipeSystem.maxLevel, RecipeSystem.maxLevel, RecipeSystem.maxLevel]
            return s
        }
        // With everything bought and no throttle, only the endless renovation is left.
        XCTAssertEqual(EarningsSystem.nextGoalType(for: only(warehouse: 15)), .renovation)
        XCTAssertEqual(EarningsSystem.nextGoalType(for: only(warehouse: 16)), .warehouse)
        XCTAssertEqual(EarningsSystem.nextGoalUpgrade(for: only(warehouse: 16))?.coinCost, 800)
    }

    func test_goal_fullWarehouse_withoutAMenuCook_isNotWarehouse() {
        // Before a cook is assigned the cook is the bottleneck, not the warehouse.
        var s = stall(warehouse: 10)
        s.menuCooks = [0, 0, 0]
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .staff)
        s.menuCooks = [0, 2, 0]
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .warehouse, "any menu's cook counts")
    }

    func test_goal_atMaxCap_neverWarehouse() {
        XCTAssertEqual(goalName(warehouse: 50, capacity: 50), "알바생")
    }

    private func stall(warehouse: Int, capacity: Int = 10) -> StallState {
        var s = StallState()
        s.menuCooks = [1, 0, 0]
        s.warehouse = warehouse
        s.warehouseCapacity = capacity
        s.recipeLevels = [RecipeSystem.maxLevel, RecipeSystem.maxLevel, RecipeSystem.maxLevel]
        return s
    }

    // MARK: Persistence

    func test_expandedCap_survivesReload() {
        store.stall.coins = 300
        store.expandWarehouse()
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.stall.warehouseCapacity, 25)
    }

    func test_oldSaveWithoutCapacity_defaultsToTheOldBase() throws {
        let json = #"{"coins": 5}"#
        let decoded = try JSONDecoder().decode(StallState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.warehouseCapacity, WarehouseSystem.legacyBaseCapacity)
    }
}
