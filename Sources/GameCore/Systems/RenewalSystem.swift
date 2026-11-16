import Foundation

/// 리뉴얼 오픈: a failed shop gets its rating back to 3.0 for a fee or an ad, once in a while.
public enum RenewalSystem {
    /// Offered while the HUD shows a rating under this.
    public static let eligibleBelowRating: Double = 2.5
    public static let resultingRating: Double = 3.0
    /// The coin fee, in sales of the best unlocked dish: dear enough that it is not a free refresh,
    /// cheap enough that a stuck shop can still pay it.
    public static let feeSales: Double = 30
    /// Play seconds before another reopening can be offered, so it cannot be farmed.
    public static let cooldown: Double = 600

    public enum Payment { case coins, ad }

    public static func fee(bestSalePrice: Double) -> Double {
        Double(MissionSystem.cleanNumber(feeSales * bestSalePrice))
    }
}
