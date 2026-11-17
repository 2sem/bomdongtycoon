import Foundation

/// 가게 단장 rush: a timed customer surge that comes with buying a renovation level.
public enum RushSystem {
    public static let duration: Double = 120
    public static let spawnIntervalMultiplier: Double = 0.6
}

/// 전단지 알바: a temporary hire for a shop that is quiet (rating under 3.0). Not a staff member.
public enum PartTimerSystem {
    public static let shiftDuration: Double = 180
    /// Customers that walk in with each natural arrival while a shift runs: "plus one", like a flyer tap.
    public static let extraCustomers = 1
    /// Cheap enough for a stuck shop, dear enough that the ad is the better deal.
    public static let feeSales: Double = 10

    public enum Payment { case coins, ad }

    public static func fee(bestSalePrice: Double) -> Double {
        Double(MissionSystem.cleanNumber(feeSales * bestSalePrice))
    }
}

/// Fever and the rush never multiply: the shorter interval wins. The part-timer leaves the interval alone
/// and brings `PartTimerSystem.extraCustomers` more customers with every arrival.
public enum SpawnPaceSystem {
    public static func interval(base: Double, feverActive: Bool, rushActive: Bool) -> Double {
        var best = base
        if feverActive { best = min(best, base * FeverSystem.spawnIntervalMultiplier) }
        if rushActive { best = min(best, base * RushSystem.spawnIntervalMultiplier) }
        return best
    }
}
