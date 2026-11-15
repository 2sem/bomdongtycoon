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

    public static func wage(forTier tier: Int) -> Double { dailyWages[tier] ?? 0 }

    /// Everything the stall owes at the next payday: every worker on a post or on the bench.
    public static func payroll(stall: StallState) -> Double {
        Double(stall.tier1Count) * wage(forTier: 1)
            + Double(stall.tier2Count) * wage(forTier: 2)
            + Double(stall.tier3Count) * wage(forTier: 3)
            + Double(stall.farmerCount) * wage(forTier: 4)
            + Double(stall.veteranAlbaCount) * wage(forTier: 5)
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

        var result = Settlement()
        for slot in slots {
            let tier = tier(of: slot, stall: stall, farm: farm)
            let wage = wage(forTier: tier)
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

    private static func tier(of slot: Slot, stall: StallState, farm: FarmState) -> Int {
        switch slot {
        case .cook(let i): stall.menuCooks[i]
        case .cashier: stall.cashierTier
        case .farm(let i): farmTier(farm.plots[i].workerType)
        case .bench(let tier, _): tier
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
