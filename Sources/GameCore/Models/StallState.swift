import Foundation

public struct StallState: Codable {
    public var coins: Double = 50
    public var menuTier: Int = 0
    public var staffTier: Int = 0       // highest tier purchased
    public var stallTier: Int = 0
    /// Index into `UpgradeDefinitions.location` (0...2). Sale-price multiplier only.
    public var locationTier: Int = 0
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
    public var warehouse: Int = 5
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

    // Farm worker training level (legacy — kept for backward compat with old saves)
    public var farmWorkerTier: Int = 1

    // Farmer staff (farm-only, 2× speed)
    public var farmerCount: Int = 0
    public var farmerIdleEnergies: [Double] = []

    // Veteran alba staff (farm-only, 1.4× speed)
    public var veteranAlbaCount: Int = 0
    public var veteranAlbaIdleEnergies: [Double] = []

    private enum CodingKeys: String, CodingKey {
        case coins, menuTier, staffTier, stallTier, locationTier, pendingCoins
        case tier1Count, tier2Count, tier3Count
        case cashierCount, menuCooks
        case menuCookEnergy, cashierEnergy, cashierTier
        case tier1IdleEnergies, tier2IdleEnergies, tier3IdleEnergies
        case warehouse, warehouseCapacity, menuStock
        case farmWorkers, farmWorkerTier
        case farmerCount, farmerIdleEnergies
        case veteranAlbaCount, veteranAlbaIdleEnergies
    }

    /// Every key is optional so older saves (which predate `locationTier`) keep loading.
    public init(from decoder: Decoder) throws {
        let d = StallState()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = try c.decodeIfPresent(Double.self, forKey: .coins) ?? d.coins
        menuTier = try c.decodeIfPresent(Int.self, forKey: .menuTier) ?? d.menuTier
        staffTier = try c.decodeIfPresent(Int.self, forKey: .staffTier) ?? d.staffTier
        stallTier = try c.decodeIfPresent(Int.self, forKey: .stallTier) ?? d.stallTier
        let rawLocation = try c.decodeIfPresent(Int.self, forKey: .locationTier) ?? 0
        locationTier = min(max(rawLocation, 0), UpgradeDefinitions.location.count - 1)
        pendingCoins = try c.decodeIfPresent(Double.self, forKey: .pendingCoins) ?? d.pendingCoins
        tier1Count = try c.decodeIfPresent(Int.self, forKey: .tier1Count) ?? d.tier1Count
        tier2Count = try c.decodeIfPresent(Int.self, forKey: .tier2Count) ?? d.tier2Count
        tier3Count = try c.decodeIfPresent(Int.self, forKey: .tier3Count) ?? d.tier3Count
        cashierCount = try c.decodeIfPresent(Int.self, forKey: .cashierCount) ?? d.cashierCount
        menuCooks = try c.decodeIfPresent([Int].self, forKey: .menuCooks) ?? d.menuCooks
        menuCookEnergy = try c.decodeIfPresent([Double].self, forKey: .menuCookEnergy) ?? d.menuCookEnergy
        cashierEnergy = try c.decodeIfPresent(Double.self, forKey: .cashierEnergy) ?? d.cashierEnergy
        cashierTier = try c.decodeIfPresent(Int.self, forKey: .cashierTier) ?? d.cashierTier
        tier1IdleEnergies = try c.decodeIfPresent([Double].self, forKey: .tier1IdleEnergies) ?? d.tier1IdleEnergies
        tier2IdleEnergies = try c.decodeIfPresent([Double].self, forKey: .tier2IdleEnergies) ?? d.tier2IdleEnergies
        tier3IdleEnergies = try c.decodeIfPresent([Double].self, forKey: .tier3IdleEnergies) ?? d.tier3IdleEnergies
        warehouse = try c.decodeIfPresent(Int.self, forKey: .warehouse) ?? d.warehouse
        warehouseCapacity = try c.decodeIfPresent(Int.self, forKey: .warehouseCapacity) ?? d.warehouseCapacity
        menuStock = try c.decodeIfPresent([Int].self, forKey: .menuStock) ?? d.menuStock
        farmWorkers = try c.decodeIfPresent(Int.self, forKey: .farmWorkers) ?? d.farmWorkers
        farmWorkerTier = try c.decodeIfPresent(Int.self, forKey: .farmWorkerTier) ?? d.farmWorkerTier
        farmerCount = try c.decodeIfPresent(Int.self, forKey: .farmerCount) ?? d.farmerCount
        farmerIdleEnergies = try c.decodeIfPresent([Double].self, forKey: .farmerIdleEnergies) ?? d.farmerIdleEnergies
        veteranAlbaCount = try c.decodeIfPresent(Int.self, forKey: .veteranAlbaCount) ?? d.veteranAlbaCount
        veteranAlbaIdleEnergies = try c.decodeIfPresent([Double].self, forKey: .veteranAlbaIdleEnergies) ?? d.veteranAlbaIdleEnergies
    }

    public init() {
        // Start with one 알바생 assigned to farm — auto-harvests and is more useful than slow cooking for newbies
        tier1Count = 1
    }
}
