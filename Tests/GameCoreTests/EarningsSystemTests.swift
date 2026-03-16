import XCTest
@testable import GameCore

final class EarningsSystemTests: XCTestCase {

    func test_coinsPerSecond_baseLine() {
        let stall = StallState()
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 1.0, accuracy: 0.01)
    }

    func test_coinsPerSecond_withStaffTier1() {
        var stall = StallState()
        stall.staffTier = 1
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 1.5, accuracy: 0.01)
    }

    func test_coinsPerSecond_multipleUpgrades() {
        var stall = StallState()
        stall.menuTier = 1   // x2.5
        stall.staffTier = 1  // x1.5
        stall.stallTier = 1  // x2.0
        // base 1.0 * 2.5 * 1.5 * 2.0 = 7.5
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall), 7.5, accuracy: 0.01)
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
