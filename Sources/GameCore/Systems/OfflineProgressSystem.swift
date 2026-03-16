import Foundation

public enum OfflineProgressSystem {

    static let maxOfflineHours: Double = 8

    public static func calculateOfflineEarnings(
        stall: StallState,
        lastActiveDate: Date?,
        multiplier: Double = 1.0
    ) -> Double {
        guard let lastActive = lastActiveDate else { return 0 }
        let elapsed = min(
            Date().timeIntervalSince(lastActive),
            maxOfflineHours * 3600
        )
        return EarningsSystem.coinsPerSecond(for: stall) * elapsed * multiplier
    }
}
