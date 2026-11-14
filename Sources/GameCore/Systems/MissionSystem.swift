import Foundation

public enum MissionSystem {
    public static let missionsPerDay = 3
    public static let minimumReward: Double = 100
    public static let rewardSeconds: Double = 90
    public static let earnTargetSeconds: Double = 120
    /// Floor for the earn target on a fresh save with no measured rate: about one base sale per 10 s.
    public static let baseEarnRate: Double = 3
    public static let gourmetRatingFloor: Double = 3.0

    private static let serveTargets   = [20, 40, 80]
    private static let harvestTargets = [15, 30, 60]
    private static let cookTargets    = [15, 30, 60]
    private static let feverTargets   = [1, 2, 3]
    private static let gourmetTargets = [1, 2, 3]

    /// yyyymmdd in the calendar's local day.
    public static func dayKey(for date: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    public static func reward(earningRate: Double) -> Double {
        max(minimumReward, rewardSeconds * earningRate)
    }

    public static func target(for kind: MissionKind, stallTier: Int, earningRate: Double) -> Int {
        let tier = min(max(stallTier, 0), 2)
        switch kind {
        case .serveCustomers: return serveTargets[tier]
        case .harvest:        return harvestTargets[tier]
        case .cookDishes:     return cookTargets[tier]
        case .triggerFever:   return feverTargets[tier]
        case .serveGourmets:  return gourmetTargets[tier]
        case .earnCoins:      return cleanNumber(earnTargetSeconds * max(earningRate, baseEarnRate))
        }
    }

    /// Two significant figures: 363.2 -> 360, 4812 -> 4800.
    static func cleanNumber(_ value: Double) -> Int {
        guard value >= 100 else { return max(1, Int(value.rounded())) }
        let step = pow(10, floor(log10(value)) - 1)
        return Int((value / step).rounded() * step)
    }

    /// Same day key and inputs always give the same missions.
    public static func roll(dayKey: Int, stallTier: Int, earningRate: Double, rating: Double) -> [Mission] {
        var pool = MissionKind.allCases
        if rating < gourmetRatingFloor { pool.removeAll { $0 == .serveGourmets } }

        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: dayKey))
        // Own Fisher-Yates: `shuffled(using:)` makes no cross-release promise about its order.
        for i in stride(from: pool.count - 1, to: 0, by: -1) {
            pool.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
        let reward = reward(earningRate: earningRate)
        return pool.prefix(missionsPerDay).map { kind in
            Mission(id: "\(dayKey)-\(kind.rawValue)", kind: kind,
                    target: target(for: kind, stallTier: stallTier, earningRate: earningRate),
                    reward: reward)
        }
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
