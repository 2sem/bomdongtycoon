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

// MARK: - Goal selection vs. staff unlock

extension EarningsSystemTests {
    private func goal(stallTier: Int, staffTier: Int, coins: Double,
                      menuTier: Int = 2, locationTier: Int = 0) -> String? {
        var stall = StallState()
        stall.stallTier = stallTier
        stall.staffTier = staffTier
        stall.menuTier = menuTier       // menu maxed so it never competes
        stall.locationTier = locationTier
        stall.coins = coins
        return EarningsSystem.nextGoalUpgrade(for: stall)?.name
    }

    func test_staffUnlockRule_perTier() {
        XCTAssertTrue(UpgradeDefinitions.isStaffTierUnlocked(1, stallTier: 0))
        XCTAssertFalse(UpgradeDefinitions.isStaffTierUnlocked(2, stallTier: 0))
        XCTAssertTrue(UpgradeDefinitions.isStaffTierUnlocked(2, stallTier: 1))
        XCTAssertFalse(UpgradeDefinitions.isStaffTierUnlocked(3, stallTier: 1))
        XCTAssertTrue(UpgradeDefinitions.isStaffTierUnlocked(3, stallTier: 2))
        XCTAssertFalse(UpgradeDefinitions.isStaffTierUnlocked(4, stallTier: 2))
        XCTAssertFalse(UpgradeDefinitions.isStaffTierUnlocked(0, stallTier: 2))
    }

    func test_lockedImoGoal_fallsBackToStallUpgrade() {
        // 3,000 coins covers 이모님 but the stall is still 포장마차.
        XCTAssertEqual(goal(stallTier: 0, staffTier: 1, coins: 3_000), "봄동 식당")
        XCTAssertEqual(goal(stallTier: 0, staffTier: 1, coins: 2_999), "봄동 식당")
        XCTAssertEqual(goal(stallTier: 0, staffTier: 1, coins: 100_000), "봄동 식당")
    }

    func test_unlockedImoGoal_isChosenOnceStallIsTier1() {
        XCTAssertEqual(goal(stallTier: 1, staffTier: 1, coins: 0), "이모님")  // 3,000 < 25,000
        XCTAssertEqual(goal(stallTier: 1, staffTier: 1, coins: 3_000), "이모님")
    }

    func test_lockedChefGoal_fallsBackToStallUpgrade() {
        XCTAssertEqual(goal(stallTier: 1, staffTier: 2, coins: 15_000), "봄동 전문점")
        XCTAssertEqual(goal(stallTier: 1, staffTier: 2, coins: 14_999), "봄동 전문점")
    }

    func test_unlockedChefGoal_isChosenAtStallTier2() {
        XCTAssertEqual(goal(stallTier: 2, staffTier: 2, coins: 15_000), "봄동 요리사")
    }

    func test_firstHire_neverGated() {
        XCTAssertEqual(goal(stallTier: 0, staffTier: 0, coins: 0), "알바생")
        XCTAssertEqual(goal(stallTier: 0, staffTier: 0, coins: 500), "알바생")
    }

    func test_nextAffordableUpgrade_skipsLockedStaff() {
        var stall = StallState()
        stall.staffTier = 1
        stall.menuTier = 2
        stall.coins = 4_000
        XCTAssertNil(EarningsSystem.nextAffordableUpgrade(for: stall))  // 이모님 locked, 식당 5,000
        stall.coins = 5_000
        XCTAssertEqual(EarningsSystem.nextAffordableUpgrade(for: stall)?.name, "봄동 식당")
    }

    func test_locationGoalText_groupsThousands() {
        var stall = StallState()
        stall.stallTier = 2
        stall.staffTier = 3
        stall.menuTier = 2
        stall.coins = 39_530
        let text = EarningsSystem.locationGoalText(for: stall)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("39,530 / 40,000") == true, text ?? "nil")
    }

    func test_coinFormat_groupsAndTruncates() {
        XCTAssertEqual(CoinFormat.string(0), "0")
        XCTAssertEqual(CoinFormat.string(999.9), "999")
        XCTAssertEqual(CoinFormat.string(1_000), "1,000")
        XCTAssertEqual(CoinFormat.string(1_234_567), "1,234,567")
    }
}
