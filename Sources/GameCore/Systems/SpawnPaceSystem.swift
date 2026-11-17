import Foundation

/// 가게 단장 rush: a timed customer surge that comes with buying a renovation level.
public enum RushSystem {
    public static let duration: Double = 120
    public static let spawnIntervalMultiplier: Double = 0.6
}

/// 전단지 알바: a temporary hire for a shop that is quiet (rating under 3.0). Not a staff member.
public enum PartTimerSystem {
    public static let shiftDuration: Double = 180
    public static let spawnIntervalMultiplier: Double = 0.7
    /// Cheap enough for a stuck shop, dear enough that the ad is the better deal.
    public static let feeSales: Double = 10

    public enum Payment { case coins, ad }

    public static func fee(bestSalePrice: Double) -> Double {
        Double(MissionSystem.cleanNumber(feeSales * bestSalePrice))
    }
}

/// Fever, the rush and the part-timer never multiply: the strongest (shortest interval) one wins.
public enum SpawnPaceSystem {
    /// `floor` is the 3.0 shop's interval: the part-timer alone never makes a shop busier than that.
    public static func interval(base: Double, floor: Double, feverActive: Bool, rushActive: Bool,
                                partTimerActive: Bool) -> Double {
        var best = base
        if feverActive { best = min(best, base * FeverSystem.spawnIntervalMultiplier) }
        if rushActive { best = min(best, base * RushSystem.spawnIntervalMultiplier) }
        if partTimerActive {
            best = min(best, min(base, max(base * PartTimerSystem.spawnIntervalMultiplier, floor)))
        }
        return best
    }
}
