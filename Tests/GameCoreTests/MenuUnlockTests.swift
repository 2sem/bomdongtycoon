import XCTest
@testable import GameCore

@MainActor
final class MenuUnlockTests: XCTestCase {

    private func stall(tier: Int, coins: Double) -> StallState {
        var s = StallState()
        s.menuTier = tier
        s.coins = coins
        return s
    }

    func test_nextDish_affordable() {
        XCTAssertEqual(MenuUnlockSystem.status(for: stall(tier: 0, coins: 800), menuIndex: 1),
                       .available(menuIndex: 1, cost: 800))
    }

    func test_nextDish_short_reportsShortfall() {
        XCTAssertEqual(MenuUnlockSystem.status(for: stall(tier: 0, coins: 500), menuIndex: 1),
                       .short(menuIndex: 1, cost: 800, shortfall: 300))
    }

    func test_beyondNext_needsEarlier_evenWhenRich() {
        XCTAssertEqual(MenuUnlockSystem.status(for: stall(tier: 0, coins: 1_000_000), menuIndex: 2),
                       .needsEarlier(menuIndex: 2, nextIndex: 1))
    }

    func test_unlockedAndOutOfRange_notLocked() {
        let s = stall(tier: 1, coins: 0)
        XCTAssertEqual(MenuUnlockSystem.status(for: s, menuIndex: 0), .notLocked)
        XCTAssertEqual(MenuUnlockSystem.status(for: s, menuIndex: 1), .notLocked)
        XCTAssertEqual(MenuUnlockSystem.status(for: s, menuIndex: 9), .notLocked)
    }

    func test_allUnlocked() {
        let top = UpgradeDefinitions.menu.count - 1
        let s = stall(tier: top, coins: 1_000_000)
        XCTAssertNil(MenuUnlockSystem.nextCost(for: s))
        for i in 0...top { XCTAssertEqual(MenuUnlockSystem.status(for: s, menuIndex: i), .notLocked) }
    }

    func test_purchaseUpgrade_followsTheSameRule() {
        let store = GameStore(defaults: UserDefaults(suiteName: "MenuUnlockTests.\(UUID().uuidString)")!)
        store.stall.coins = 799
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.menuTier, 0)
        store.stall.coins = 800
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.menuTier, 1)
        XCTAssertEqual(store.stall.coins, 0)
    }
}
