import Foundation

/// 레시피 강화: the continuous sink that opens with each dish. Every level adds 10% to that dish's price.
public enum RecipeSystem {
    public static let maxLevel = 20
    public static let priceBonusPerLevel: Double = 0.10
    public static let costGrowth: Double = 1.5
    /// Level-0 cost per menu index: 겉절이, 봄동김치, 봄동비빔밥.
    public static let baseCosts: [Double] = [150, 600, 2_500]

    /// Composed once in `EarningsSystem.pricePerItem(for:menuIndex:)`, so live sales,
    /// `coinsPerSecond` and offline earnings all inherit it.
    public static func priceMultiplier(level: Int) -> Double {
        1 + priceBonusPerLevel * Double(min(max(0, level), maxLevel))
    }

    public static func level(for stall: StallState, menuIndex: Int) -> Int {
        stall.recipeLevels.indices.contains(menuIndex) ? stall.recipeLevels[menuIndex] : 0
    }

    public static func isUnlocked(menuIndex: Int, stall: StallState) -> Bool {
        menuIndex >= 0 && menuIndex <= stall.menuTier && menuIndex < baseCosts.count
    }

    /// Two significant figures, like the renovation: 150, 230, 340, 510, 760.
    public static func cost(menuIndex: Int, level: Int) -> Double? {
        guard baseCosts.indices.contains(menuIndex), level >= 0, level < maxLevel else { return nil }
        return Double(MissionSystem.cleanNumber(baseCosts[menuIndex] * pow(costGrowth, Double(level))))
    }

    /// nil when the dish is locked or already at `maxLevel`.
    public static func nextCost(for stall: StallState, menuIndex: Int) -> Double? {
        guard isUnlocked(menuIndex: menuIndex, stall: stall) else { return nil }
        return cost(menuIndex: menuIndex, level: level(for: stall, menuIndex: menuIndex))
    }

    /// Whole percent the dish's price is up by at `level` (for copy).
    public static func bonusPercent(level: Int) -> Int {
        Int(((priceMultiplier(level: level) - 1) * 100).rounded())
    }

    public static var percentPerLevel: Int { Int((priceBonusPerLevel * 100).rounded()) }
}
