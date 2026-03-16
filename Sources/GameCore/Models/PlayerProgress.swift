import Foundation

public struct PlayerProgress: Codable {
    public var isFirstLaunch: Bool = true
    public var isShopNameSet: Bool = false
    public var shopName: String = "봄동 가게"
    public var lastActiveDate: Date? = nil
    public var seasonStartDate: Date? = nil
    public var totalEarned: Double = 0

    public init() {}
}
