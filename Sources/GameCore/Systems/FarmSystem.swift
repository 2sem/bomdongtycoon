import Foundation

public enum FarmSystem {
    public static let baseGrowthDuration: Double = 12.0

    public static func growthRate(for farm: FarmState) -> Double {
        let tier = min(farm.upgradeTier, UpgradeDefinitions.farm.count - 1)
        return (1.0 / baseGrowthDuration) * UpgradeDefinitions.farm[tier].growthMultiplier
    }

    public static func harvestYield(for farm: FarmState) -> Int {
        let tier = min(farm.upgradeTier, UpgradeDefinitions.farm.count - 1)
        return UpgradeDefinitions.farm[tier].harvestYield
    }

    public static func activePlotCount(for farm: FarmState) -> Int {
        let tier = min(farm.upgradeTier, UpgradeDefinitions.farm.count - 1)
        return UpgradeDefinitions.farm[tier].plotCount
    }
}
