import Foundation

public enum EarningsSystem {

    static let baseCoinsPerSecond: Double = 1.0

    public static func coinsPerSecond(for stall: StallState) -> Double {
        var rate = baseCoinsPerSecond

        if stall.menuTier > 0 {
            rate *= UpgradeDefinitions.menu[stall.menuTier].earningsMultiplier
        }
        if stall.staffTier > 0 {
            rate *= UpgradeDefinitions.staff[stall.staffTier - 1].earningsMultiplier
        }
        if stall.stallTier > 0 {
            rate *= UpgradeDefinitions.stall[stall.stallTier].earningsMultiplier
        }
        if stall.locationTier > 0 {
            rate *= UpgradeDefinitions.location[stall.locationTier].earningsMultiplier
        }
        return rate
    }

    /// Returns the cheapest upgrade the player can currently afford
    public static func nextAffordableUpgrade(for stall: StallState) -> UpgradeDefinition? {
        candidates(for: stall)
            .filter { $0.coinCost <= stall.coins }
            .min(by: { $0.coinCost < $1.coinCost })
    }

    /// Returns the next upgrade the player is saving toward (cheapest overall)
    public static func nextGoalUpgrade(for stall: StallState) -> UpgradeDefinition? {
        candidates(for: stall).min(by: { $0.coinCost < $1.coinCost })
    }

    private static func candidates(for stall: StallState) -> [UpgradeDefinition] {
        var result: [UpgradeDefinition] = []
        if stall.staffTier < UpgradeDefinitions.staff.count {
            result.append(UpgradeDefinitions.staff[stall.staffTier])
        }
        if stall.menuTier + 1 < UpgradeDefinitions.menu.count {
            result.append(UpgradeDefinitions.menu[stall.menuTier + 1])
        }
        if stall.stallTier + 1 < UpgradeDefinitions.stall.count {
            result.append(UpgradeDefinitions.stall[stall.stallTier + 1])
        }
        if stall.locationTier + 1 < UpgradeDefinitions.location.count {
            result.append(UpgradeDefinitions.location[stall.locationTier + 1])
        }
        return result
    }
}
