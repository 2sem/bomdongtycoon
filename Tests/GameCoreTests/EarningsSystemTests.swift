import XCTest
@testable import GameCore

final class EarningsSystemTests: XCTestCase {

    func test_coinsPerSecond_baseLine() {
        let stall = StallState()
        // base: 1.0 items/s × 30.0 coins/item = 30.0
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 30.0, accuracy: 0.01)
    }

    func test_coinsPerSecond_withStaffTier1() {
        var stall = StallState()
        stall.staffTier = 1  // production ×2.0
        // 1.0 × 2.0 × 30.0 = 60.0
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 60.0, accuracy: 0.01)
    }

    func test_coinsPerSecond_multipleUpgrades() {
        var stall = StallState()
        stall.menuTier = 1   // price ×2.5
        stall.staffTier = 1  // production ×2.0
        stall.stallTier = 1  // maxStock only — no effect on rate
        // production: 1.0 × 2.0 = 2.0; price: 30 × 2.5 = 75.0; total: 150.0
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 150.0, accuracy: 0.01)
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
