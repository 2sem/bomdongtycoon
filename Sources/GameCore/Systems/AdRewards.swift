import Foundation

/// One rewarded ad surface. Each has its own ad unit so reporting is per placement.
public enum AdPlacement: String, CaseIterable, Codable, Sendable {
    case offline, fever, mission, boost, gift, renewal
}

/// Which rewarded prompt may animate: never more than one at a time, the most urgent first.
public enum AdPromptSurface: Equatable {
    case gift, boost, fever

    public static func active(giftPresent: Bool, boostAvailable: Bool, feverAdAvailable: Bool) -> AdPromptSurface? {
        if giftPresent { return .gift }
        if boostAvailable { return .boost }
        if feverAdAvailable { return .fever }
        return nil
    }
}

/// 선물 상자: timing and amount. The roll is injected through the store so it stays testable.
public enum GiftSystem {
    public static let minInterval: Double = 240
    public static let maxInterval: Double = 360
    /// A first crate never appears before this much play time of the install.
    public static let firstGiftPlaySeconds: Double = 240
    public static let lifetime: Double = 30
    public static let amountSales: Double = 20
    public static let amountIncomeSeconds: Double = 150

    public static func interval(roll: Double) -> Double {
        minInterval + (maxInterval - minInterval) * min(max(roll, 0), 1)
    }

    public static func amount(bestSalePrice: Double, earningRate: Double) -> Double {
        max(amountSales * bestSalePrice, amountIncomeSeconds * earningRate).rounded()
    }
}

/// 봄바람 부스트 and the fever recharge: durations, cooldowns and the shared grace period.
public enum AdBoostSystem {
    public static let boostDuration: Double = 180
    public static let boostCooldown: Double = 300
    /// A running boost can be extended by one more `boostDuration` while the total stays within this.
    public static let maxBankedSeconds: Double = 540
    public static let priceMultiplier: Double = 2
    public static let feverCooldown: Double = 300
    /// Hidden this long after the offer is closed without watching.
    public static let feverDeclineCooldown: Double = 180
    /// The recharge is only offered while the gauge is below this.
    public static let feverAdMaxCharge: Double = 0.7
    /// Rewarded offers for fever and boost wait until the install has this much play time.
    public static let graceSeconds: Double = 180
}

/// Persisted under its own key, outside the run blobs: a new spring must not refund a cooldown.
public struct AdRewardState: Codable, Equatable {
    public var boostEndsAt: Date?
    public var boostCooldownEndsAt: Date?

    public init() {}

    private enum CodingKeys: String, CodingKey { case boostEndsAt, boostCooldownEndsAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        boostEndsAt = c.decodeOrNil(Date.self, forKey: .boostEndsAt)
        boostCooldownEndsAt = c.decodeOrNil(Date.self, forKey: .boostCooldownEndsAt)
    }
}

/// Minimum spacing between repeats of a notice.
public struct CooldownGate {
    public let interval: TimeInterval
    private var last: Date?

    public init(interval: TimeInterval) { self.interval = interval }

    public mutating func fire(now: Date) -> Bool {
        if let last, now.timeIntervalSince(last) < interval { return false }
        last = now
        return true
    }
}
