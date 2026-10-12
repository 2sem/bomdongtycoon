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

    /// Price for a specific menu slot (겉절이=30, 봄동김치=75, 봄동비빔밥=180) times the location multiplier
    public static func pricePerItem(for stall: StallState, menuIndex: Int) -> Double {
        let menuMultiplier = menuIndex < UpgradeDefinitions.menu.count
            ? UpgradeDefinitions.menu[menuIndex].priceMultiplier
            : 1.0
        return basePricePerItem * menuMultiplier * locationMultiplier(for: stall)
    }

    /// Maximum stock the stall can hold at once
    public static func maxStock(for stall: StallState) -> Int {
        UpgradeDefinitions.stall[stall.stallTier].maxStock
    }

    /// Coins per second summed across all assigned menu slots.
    /// Each slot uses its cook's actual tier (production rate) and its own menu price.
    public static func coinsPerSecond(for stall: StallState) -> Double {
        var total = 0.0
        for i in 0...stall.menuTier {
            let cookTier = i < stall.menuCooks.count ? stall.menuCooks[i] : 0
            guard cookTier > 0, cookTier <= UpgradeDefinitions.staff.count else { continue }
            let rate  = baseProductionRate * UpgradeDefinitions.staff[cookTier - 1].productionMultiplier
            let price = pricePerItem(for: stall, menuIndex: i)
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
        guard let next = nextLocation(for: stall) else {
            return goal == nil ? "🎉 강남에서 봄동 제국을 완성했어요!" : nil
        }
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

    // MARK: Goal selection

    private struct Goal {
        let type: UpgradeType
        let definition: UpgradeDefinition
    }

    private static func nextGoal(for stall: StallState) -> Goal? {
        candidates(for: stall).min(by: { $0.definition.coinCost < $1.definition.coinCost })
    }

    private static func candidates(for stall: StallState) -> [Goal] {
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
        return result
    }
}
