import Foundation

public enum EarningsSystem {

    static let baseProductionRate: Double = 1.0   // items per second
    static let basePricePerItem: Double = 30.0    // coins per item sold

    /// Items produced per second based on staff and location upgrades
    public static func productionRate(for stall: StallState) -> Double {
        var rate = baseProductionRate
        if stall.staffTier > 0 {
            rate *= UpgradeDefinitions.staff[stall.staffTier - 1].productionMultiplier
        }
        return rate
    }

    /// Coins earned per item sold based on menu and location upgrades
    public static func pricePerItem(for stall: StallState) -> Double {
        basePricePerItem * UpgradeDefinitions.menu[stall.menuTier].priceMultiplier
    }

    /// Price for a specific menu slot (겉절이=30, 봄동김치=75, 봄동비빔밥=180)
    public static func pricePerItem(for stall: StallState, menuIndex: Int) -> Double {
        guard menuIndex < UpgradeDefinitions.menu.count else { return basePricePerItem }
        return basePricePerItem * UpgradeDefinitions.menu[menuIndex].priceMultiplier
    }

    /// Maximum stock the stall can hold at once
    public static func maxStock(for stall: StallState) -> Int {
        UpgradeDefinitions.stall[stall.stallTier].maxStock
    }

    /// Coins per second summed across all assigned menu slots.
    /// Each slot uses its cook's actual tier (production rate) and its own menu price.
    public static func coinsPerSecond(for stall: StallState) -> Double {
        var total = 0.0
        for i in 0...stall.menuTier {
            let cookTier = i < stall.menuCooks.count ? stall.menuCooks[i] : 0
            guard cookTier > 0, cookTier <= UpgradeDefinitions.staff.count else { continue }
            let rate  = baseProductionRate * UpgradeDefinitions.staff[cookTier - 1].productionMultiplier
            let price = pricePerItem(for: stall, menuIndex: i)
            total += rate * price
        }
        return total
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
        return result
    }
}
