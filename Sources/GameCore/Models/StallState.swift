import Foundation

public struct StallState: Codable {
    public var coins: Double = 0
    public var menuTier: Int = 0       // 0=겉절이, 1=봄동김치, 2=봄동비빔밥
    public var staffTier: Int = 0      // 0=none, 1=알바생, 2=아주머니, 3=요리사
    public var stallTier: Int = 0      // 0=포장마차, 1=분식집, 2=전문점
    public var locationTier: Int = 0   // 0=골목, 1=시장, 2=강남
    public var pendingCoins: Double = 0
    /// Fractional stock accumulator — whole items are sold to customers
    public var stock: Double = 0
    /// Workers assigned to the shop (auto-collect coins)
    public var shopWorkers: Int = 0
    /// Workers assigned to the farm (auto-harvest plots)
    public var farmWorkers: Int = 0

    /// Auto-collect is active when at least one worker is assigned to the shop
    public var autoCollectEnabled: Bool { shopWorkers > 0 }

    public init() {}
}
