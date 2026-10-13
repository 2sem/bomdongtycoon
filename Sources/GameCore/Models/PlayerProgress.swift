import Foundation

public struct PlayerProgress: Codable {
    public var isFirstLaunch: Bool = true
    public var isShopNameSet: Bool = false
    public var shopName: String = "봄동 가게"
    public var lastActiveDate: Date? = nil
    public var totalEarned: Double = 0
    public var earningRate: Double = 0     // coins/s rolling average, updated every 5s
    public var rating: Double = 3.0
    public var totalServed: Int = 0
    public var totalFailed: Int = 0

    // MARK: Prestige and stats
    // `legacyMultiplier` is derived from `prestigeCount` (`PrestigeSystem`), never stored.
    // Lifetime totals above only ever grow; "this run" is the total minus its `runBaseline*`, which
    // a new spring (PR 2) will set to the totals at the moment of the reset.
    public var prestigeCount: Int = 0
    public var totalPlaySeconds: TimeInterval = 0
    public var runBaselinePlaySeconds: TimeInterval = 0
    public var runBaselineEarned: Double = 0
    public var runBaselineServed: Int = 0
    public var runBaselineFailed: Int = 0
    /// Highest rating ever reached. Read through `highestRating`: saves from before this field
    /// carry only the live `rating`.
    public var bestRating: Double = 0
    public var fastestRunSeconds: TimeInterval? = nil
    public var hasSeenPrestigeIntro: Bool = false

    public init() {}

    public var highestRating: Double { max(bestRating, rating) }
    public var runPlaySeconds: TimeInterval { max(0, totalPlaySeconds - runBaselinePlaySeconds) }
    public var runEarned: Double { max(0, totalEarned - runBaselineEarned) }
    public var runServed: Int { max(0, totalServed - runBaselineServed) }
    public var runFailed: Int { max(0, totalFailed - runBaselineFailed) }

    /// Every key is optional: a field added in a later release must not make older saves fail to decode.
    public init(from decoder: Decoder) throws {
        let d = PlayerProgress()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isFirstLaunch   = c.decodeOrDefault(.isFirstLaunch, d.isFirstLaunch)
        isShopNameSet   = c.decodeOrDefault(.isShopNameSet, d.isShopNameSet)
        shopName        = c.decodeOrDefault(.shopName, d.shopName)
        lastActiveDate  = c.decodeOrNil(Date.self, forKey: .lastActiveDate)
        totalEarned     = c.decodeOrDefault(.totalEarned, d.totalEarned)
        earningRate     = c.decodeOrDefault(.earningRate, d.earningRate)
        rating          = c.decodeOrDefault(.rating, d.rating)
        totalServed     = c.decodeOrDefault(.totalServed, d.totalServed)
        totalFailed     = c.decodeOrDefault(.totalFailed, d.totalFailed)
        prestigeCount          = c.decodeOrDefault(.prestigeCount, d.prestigeCount)
        totalPlaySeconds       = c.decodeOrDefault(.totalPlaySeconds, d.totalPlaySeconds)
        runBaselinePlaySeconds = c.decodeOrDefault(.runBaselinePlaySeconds, d.runBaselinePlaySeconds)
        runBaselineEarned      = c.decodeOrDefault(.runBaselineEarned, d.runBaselineEarned)
        runBaselineServed      = c.decodeOrDefault(.runBaselineServed, d.runBaselineServed)
        runBaselineFailed      = c.decodeOrDefault(.runBaselineFailed, d.runBaselineFailed)
        bestRating             = c.decodeOrDefault(.bestRating, d.bestRating)
        fastestRunSeconds      = c.decodeOrNil(TimeInterval.self, forKey: .fastestRunSeconds)
        hasSeenPrestigeIntro   = c.decodeOrDefault(.hasSeenPrestigeIntro, d.hasSeenPrestigeIntro)
    }
}
