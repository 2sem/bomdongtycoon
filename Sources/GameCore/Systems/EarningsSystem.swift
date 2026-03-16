import Foundation

public enum EarningsSystem {

    static let baseProductionRate: Double = 1.0   // items per second
    static let basePricePerItem: Double = 10.0    // coins per item sold

    /// Items produced per second based on staff and location upgrades
    public static func productionRate(for stall: StallState) -> Double {
        var rate = baseProductionRate
        if stall.staffTier > 0 {
            rate *= UpgradeDefinitions.staff[stall.staffTier - 1].productionMultiplier
        }
        rate *= UpgradeDefinitions.location[stall.locationTier].productionMultiplier
        return rate
    }

    /// Coins earned per item sold based on menu and location upgrades
    public static func pricePerItem(for stall: StallState) -> Double {
        var price = basePricePerItem
        price *= UpgradeDefinitions.menu[stall.menuTier].priceMultiplier
        price *= UpgradeDefinitions.location[stall.locationTier].priceMultiplier
        return price
    }

    /// Maximum stock the stall can hold at once
    public static func maxStock(for stall: StallState) -> Int {
        UpgradeDefinitions.stall[stall.stallTier].maxStock
    }

    /// Derived coins per second = productionRate × pricePerItem (used for HUD and offline)
    public static func coinsPerSecond(for stall: StallState) -> Double {
        productionRate(for: stall) * pricePerItem(for: stall)
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
