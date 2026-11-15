import Foundation

/// 가게 단장: the endless sink that opens at the final stall tier. Each level adds 8% to every sale.
public enum RenovationSystem {
    public static let priceBonusPerLevel: Double = 0.08
    public static let baseCost: Double = 30_000
    public static let costGrowth: Double = 1.25

    public static func isUnlocked(for stall: StallState) -> Bool {
        stall.stallTier >= UpgradeDefinitions.stall.count - 1
    }

    /// Composed once in `EarningsSystem.pricePerItem`, so live sales, `coinsPerSecond` and offline
    /// earnings all inherit it.
    public static func priceMultiplier(level: Int) -> Double {
        1 + priceBonusPerLevel * Double(max(0, level))
    }

    /// Two significant figures so the cost reads as a round number: 30,000, 38,000, 47,000, 59,000.
    public static func cost(forLevel level: Int) -> Double {
        Double(MissionSystem.cleanNumber(baseCost * pow(costGrowth, Double(max(0, level)))))
    }

    public static func nextCost(for stall: StallState) -> Double? {
        isUnlocked(for: stall) ? cost(forLevel: stall.renovationLevel) : nil
    }

    /// Whole percent the next level adds (for copy).
    public static var percentPerLevel: Int { Int((priceBonusPerLevel * 100).rounded()) }
}
