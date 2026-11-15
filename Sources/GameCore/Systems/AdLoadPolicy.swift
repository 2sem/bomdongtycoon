import Foundation

/// When a failed ad load is retried and how long a loaded ad may be kept. The lifetimes sit just
/// inside AdMob's own (rewarded 1 h, app open 4 h) so a kept ad never fails to present.
public enum AdLoadPolicy {
    public static let baseRetryDelay: TimeInterval = 2
    public static let maxRetryDelay: TimeInterval = 64
    public static let rewardedLifetime: TimeInterval = 55 * 60
    public static let appOpenLifetime: TimeInterval = 3 * 3600 + 55 * 60

    /// 2, 4, 8 ... capped at 64 s; `failures` is the consecutive failure count including the one just seen.
    public static func retryDelay(afterFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return baseRetryDelay }
        let exponent = min(failures - 1, 6)
        return min(baseRetryDelay * pow(2, Double(exponent)), maxRetryDelay)
    }

    public static func isExpired(loadedAt: Date, lifetime: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSince(loadedAt) >= lifetime
    }

    public static func isRewardedExpired(loadedAt: Date, now: Date) -> Bool {
        isExpired(loadedAt: loadedAt, lifetime: rewardedLifetime, now: now)
    }

    public static func isAppOpenExpired(loadedAt: Date, now: Date) -> Bool {
        isExpired(loadedAt: loadedAt, lifetime: appOpenLifetime, now: now)
    }
}
