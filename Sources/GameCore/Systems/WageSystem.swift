import Foundation

/// Every employed worker is paid once per game day: one `DayCycle` loop, day and night together.
///
/// Play time only. `progress.totalPlaySeconds` is what defines a day and it does not advance
/// while the app is inactive or the simulation is paused, so a closed app owes nothing and
/// offline earnings stay untouched.
///
/// Tiers are the hire list's: 1 알바생, 2 이모님, 3 봄동 요리사, 4 농부, 5 고참 알바.
public enum WageSystem {

    /// Coins per worker per day. Sized against what the worker adds in a day at the stage she is
    /// normally hired, about 10-15% of it, so a worker on a useful post pays for herself many times
    /// over while a bench worker is a visible cost:
    /// - 알바생: hired at 300 coins by a shop making ~400+/day; one farming or cooking feeds ~25-30 dishes. 50.
    /// - 고참 알바: ~800 coins; a counter bonus of x1.4 on ~1,000/day of sales. 80.
    /// - 농부: ~2,000 coins; twice an alba's growth on one plot. 120.
    /// - 이모님: ~3,000 coins; 0.28 dishes/s of 75-coin 봄동김치, ~2,000/day. 250.
    /// - 봄동 요리사: ~15,000 coins; 0.49 dishes/s of 180-coin 비빔밥 at market prices, ~8,000+/day. 1,000.
    public static let dailyWages: [Int: Double] = [1: 50, 2: 250, 3: 1_000, 4: 120, 5: 80]

    /// A Lv.1 worker's wage: what the hire list shows.
    public static func wage(forTier tier: Int) -> Double { dailyWages[tier] ?? 0 }

    /// A worker's wage at her level: the tier's base times `StaffLevelSystem.wageMultiplier`, in whole coins.
    public static func wage(forTier tier: Int, level: Int) -> Double {
        (wage(forTier: tier) * StaffLevelSystem.wageMultiplier(level: level)).rounded()
    }

    /// Everything the stall owes at the next payday: every worker on a post or on the bench, at her level.
    public static func payroll(stall: StallState, farm: FarmState) -> Double {
        slots(stall: stall, farm: farm).reduce(0) { total, slot in
            let (tier, level) = tierAndLevel(of: slot, stall: stall, farm: farm)
            return total + wage(forTier: tier, level: level)
        }
    }

    public static func headcount(stall: StallState) -> Int {
        stall.staffCount + stall.farmerCount + stall.veteranAlbaCount
    }

    public struct Settlement: Equatable {
        public var paid: Double = 0
        public var paidCount = 0
        public var unpaidCount = 0
    }

    private enum Slot {
        case cook(Int), cashier, farm(Int), bench(tier: Int, index: Int)
    }

    /// Pay order: cooks by dish, the cashier, farm hands by plot, then the bench cheapest tier first.
    /// A worker whose wage the remaining coins cannot cover is skipped (the next, cheaper one may
    /// still be paid) and goes on strike: energy 0 and asleep, the existing rest, so she is back
    /// after a full rest. Coins never go below 0 and nothing is owed afterwards.
    @discardableResult
    public static func settle(stall: inout StallState, farm: inout FarmState) -> Settlement {
        var result = Settlement()
        for slot in slots(stall: stall, farm: farm) {
            let (tier, level) = tierAndLevel(of: slot, stall: stall, farm: farm)
            let wage = wage(forTier: tier, level: level)
            if stall.coins >= wage {
                stall.coins -= wage
                result.paid += wage
                result.paidCount += 1
            } else {
                strike(slot, stall: &stall, farm: &farm)
                result.unpaidCount += 1
            }
        }
        return result
    }

    private static func slots(stall: StallState, farm: FarmState) -> [Slot] {
        var posted: [Int: Int] = [:]
        var slots: [Slot] = []
        for i in stall.menuCooks.indices where stall.menuCooks[i] > 0 {
            slots.append(.cook(i)); posted[stall.menuCooks[i], default: 0] += 1
        }
        if stall.cashierCount > 0 {
            slots.append(.cashier); posted[stall.cashierTier, default: 0] += 1
        }
        for i in farm.plots.indices where farm.plots[i].hasWorker {
            slots.append(.farm(i)); posted[farmTier(farm.plots[i].workerType), default: 0] += 1
        }
        for tier in [1, 5, 4, 2, 3] {
            let benched = max(0, count(tier: tier, stall: stall) - posted[tier, default: 0])
            for index in 0..<benched { slots.append(.bench(tier: tier, index: index)) }
        }

        return slots
    }

    private static func farmTier(_ type: FarmWorkerType) -> Int {
        switch type {
        case .alba: 1
        case .farmer: 4
        case .veteranAlba: 5
        case .none: 0
        }
    }

    private static func count(tier: Int, stall: StallState) -> Int {
        switch tier {
        case 1: stall.tier1Count
        case 2: stall.tier2Count
        case 3: stall.tier3Count
        case 4: stall.farmerCount
        case 5: stall.veteranAlbaCount
        default: 0
        }
    }

    private static func tierAndLevel(of slot: Slot, stall: StallState, farm: FarmState) -> (tier: Int, level: Int) {
        switch slot {
        case .cook(let i): (stall.menuCooks[i], stall.menuCookLevels[safe: i] ?? 1)
        case .cashier: (stall.cashierTier, stall.cashierLevel)
        case .farm(let i): (farmTier(farm.plots[i].workerType), farm.plots[i].workerLevel)
        case .bench(let tier, let index): (tier, StaffLevelSystem.benchLevel(tier: tier, index: index, stall: stall))
        }
    }

    private static func strike(_ slot: Slot, stall: inout StallState, farm: inout FarmState) {
        switch slot {
        case .cook(let i):
            stall.menuCookEnergy[i] = 0; stall.menuCookResting[i] = true
        case .cashier:
            stall.cashierEnergy = 0; stall.cashierResting = true
        case .farm(let i):
            farm.plots[i].workerEnergy = 0; farm.plots[i].workerResting = true
        case .bench(let tier, let index):
            switch tier {
            case 1: zero(&stall.tier1IdleEnergies, index)
            case 2: zero(&stall.tier2IdleEnergies, index)
            case 3: zero(&stall.tier3IdleEnergies, index)
            case 4: zero(&stall.farmerIdleEnergies, index)
            default: zero(&stall.veteranAlbaIdleEnergies, index)
            }
        }
    }

    private static func zero(_ pool: inout [Double], _ index: Int) {
        if pool.indices.contains(index) { pool[index] = 0 }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Per-worker levels. Every worker is hired at Lv.1; a level is bought one step at a time with coins,
/// makes her faster and raises her daily wage, and the wage rises faster than the speed so a high
/// level on a post that earns little is a real choice.
///
/// Speed (x1.00, 1.15, 1.30, 1.45, 1.60) multiplies, per post:
/// - a cook's dish rate;
/// - a farm hand's crop growth on her plot (harvest and replant follow the crop, so that is her pace);
/// - a cashier's sale bonus, which scales her bonus (the counter has no speed to scale): alba at Lv.5
///   adds 40% instead of 25%.
/// Wage (x1.00, 1.25, 1.50, 1.75, 2.00) multiplies the tier's `WageSystem` base.
public enum StaffLevelSystem {
    public static let maxLevel = 5
    public static let speedPerLevel = 0.15
    public static let wagePerLevel = 0.25

    /// Cost of Lv.N to Lv.N+1 as a share of the type's hire price, N = 1...4: 0.5x, 1x, 2x, 4x.
    /// Rising so the last step is the dear one, and scaled from the hire price so 봄동 요리사
    /// levels cost what a 봄동 요리사 is worth. Climbing to Lv.5 costs 7.5x the hire price in all.
    public static let costShares: [Double] = [0.5, 1, 2, 4]

    public static func clamped(_ level: Int) -> Int { min(max(level, 1), maxLevel) }

    public static func speedMultiplier(level: Int) -> Double {
        1 + speedPerLevel * Double(clamped(level) - 1)
    }

    public static func wageMultiplier(level: Int) -> Double {
        1 + wagePerLevel * Double(clamped(level) - 1)
    }

    /// What a worker of `tier` costs to hire, the base the level costs scale from.
    public static func hirePrice(tier: Int) -> Double {
        switch tier {
        case 1...3: UpgradeDefinitions.staff[tier - 1].coinCost
        case 4: UpgradeDefinitions.farmer[0].coinCost
        default: UpgradeDefinitions.veteranAlba[0].coinCost
        }
    }

    /// nil at max level.
    public static func cost(tier: Int, fromLevel level: Int) -> Double? {
        guard level >= 1, level < maxLevel else { return nil }
        return (hirePrice(tier: tier) * costShares[level - 1]).rounded()
    }

    /// Everything the sheet shows before the player pays.
    public struct Step: Equatable {
        public let fromLevel: Int
        public let toLevel: Int
        public let cost: Double
        /// Whole percent faster than she is now, e.g. Lv.1 to Lv.2 is +15%.
        public let speedGainPercent: Int
        public let wageBefore: Double
        public let wageAfter: Double
    }

    public static func step(tier: Int, fromLevel level: Int) -> Step? {
        guard let cost = cost(tier: tier, fromLevel: level) else { return nil }
        let gain = speedMultiplier(level: level + 1) / speedMultiplier(level: level) - 1
        return Step(fromLevel: level, toLevel: level + 1, cost: cost,
                    speedGainPercent: Int((gain * 100).rounded()),
                    wageBefore: WageSystem.wage(forTier: tier, level: level),
                    wageAfter: WageSystem.wage(forTier: tier, level: level + 1))
    }

    static func benchLevel(tier: Int, index: Int, stall: StallState) -> Int {
        let pool: [Int]
        switch tier {
        case 1: pool = stall.tier1IdleLevels
        case 2: pool = stall.tier2IdleLevels
        case 3: pool = stall.tier3IdleLevels
        case 4: pool = stall.farmerIdleLevels
        default: pool = stall.veteranAlbaIdleLevels
        }
        return pool[safe: index] ?? 1
    }
}
