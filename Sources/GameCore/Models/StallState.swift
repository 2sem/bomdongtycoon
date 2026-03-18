import Foundation

public struct StallState: Codable {
    public var coins: Double = 0
    public var menuTier: Int = 0
    public var staffTier: Int = 0       // highest tier purchased
    public var stallTier: Int = 0
    public var pendingCoins: Double = 0

    // Per-tier headcounts (only tier1 can farm)
    public var tier1Count: Int = 0      // 알바생 — farm + cashier + cook
    public var tier2Count: Int = 0      // 이모님 — cashier + cook only
    public var tier3Count: Int = 0      // 봄동 요리사 — cashier + cook only

    // Position assignments
    public var cashierCount: Int = 0;
    public var menuCooks: [Int] = [0, 0, 0];   // one slot per menu

    // Worker energy (0.0–1.0) — per active slot
    public var menuCookEnergy: [Double] = [1.0, 1.0, 1.0];
    public var cashierEnergy: Double = 1.0;
    public var cashierTier: Int = 0;   // which tier worker is in the cashier slot

    // Idle energy pools — one Double per unassigned worker of each tier
    public var tier1IdleEnergies: [Double] = []
    public var tier2IdleEnergies: [Double] = []
    public var tier3IdleEnergies: [Double] = []

    // Warehouse
    public var warehouse: Int = 0
    public var warehouseCapacity: Int = 10
    public var menuStock: [Int] = [0, 0, 0]

    // Computed
    public var staffCount: Int { tier1Count + tier2Count + tier3Count }
    /// Number of shop-side workers (cashier + one cook per assigned menu slot)
    public var shopWorkers: Int { cashierCount + menuCooks.filter { $0 > 0 }.count }
    public var stock: Double { Double(menuStock.reduce(0, +)) }
    public var autoCollectEnabled: Bool { cashierCount > 0 }

    // Legacy — kept for FarmState compatibility only
    public var farmWorkers: Int = 0

    // Farm worker training level (global, shared by all farm-assigned 알바생)
    public var farmWorkerTier: Int = 1

    private enum CodingKeys: String, CodingKey {
        case coins, menuTier, staffTier, stallTier, pendingCoins
        case tier1Count, tier2Count, tier3Count
        case cashierCount, menuCooks
        case menuCookEnergy, cashierEnergy, cashierTier
        case tier1IdleEnergies, tier2IdleEnergies, tier3IdleEnergies
        case warehouse, warehouseCapacity, menuStock
        case farmWorkers
        case farmWorkerTier
    }

    public init() {}
}
