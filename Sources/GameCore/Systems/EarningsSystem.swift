import Foundation

public enum EarningsSystem {

    static let baseProductionRate: Double = 1.0   // items per second
    static let basePricePerItem: Double = 30.0    // coins per item sold

    /// Items produced per second based on staff and location upgrades
    public static func productionRate(for stall: StallState) -> Double {
        var rate = baseProductionRate
        if stall.staffTier > 0 {
            rate *= UpgradeDefinitions.staff[stall.staffTier - 1].productionMultiplier
        }
        return rate
    }

    /// Coins earned per item sold based on menu and location upgrades
    public static func pricePerItem(for stall: StallState) -> Double {
        pricePerItem(for: stall, menuIndex: stall.menuTier)
    }

    /// Sale-price multiplier of the stall's location (x1 / x2 / x4). Applied only in
    /// `pricePerItem(for:menuIndex:)`; live sales, `coinsPerSecond` and offline
    /// earnings all price through it, so it must not be applied again downstream.
    public static func locationMultiplier(for stall: StallState) -> Double {
        let tier = min(max(stall.locationTier, 0), UpgradeDefinitions.location.count - 1)
        return UpgradeDefinitions.location[tier].saleMultiplier
    }

    /// Design intent: a cashier at the counter is a real job, not a figure. Every sale
    /// earns more while they work, and a sleeping one earns the base price until she is back to full energy.
    static let cashierSaleBonus: Double = 1.25
    /// The veteran alba (tier 5) keeps her older x1.4; it replaces the bonus, never stacks.
    static let veteranCashierSaleBonus: Double = 1.4
    static let veteranCashierTier = 5

    /// Revenue multiplier of the hired cashier. 1.0 with no cashier or a sleeping one.
    public static func cashierSaleMultiplier(for stall: StallState) -> Double {
        guard stall.cashierCount > 0,
              !stall.cashierResting else { return 1.0 }
        return stall.cashierTier == veteranCashierTier ? veteranCashierSaleBonus : cashierSaleBonus
    }

    /// The bonus a cashier of `tier` brings when rested, in whole percent (for copy).
    public static func cashierSaleBonusPercent(tier: Int) -> Int {
        let m = tier == veteranCashierTier ? veteranCashierSaleBonus : cashierSaleBonus
        return Int(((m - 1) * 100).rounded())
    }

    /// What a sale actually pays: the one place every revenue multiplier composes
    /// (menu x location x renovation x cashier x legacy). Costs are never scaled.
    /// Offline earnings use `progress.earningRate`, an EMA of these sale prices, so the
    /// cashier and legacy bonuses are already inside the rate and must not be applied again there.
    /// `prestigeCount` 0 multiplies by exactly 1.0, so a first-run player's prices are untouched.
    /// Required, not defaulted: a caller that forgot it would silently price a prestiged save at x1.
    /// `feverMultiplier`, `boostMultiplier`, `gourmetMultiplier` and `weatherMultiplier` are active-play bonuses: only `sellItem` passes
    /// them, so `coinsPerSecond`, the golden bonus and offline earnings stay on the base economy.
    public static func salePrice(for stall: StallState, menuIndex: Int, prestigeCount: Int,
                                 feverMultiplier: Double = 1, gourmetMultiplier: Double = 1,
                                 boostMultiplier: Double = 1, weatherMultiplier: Double = 1) -> Double {
        pricePerItem(for: stall, menuIndex: menuIndex)
            * cashierSaleMultiplier(for: stall)
            * PrestigeSystem.legacyMultiplier(prestigeCount: prestigeCount)
            * feverMultiplier
            * boostMultiplier
            * gourmetMultiplier
            * weatherMultiplier
    }

    public static let gourmetMultiplier: Double = 3

    /// Price for a specific menu slot (겉절이=30, 봄동김치=75, 봄동비빔밥=180) times the recipe level,
    /// location and renovation multipliers
    public static func pricePerItem(for stall: StallState, menuIndex: Int) -> Double {
        let menuMultiplier = menuIndex < UpgradeDefinitions.menu.count
            ? UpgradeDefinitions.menu[menuIndex].priceMultiplier
            : 1.0
        return basePricePerItem * menuMultiplier * locationMultiplier(for: stall)
            * RenovationSystem.priceMultiplier(level: stall.renovationLevel)
            * RecipeSystem.priceMultiplier(level: RecipeSystem.level(for: stall, menuIndex: menuIndex))
    }

    /// Dishes a customer may order: unlocked and either in stock or with a cook assigned. When no dish
    /// qualifies (a fresh shop), any unlocked dish, so a customer always has something to ask for.
    public static func orderableMenus(for stall: StallState) -> [Int] {
        let unlocked = Array(0...max(0, min(stall.menuTier, UpgradeDefinitions.menu.count - 1)))
        let ready = unlocked.filter { i in
            (i < stall.menuStock.count && stall.menuStock[i] > 0)
                || (i < stall.menuCooks.count && stall.menuCooks[i] > 0)
        }
        return ready.isEmpty ? unlocked : ready
    }

    /// Maximum stock the stall can hold at once
    public static func maxStock(for stall: StallState) -> Int {
        UpgradeDefinitions.stall[stall.stallTier].maxStock
    }

    /// Coins per second summed across all assigned menu slots.
    /// Each slot uses its cook's actual tier (production rate) and its own menu price.
    public static func coinsPerSecond(for stall: StallState, prestigeCount: Int) -> Double {
        var total = 0.0
        for i in 0...stall.menuTier {
            let cookTier = i < stall.menuCooks.count ? stall.menuCooks[i] : 0
            guard cookTier > 0, cookTier <= UpgradeDefinitions.staff.count else { continue }
            let rate  = baseProductionRate * UpgradeDefinitions.staff[cookTier - 1].productionMultiplier
            let price = salePrice(for: stall, menuIndex: i, prestigeCount: prestigeCount)
            total += rate * price
        }
        return total
    }

    /// Returns the cheapest upgrade the player can currently afford
    public static func nextAffordableUpgrade(for stall: StallState) -> UpgradeDefinition? {
        candidates(for: stall)
            .filter { $0.definition.coinCost <= stall.coins }
            .min(by: { $0.definition.coinCost < $1.definition.coinCost })?
            .definition
    }

    /// Returns the next upgrade the player is saving toward (cheapest overall)
    public static func nextGoalUpgrade(for stall: StallState) -> UpgradeDefinition? {
        nextGoal(for: stall)?.definition
    }

    /// Which kind of purchase `nextGoalUpgrade` refers to; `.location` for a relocation goal.
    public static func nextGoalType(for stall: StallState) -> UpgradeType? {
        nextGoal(for: stall)?.type
    }

    /// What the goal capsule should call the next goal; `.upgrade` is the generic label.
    /// Location goals are handled separately by `locationGoalText`.
    public static func nextGoalLabel(for stall: StallState) -> GoalLabel? {
        switch nextGoalType(for: stall) {
        case .staff: .hire
        case .warehouse: .warehouse
        case .renovation: .renovation
        case .recipe: .recipe
        case nil: nil
        default: .upgrade
        }
    }

    /// Nothing but the endless sinks (recipe levels, renovation) left to buy: the point where the
    /// goal capsule becomes the new-spring entry, since those never outrank it.
    public static func isOnlyRenovationLeft(for stall: StallState) -> Bool {
        structuralCandidates(for: stall).isEmpty
    }

    // MARK: Location goal

    /// The location after the current one, if any.
    public static func nextLocation(for stall: StallState) -> LocationDefinition? {
        let next = stall.locationTier + 1
        return next < UpgradeDefinitions.location.count ? UpgradeDefinitions.location[next] : nil
    }

    /// True when the next location's stall prerequisite is met.
    public static func nextLocationUnlocked(for stall: StallState) -> Bool {
        guard let next = nextLocation(for: stall) else { return false }
        return stall.stallTier >= next.requiredStallTier
    }

    /// Goal-bar copy for the location goal; nil means "use the generic upgrade label".
    public static func locationGoalText(for stall: StallState) -> String? {
        let goal = nextGoal(for: stall)
        // At the final location there is no location goal; with nothing else left the capsule
        // becomes the new-spring entry (`GoalProgressBar`).
        guard let next = nextLocation(for: stall) else { return nil }
        guard nextLocationUnlocked(for: stall) else {
            guard goal == nil else { return nil }
            let stallName = UpgradeDefinitions.stall[next.requiredStallTier].name
            return "다음 목표: \(stallName)으로 \(next.name) 이전을 준비하세요"
        }
        guard goal?.type == .location else { return nil }
        if stall.coins >= next.coinCost {
            return "\(next.destination) 이전할 수 있어요! 탭해서 확인"
        }
        return "다음 목표까지 💰 \(CoinFormat.string(stall.coins)) / \(CoinFormat.string(next.coinCost)) · \(next.name) 이전"
    }

    /// Short variant of `locationGoalText` for narrow pills (375pt phones truncate the full phrase,
    /// and the amount and destination are the parts that matter). Nil when there is no shorter form.
    public static func locationGoalCompactText(for stall: StallState) -> String? {
        guard let next = nextLocation(for: stall) else { return nil }
        let goal = nextGoal(for: stall)
        guard nextLocationUnlocked(for: stall) else {
            guard goal == nil else { return nil }
            return "\(UpgradeDefinitions.stall[next.requiredStallTier].name) 필요 · \(next.name) 이전"
        }
        guard goal?.type == .location, stall.coins < next.coinCost else { return nil }
        return "💰 \(CoinFormat.string(stall.coins)) / \(CoinFormat.string(next.coinCost)) · \(next.name)"
    }

    // MARK: Goal selection

    private struct Goal {
        let type: UpgradeType
        let definition: UpgradeDefinition
    }

    private static func nextGoal(for stall: StallState) -> Goal? {
        // A tie goes to the warehouse: it is only offered when it is the real throttle.
        candidates(for: stall).min { a, b in
            if a.definition.coinCost != b.definition.coinCost { return a.definition.coinCost < b.definition.coinCost }
            return a.type == .warehouse && b.type != .warehouse
        }
    }

    /// Everything the player can ever save toward, cheapest first wins: the structural purchases plus
    /// the endless recipe levels and renovation, so there is always a next goal.
    private static func candidates(for stall: StallState) -> [Goal] {
        var result = structuralCandidates(for: stall)
        for menuIndex in 0..<UpgradeDefinitions.menu.count {
            guard let cost = RecipeSystem.nextCost(for: stall, menuIndex: menuIndex) else { continue }
            let level = RecipeSystem.level(for: stall, menuIndex: menuIndex)
            result.append(Goal(type: .recipe(menuIndex: menuIndex), definition: UpgradeDefinition(
                name: UpgradeDefinitions.menu[menuIndex].name, coinCost: cost,
                description: "레시피 \(level) → \(level + 1)")))
        }
        if let cost = RenovationSystem.nextCost(for: stall) {
            result.append(Goal(type: .renovation, definition: UpgradeDefinition(
                name: "가게 단장", coinCost: cost,
                description: "판매가 +\(RenovationSystem.percentPerLevel)%")))
        }
        return result
    }

    private static func structuralCandidates(for stall: StallState) -> [Goal] {
        var result: [Goal] = []
        // Hire tier = staffTier + 1; skipped while the stall is too low, so the
        // stall upgrade that unlocks it becomes the goal instead.
        if stall.staffTier < UpgradeDefinitions.staff.count,
           UpgradeDefinitions.isStaffTierUnlocked(stall.staffTier + 1, stallTier: stall.stallTier) {
            result.append(Goal(type: .staff, definition: UpgradeDefinitions.staff[stall.staffTier]))
        }
        if stall.menuTier + 1 < UpgradeDefinitions.menu.count {
            result.append(Goal(type: .menu, definition: UpgradeDefinitions.menu[stall.menuTier + 1]))
        }
        if stall.stallTier + 1 < UpgradeDefinitions.stall.count {
            result.append(Goal(type: .stall, definition: UpgradeDefinitions.stall[stall.stallTier + 1]))
        }
        // A location only becomes a goal once its stall prerequisite is met.
        if let next = nextLocation(for: stall), nextLocationUnlocked(for: stall) {
            result.append(Goal(type: .location, definition: UpgradeDefinition(
                name: next.name, coinCost: next.coinCost, description: next.description)))
        }
        // Warehouse: only a goal once it is the real throttle (>= 80% full) AND a menu cook is
        // assigned. Before a cook exists the cook is the bottleneck, so cheapest-first must not let
        // a 300-coin expansion displace a hire/menu/stall while there is still room.
        if WarehouseSystem.isThrottling(count: stall.warehouse, capacity: stall.warehouseCapacity),
           stall.menuCooks.contains(where: { $0 > 0 }),
           let next = WarehouseSystem.nextExpansion(current: stall.warehouseCapacity) {
            result.append(Goal(type: .warehouse, definition: UpgradeDefinition(
                name: "창고 확장", coinCost: next.cost,
                description: "창고 \(stall.warehouseCapacity)칸 → \(next.capacity)칸")))
        }
        return result
    }
}

public enum GoalLabel: Equatable {
    case hire, warehouse, upgrade, renovation, recipe
}
