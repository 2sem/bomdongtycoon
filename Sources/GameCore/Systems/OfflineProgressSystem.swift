import Foundation

public enum OfflineProgressSystem {

    static let maxOfflineHours: Double = 8
    /// Offline earnings rate relative to real-time — keeps progression rewarding but not trivial
    public static let offlineEfficiency: Double = 0.25

    public static func calculateOfflineEarnings(
        stall: StallState,
        lastActiveDate: Date?,
        multiplier: Double = 1.0,
        seasonMultiplier: Double = 1.0
    ) -> Double {
        guard let lastActive = lastActiveDate else { return 0 }
        let elapsed = min(
            Date().timeIntervalSince(lastActive),
            maxOfflineHours * 3600
        )
        return EarningsSystem.coinsPerSecond(for: stall) * elapsed * multiplier * seasonMultiplier
    }
}
