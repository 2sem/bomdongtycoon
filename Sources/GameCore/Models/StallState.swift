import Foundation

public struct StallState: Codable {
    public var coins: Double = 0
    public var menuTier: Int = 0
    public var staffTier: Int = 0      // quality tier: 0=none, 1=알바생, 2=이모님, 3=요리사
    public var staffCount: Int = 0     // total workers hired (headcount)
    public var stallTier: Int = 0
    public var locationTier: Int = 0
    public var pendingCoins: Double = 0
    public var shopWorkers: Int = 0
    public var farmWorkers: Int = 0
    public var warehouse: Int = 0
    public var warehouseCapacity: Int = 10
    public var menuStock: [Int] = [0, 0, 0]

    /// Computed — sum of all menu stocks; excluded from Codable via CodingKeys
    public var stock: Double { Double(menuStock.reduce(0, +)) }

    public var autoCollectEnabled: Bool { shopWorkers > 0 }

    // Exclude stock from Codable
    private enum CodingKeys: String, CodingKey {
        case coins, menuTier, staffTier, staffCount, stallTier, locationTier
        case pendingCoins, shopWorkers, farmWorkers
        case warehouse, warehouseCapacity, menuStock
    }

    public init() {}
}
