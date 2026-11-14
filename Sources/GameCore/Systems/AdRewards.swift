import Foundation

/// One rewarded ad surface. Each has its own ad unit so reporting is per placement.
public enum AdPlacement: String, CaseIterable, Codable {
    case offline, fever, mission, boost, gift

    /// Production rewarded unit per placement; the one table the App reads. Debug builds use Google's test unit.
    public var releaseUnitID: String {
        switch self {
        case .offline: "ca-app-pub-9684378399371172/3844454464"
        case .fever:   "ca-app-pub-9684378399371172/5741927518"
        case .mission: "ca-app-pub-9684378399371172/8096628117"
        case .boost:   "ca-app-pub-9684378399371172/6404272495"
        case .gift:    "ca-app-pub-9684378399371172/5248917584"
        }
    }
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
    public static let priceMultiplier: Double = 2
    public static let feverCooldown: Double = 180
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
