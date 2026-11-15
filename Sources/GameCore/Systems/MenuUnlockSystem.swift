import Foundation

/// What buying a dish's padlock would do right now. One rule for the upgrade sheet's menu
/// purchase and the padlock tap on the counter: coins only, and only the next dish in order.
public enum MenuUnlockStatus: Equatable, Sendable {
    /// The next dish, and the coins are there.
    case available(menuIndex: Int, cost: Double)
    /// The next dish, `shortfall` coins away.
    case short(menuIndex: Int, cost: Double, shortfall: Double)
    /// A dish further down the line: `nextIndex` has to be unlocked first.
    case needsEarlier(menuIndex: Int, nextIndex: Int)
    /// Already unlocked, or not a dish at all.
    case notLocked
}

public enum MenuUnlockSystem {
    /// Cost of the next dish; nil once every dish is unlocked.
    public static func nextCost(for stall: StallState) -> Double? {
        let next = stall.menuTier + 1
        guard next < UpgradeDefinitions.menu.count else { return nil }
        return UpgradeDefinitions.menu[next].coinCost
    }

    public static func status(for stall: StallState, menuIndex: Int) -> MenuUnlockStatus {
        let next = stall.menuTier + 1
        guard menuIndex >= next, menuIndex < UpgradeDefinitions.menu.count,
              let cost = nextCost(for: stall) else { return .notLocked }
        guard menuIndex == next else { return .needsEarlier(menuIndex: menuIndex, nextIndex: next) }
        return stall.coins >= cost
            ? .available(menuIndex: menuIndex, cost: cost)
            : .short(menuIndex: menuIndex, cost: cost, shortfall: cost - stall.coins)
    }
}
