import XCTest
@testable import GameCore

final class EarningsSystemTests: XCTestCase {

    // coinsPerSecond sums per menu slot, driven by the cook assigned to it
    // (menuCooks[i] = worker tier, 0 = nobody). staffTier is an unlock, not a rate input.

    func test_coinsPerSecond_baseLine() {
        // No cook assigned to any slot: nothing is produced.
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: StallState()), 0, accuracy: 0.01)

        var withCook = StallState()
        withCook.menuCooks = [1, 0, 0]
        // tier-1 cook 2.0 items/s x 30 coins/item = 60
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: withCook), 60.0, accuracy: 0.01)
    }

    func test_coinsPerSecond_withStaffTier1() {
        var stall = StallState()
        stall.staffTier = 1
        stall.menuCooks = [1, 0, 0]  // tier-1 cook, production x2.0
        // 1.0 x 2.0 x 30.0 = 60.0
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 60.0, accuracy: 0.01)

        stall.menuCooks = [2, 0, 0]  // tier-2 cook, production x4.0
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 120.0, accuracy: 0.01)
    }

    func test_coinsPerSecond_multipleUpgrades() {
        var stall = StallState()
        stall.menuTier = 1   // second menu slot opens, price x2.5
        stall.staffTier = 1
        stall.stallTier = 1  // maxStock only — no effect on rate
        stall.menuCooks = [1, 1, 0]
        // slot 0: 2.0 x 30 = 60; slot 1: 2.0 x 75 = 150; total 210
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 210.0, accuracy: 0.01)
    }

    func test_maxStock_baseLine() {
        let stall = StallState()
        XCTAssertEqual(EarningsSystem.maxStock(for: stall), 15)
    }

    func test_maxStock_tier1() {
        var stall = StallState()
        stall.stallTier = 1
        XCTAssertEqual(EarningsSystem.maxStock(for: stall), 30)
    }

    func test_pricePerItem_withMenuUpgrade() {
        var stall = StallState()
        stall.menuTier = 1  // ×2.5
        XCTAssertEqual(EarningsSystem.pricePerItem(for: stall), 75.0, accuracy: 0.01)
    }

    func test_nextAffordableUpgrade_returnsLowestAffordable() {
        var stall = StallState()
        stall.coins = 600
        let next = EarningsSystem.nextAffordableUpgrade(for: stall)
        XCTAssertEqual(next?.name, "알바생")  // costs 500
    }

    func test_nextAffordableUpgrade_noneAffordable() {
        let stall = StallState()  // 0 coins
        XCTAssertNil(EarningsSystem.nextAffordableUpgrade(for: stall))
    }

    func test_nextGoalUpgrade_returnsSmallestCost() {
        let stall = StallState()  // 0 coins — all unaffordable
        let goal = EarningsSystem.nextGoalUpgrade(for: stall)
        XCTAssertNotNil(goal)
        XCTAssertEqual(goal?.name, "알바생")  // cheapest at 500
    }
}
