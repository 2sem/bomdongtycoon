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

    /// Asleep: set when a post's energy hits 0, cleared only at full energy. A sleeping worker does no work.
    public var menuCookResting: [Bool] = [false, false, false]
    public var cashierResting: Bool = false

    // Idle energy pools — one Double per unassigned worker of each tier
    public var tier1IdleEnergies: [Double] = []
    public var tier2IdleEnergies: [Double] = []
    public var tier3IdleEnergies: [Double] = []

    /// Worker levels (1...`StaffLevelSystem.maxLevel`), parallel to the energy fields above: a level
    /// belongs to the individual worker and travels with her between posts and the bench.
    public var menuCookLevels: [Int] = [1, 1, 1]
    public var cashierLevel: Int = 1
    public var tier1IdleLevels: [Int] = []
    public var tier2IdleLevels: [Int] = []
    public var tier3IdleLevels: [Int] = []
    public var farmerIdleLevels: [Int] = []
    public var veteranAlbaIdleLevels: [Int] = []

    // Warehouse
    public var warehouse: Int = 5
    public var warehouseCapacity: Int = WarehouseSystem.baseCapacity
    public var menuStock: [Int] = [0, 0, 0]

    // Computed
    public var staffCount: Int { tier1Count + tier2Count + tier3Count }
    public var stock: Double { Double(menuStock.reduce(0, +)) }

    // Older saves still carry `farmWorkers` and `farmWorkerTier` (write-only, never read);
    // decoding ignores keys it does not know, so they are simply dropped on the next save.

    // Farmer staff (farm-only, 2× speed)
    public var farmerCount: Int = 0
    public var farmerIdleEnergies: [Double] = []

    // Veteran alba staff (farm-only, 1.4× speed)
    public var veteranAlbaCount: Int = 0
    public var veteranAlbaIdleEnergies: [Double] = []

    /// 가게 단장 levels bought; endless, each adds `RenovationSystem.priceBonusPerLevel` to every sale.
    public var renovationLevel: Int = 0

    /// 레시피 강화 level per menu index (0...`RecipeSystem.maxLevel`); each adds 10% to that dish's price.
    public var recipeLevels: [Int] = [0, 0, 0]

    private enum CodingKeys: String, CodingKey {
        case coins, menuTier, staffTier, stallTier, locationTier, pendingCoins
        case tier1Count, tier2Count, tier3Count
        case cashierCount, menuCooks
        case menuCookEnergy, cashierEnergy, cashierTier
        case menuCookResting, cashierResting
        case tier1IdleEnergies, tier2IdleEnergies, tier3IdleEnergies
        case warehouse, warehouseCapacity, menuStock
        case farmerCount, farmerIdleEnergies
        case veteranAlbaCount, veteranAlbaIdleEnergies
        case renovationLevel, recipeLevels
        case menuCookLevels, cashierLevel
        case tier1IdleLevels, tier2IdleLevels, tier3IdleLevels, farmerIdleLevels, veteranAlbaIdleLevels
    }

    /// Every key is optional so older saves (which predate `locationTier`) keep loading.
    public init(from decoder: Decoder) throws {
        let d = StallState()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coins = c.decodeOrDefault(.coins, d.coins)
        menuTier = c.decodeOrDefault(.menuTier, d.menuTier)
        staffTier = c.decodeOrDefault(.staffTier, d.staffTier)
        stallTier = c.decodeOrDefault(.stallTier, d.stallTier)
        let rawLocation: Int = c.decodeOrDefault(.locationTier, 0)
        locationTier = min(max(rawLocation, 0), UpgradeDefinitions.location.count - 1)
        pendingCoins = c.decodeOrDefault(.pendingCoins, d.pendingCoins)
        tier1Count = c.decodeOrDefault(.tier1Count, d.tier1Count)
        tier2Count = c.decodeOrDefault(.tier2Count, d.tier2Count)
        tier3Count = c.decodeOrDefault(.tier3Count, d.tier3Count)
        cashierCount = c.decodeOrDefault(.cashierCount, d.cashierCount)
        menuCooks = c.decodeOrDefault(.menuCooks, d.menuCooks)
        menuCookEnergy = c.decodeOrDefault(.menuCookEnergy, d.menuCookEnergy)
        cashierEnergy = c.decodeOrDefault(.cashierEnergy, d.cashierEnergy)
        cashierTier = c.decodeOrDefault(.cashierTier, d.cashierTier)
        menuCookResting = c.decodeOrDefault(.menuCookResting, d.menuCookResting)
        cashierResting = c.decodeOrDefault(.cashierResting, d.cashierResting)
        tier1IdleEnergies = c.decodeOrDefault(.tier1IdleEnergies, d.tier1IdleEnergies)
        tier2IdleEnergies = c.decodeOrDefault(.tier2IdleEnergies, d.tier2IdleEnergies)
        tier3IdleEnergies = c.decodeOrDefault(.tier3IdleEnergies, d.tier3IdleEnergies)
        warehouse = c.decodeOrDefault(.warehouse, d.warehouse)
        // A save with no capacity predates the 15-slot start.
        warehouseCapacity = c.decodeOrDefault(.warehouseCapacity, WarehouseSystem.legacyBaseCapacity)
        menuStock = c.decodeOrDefault(.menuStock, [0, 0, 0])
        farmerCount = c.decodeOrDefault(.farmerCount, d.farmerCount)
        farmerIdleEnergies = c.decodeOrDefault(.farmerIdleEnergies, d.farmerIdleEnergies)
        veteranAlbaCount = c.decodeOrDefault(.veteranAlbaCount, d.veteranAlbaCount)
        veteranAlbaIdleEnergies = c.decodeOrDefault(.veteranAlbaIdleEnergies, d.veteranAlbaIdleEnergies)
        renovationLevel = max(0, c.decodeOrDefault(.renovationLevel, d.renovationLevel))
        recipeLevels = c.decodeOrDefault(.recipeLevels, d.recipeLevels)

        menuCookLevels = c.decodeOrDefault(.menuCookLevels, d.menuCookLevels)
        cashierLevel = c.decodeOrDefault(.cashierLevel, d.cashierLevel)
        tier1IdleLevels = c.decodeOrDefault(.tier1IdleLevels, [])
        tier2IdleLevels = c.decodeOrDefault(.tier2IdleLevels, [])
        tier3IdleLevels = c.decodeOrDefault(.tier3IdleLevels, [])
        farmerIdleLevels = c.decodeOrDefault(.farmerIdleLevels, [])
        veteranAlbaIdleLevels = c.decodeOrDefault(.veteranAlbaIdleLevels, [])

        // GameStore indexes these three by menu index; a wrong length would trap there.
        let menuCount = UpgradeDefinitions.menu.count
        menuCooks      = Self.resized(menuCooks, to: menuCount, padding: 0)
        menuCookEnergy = Self.resized(menuCookEnergy, to: menuCount, padding: 1.0)
        menuCookResting = Self.resized(menuCookResting, to: menuCount, padding: false)
        menuStock      = Self.resized(menuStock, to: menuCount, padding: 0)
        recipeLevels   = Self.resized(recipeLevels, to: menuCount, padding: 0)
            .map { min(max($0, 0), RecipeSystem.maxLevel) }

        // An old save has no levels: every worker is Lv.1. A level pool is not resized to its energy
        // pool here (a damaged key must not change another); `GameStore` pads it on every use.
        let clamp = StaffLevelSystem.clamped
        menuCookLevels = Self.resized(menuCookLevels, to: menuCount, padding: 1).map(clamp)
        cashierLevel = clamp(cashierLevel)
        tier1IdleLevels = tier1IdleLevels.map(clamp)
        tier2IdleLevels = tier2IdleLevels.map(clamp)
        tier3IdleLevels = tier3IdleLevels.map(clamp)
        farmerIdleLevels = farmerIdleLevels.map(clamp)
        veteranAlbaIdleLevels = veteranAlbaIdleLevels.map(clamp)
    }

    private static func resized<T>(_ array: [T], to count: Int, padding: T) -> [T] {
        array.count >= count
            ? Array(array.prefix(count))
            : array + Array(repeating: padding, count: count - array.count)
    }

    /// Portions of the first dish a new game opens with, so minute one has something to sell.
    static let startingStock = 5

    public init() {
        // Start with one 알바생 assigned to farm — auto-harvests and is more useful than slow cooking for newbies
        tier1Count = 1
        menuStock = [Self.startingStock, 0, 0]
    }
}
