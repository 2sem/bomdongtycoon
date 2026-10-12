import Foundation

public struct PlayerProgress: Codable {
    public var isFirstLaunch: Bool = true
    public var isShopNameSet: Bool = false
    public var shopName: String = "봄동 가게"
    public var lastActiveDate: Date? = nil
    public var seasonStartDate: Date? = nil
    public var totalEarned: Double = 0
    public var earningRate: Double = 0     // coins/s rolling average, updated every 5s
    public var rating: Double = 3.0
    public var totalServed: Int = 0
    public var totalFailed: Int = 0

    public init() {}

    /// Every key is optional: a field added in a later release must not make older saves fail to decode.
    public init(from decoder: Decoder) throws {
        let d = PlayerProgress()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isFirstLaunch   = c.decodeOrDefault(.isFirstLaunch, d.isFirstLaunch)
        isShopNameSet   = c.decodeOrDefault(.isShopNameSet, d.isShopNameSet)
        shopName        = c.decodeOrDefault(.shopName, d.shopName)
        lastActiveDate  = c.decodeOrNil(Date.self, forKey: .lastActiveDate)
        seasonStartDate = c.decodeOrNil(Date.self, forKey: .seasonStartDate)
        totalEarned     = c.decodeOrDefault(.totalEarned, d.totalEarned)
        earningRate     = c.decodeOrDefault(.earningRate, d.earningRate)
        rating          = c.decodeOrDefault(.rating, d.rating)
        totalServed     = c.decodeOrDefault(.totalServed, d.totalServed)
        totalFailed     = c.decodeOrDefault(.totalFailed, d.totalFailed)
    }
}
