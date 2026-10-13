import XCTest
@testable import GameCore

/// A prestige-0 player must see exactly the numbers main produced. `expected` was captured by
/// running this same driver on main (b989142) before the prestige change.
@MainActor
final class PrestigeParityTests: XCTestCase {

    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "PrestigeParityTests.\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    /// 300 ticks with menu/location/cashier all in play; every figure that reaches the player.
    private func run300Ticks() -> [Double] {
        let store = GameStore(defaults: UserDefaults(suiteName: suiteName)!)
        store.farm.plots[0].workerType = .none
        store.stall.menuTier = 2
        store.stall.locationTier = 1
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.stall.cashierEnergy = 1
        store.stall.menuCooks = [1, 1, 1]
        store.stall.warehouse = 200
        store.stall.warehouseCapacity = 200
        store.stall.coins = 5000
        var offered = 0.0
        for i in 0..<300 {
            store.tick(deltaTime: 0.1)
            if i % 3 == 0 {
                store.stall.menuStock[(i / 3) % 3] = max(store.stall.menuStock[(i / 3) % 3], 1)
                if let price = store.sellItem(menuIndex: (i / 3) % 3) {
                    offered += price
                    store.recordServed(waitTime: i % 2 == 0 ? 1 : 5)
                }
            }
            if i % 17 == 0 { store.recordFailed() }
        }
        return [store.stall.coins, store.progress.totalEarned, store.stall.pendingCoins, offered,
                store.progress.rating, Double(store.progress.totalServed), Double(store.progress.totalFailed),
                EarningsSystem.coinsPerSecond(for: store.stall)]
    }

    func test_prestige0_300TickRun_matchesMain() {
        // coins, totalEarned, pendingCoins, sum of sale prices, rating, served, failed, coins/s
        let expected: [Double] = [26007.5, 21007.5, 0.0, 21007.5, 4.093999999999945, 100.0, 18.0, 1140.0]
        XCTAssertEqual(run300Ticks(), expected)
    }
}
