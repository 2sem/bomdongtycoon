#if DEBUG
import SpriteKit
import GameCore

/// `-dotAutoplay`: an attentive player with no fingers. Drives the same handlers a tap would, at
/// most `tapsPerStep` taps per game second, and logs a `[DotQA]` line every 30 game seconds.
/// Priorities: fever, tip coins, ripe plots, tired workers, dishes running low, empty plots, then the
/// hurry taps (a cooking dish, then a growing plot's water); claims and purchases are free. The flyer is tapped whenever it is ready.
/// `-dotAutoplayIdle` skips every world tap and keeps only fever, claims and purchases. Seed it with `-dotSeed` to start mid-game, or run it on a fresh install.
struct AutoplayState {
    var clock: Double = 0
    var nextLog: Double = 0
    var seenServed = 0, seenStaff = 1, seenFevers = 0, seenTiers = 0, seenPayday = 0, seenLevelUps = 0
    var firstSaleLogged = false
    var lastStep: Double = 0
    var readyLoggedAt = -1
    var purchases = 0
    var lastPurchase: Double = 0
    var longestGap: Double = 0
    /// World taps by verb, and the budget left unspent because there was nothing to tap.
    var hurries = 0, waters = 0, wakes = 0, deadTaps = 0, flyers = 0
}

extension DotWorldScene {

    private static let stepSeconds = 1.0
    private static let tapsPerStep = 2
    private static let logEvery = 30.0

    func autoplay(delta: TimeInterval, store: GameStore) {
        guard DotDebug.wantsAutoplay, !store.isSimulationPaused, layout != nil else { return }
        autoplayState.clock += delta
        logEvents(store)
        if autoplayState.clock >= autoplayState.nextLog {
            logSnapshot(store)
            autoplayState.nextLog += Self.logEvery
        }
        guard autoplayState.clock >= autoplayState.lastStep + Self.stepSeconds else { return }
        autoplayState.lastStep = autoplayState.clock
        claim(store)
        takeAds(store)
        buyGoal(store)
        tapAround(store)
    }

    private func tapAround(_ store: GameStore) {
        var taps = Self.tapsPerStep
        if store.isFeverReady, !DotDebug.autoplaySkipsFever { store.startFever(); taps -= 1 }
        guard !DotDebug.autoplayIsIdle else { return }
        if taps > 0, store.requestFlyer() { autoplayState.flyers += 1; taps -= 1 }
        if let layout {
            for point in tipLayer?.points ?? [] where taps > 0 {
                if let tip = tipLayer?.collect(at: point) { collectTip(tip, store: store, layout: layout); taps -= 1 }
            }
        }
        for i in store.farm.plots.indices where taps > 0 && store.farm.plots[i].stage == .ready
            && store.stall.warehouse < store.stall.warehouseCapacity {
            handleFarmTap(.plot(i), store: store); taps -= 1
        }
        var sleepers: [GameStore.WorkerTarget] = (0..<3).map { .cook(menuIndex: $0) } + [.cashier]
        sleepers += store.farm.plots.indices.map { .farm(plotIndex: $0) }
        for target in sleepers where taps > 0 && store.isResting(target) && handleWake(target, store: store) {
            autoplayState.wakes += 1; taps -= 1
        }
        let low = store.isFeverActive ? EarningsSystem.maxStock(for: store.stall) : 3
        for menu in 0...min(store.stall.menuTier, 2) where taps > 0
            && store.stall.menuStock[menu] < low && store.stall.warehouse > 0
            && (!(store.stall.menuCooks[menu] > 0) || store.isResting(.cook(menuIndex: menu))) && !store.isManualCookRunning(menuIndex: menu) {
            handleDishTap(menu, store: store); taps -= 1
        }
        for i in store.farm.plots.indices where taps > 0 && store.farm.plots[i].stage == .empty
            && store.stall.coins >= FarmSystem.seedCost * 2 {
            handleFarmTap(.plot(i), store: store); taps -= 1
        }
        // A full warehouse with ripe plots waiting: cook a portion to make room, as the crate's notice says.
        if store.isWarehouseFull, taps > 0,
           let menu = (0...min(store.stall.menuTier, 2)).first(where: { store.stall.menuStock[$0] < EarningsSystem.maxStock(for: store.stall) }),
           store.farm.plots.contains(where: { $0.stage == .ready }) {
            handleDishTap(menu, store: store); taps -= 1
        }
        // The hurry taps: the emptiest cooking dish first (that is the one a customer is waiting on).
        let cooking = (0...min(store.stall.menuTier, 2)).filter { store.isCooking(menuIndex: $0) }
            .sorted { store.stall.menuStock[$0] < store.stall.menuStock[$1] }
        for menu in cooking where taps > 0 {
            handleDishTap(menu, store: store); autoplayState.hurries += 1; taps -= 1
        }
        let growing = store.farm.plots.indices.filter { store.farm.plots[$0].stage == .sprout || store.farm.plots[$0].stage == .growing }
            .sorted { store.farm.plots[$0].growth > store.farm.plots[$1].growth }
        for i in growing where taps > 0 {
            handleFarmTap(.plot(i), store: store); autoplayState.waters += 1; taps -= 1
        }
        autoplayState.deadTaps += taps
    }

    private func claim(_ store: GameStore) {
        let multiplier = DotDebug.autoplayTakesAds ? 2.0 : 1.0
        for mission in store.missions where mission.isComplete && !mission.isClaimed {
            if let paid = store.claimMission(id: mission.id, multiplier: multiplier) {
                DotDebug.qa("event claim \(mission.kind.rawValue) +\(Int(paid)) t=\(timeText(store))")
            }
        }
        if let paid = store.claimDailyBonus(multiplier: multiplier) {
            DotDebug.qa("event claim daily_bonus +\(Int(paid)) t=\(timeText(store))")
        }
    }

    /// `-dotAutoplayAds`: says yes to every rewarded offer (the ad itself is skipped, as `-dotAdsGrant` does).
    private func takeAds(_ store: GameStore) {
        guard DotDebug.autoplayTakesAds else { return }
        if store.claimFeverAdCharge() { DotDebug.qa("event ad fever t=\(timeText(store))") }
        if store.claimBoost() { DotDebug.qa("event ad boost t=\(timeText(store))") }
        if let paid = store.claimGift() { DotDebug.qa("event ad gift +\(Int(paid)) t=\(timeText(store))") }
    }

    private func notePurchase(_ store: GameStore) {
        let now = autoplayState.clock
        autoplayState.longestGap = max(autoplayState.longestGap, now - autoplayState.lastPurchase)
        autoplayState.lastPurchase = now
        autoplayState.purchases += 1
    }

    /// Buys the current goal the moment it is affordable (never the new spring), then puts a new
    /// hire to work: a menu cook first, then the cashier.
    private func buyGoal(_ store: GameStore) {
        guard !store.isPrestigeAvailable || EarningsSystem.nextGoalType(for: store.stall) != nil,
              let type = EarningsSystem.nextGoalType(for: store.stall),
              let goal = EarningsSystem.nextGoalUpgrade(for: store.stall) else { return }
        let coins = store.stall.coins
        switch type {
        case .staff:
            // A hire must leave a day's payroll (with the new wage) in hand, or it would strike at once.
            let wage = WageSystem.wage(forTier: store.stall.staffTier + 1)
            guard coins >= goal.coinCost + store.dailyPayroll + wage else { return }
            store.hireWorker(tier: store.stall.staffTier + 1)
            notePurchase(store)
            DotDebug.qa("event hire t=\(timeText(store)) staff=\(store.stall.staffCount)")
        default:
            guard coins >= goal.coinCost else { return }
            store.purchaseUpgrade(type)
            notePurchase(store)
            DotDebug.qa("event buy \(type) cost=\(Int(goal.coinCost)) t=\(timeText(store))")
        }
        placeIdleStaff(store)
    }

    private func placeIdleStaff(_ store: GameStore) {
        for menu in 0...min(store.stall.menuTier, 2) where store.stall.menuCooks[menu] == 0 && store.availableWorkers > 0 {
            store.assignMenuCook(menuIndex: menu)
        }
        if store.stall.cashierCount == 0, store.availableWorkers > 0 { store.assignToCashier() }
    }

    private func logEvents(_ store: GameStore) {
        let p = store.progress
        if p.totalServed > 0, !autoplayState.firstSaleLogged {
            autoplayState.firstSaleLogged = true
            DotDebug.qa("event first_sale t=\(timeText(store))")
        }
        if p.totalFevers > autoplayState.seenFevers {
            autoplayState.seenFevers = p.totalFevers
            DotDebug.qa("event fever_start t=\(timeText(store)) n=\(p.totalFevers)")
        }
        if let payday = store.payday, payday.id != autoplayState.seenPayday {
            autoplayState.seenPayday = payday.id
            DotDebug.qa("event payday t=\(timeText(store)) paid=\(Int(payday.paid)) workers=\(payday.paidCount) strikes=\(payday.unpaidCount)")
        }
        if let ups = store.levelUps, ups.id != autoplayState.seenLevelUps {
            autoplayState.seenLevelUps = ups.id
            for up in ups.events {
                DotDebug.qa("event levelup t=\(timeText(store)) tier=\(up.tier) lv=\(up.level) wage=\(Int(up.wageBefore))->\(Int(up.wageAfter)) payroll=\(Int(store.dailyPayroll))")
            }
        }
        if store.isFeverReady, autoplayState.readyLoggedAt != p.totalFevers {
            autoplayState.readyLoggedAt = p.totalFevers
            DotDebug.qa("event fever_ready t=\(timeText(store))")
        }
    }

    private func logSnapshot(_ store: GameStore) {
        let p = store.progress
        let s = store.stall
        let lost = p.totalServed + p.totalFailed > 0
            ? String(format: "%.0f%%", Double(p.totalFailed) / Double(p.totalServed + p.totalFailed) * 100) : "-"
        DotDebug.qa(String(format: "t=%@ coins=%.0f earned=%.0f rating=%.2f served=%d failed=%d lost=%@ stall=%d menu=%d loc=%d staff=%d wh=%d/%d stock=%d plots=%d fevers=%d goldens=%d tips=%d buys=%d gap=%.0f recipes=%@ reno=%d boost=%d hurry=%d water=%d wake=%d dead=%d flyer=%d",
                           timeText(store), s.coins, p.totalEarned, p.rating, p.totalServed, p.totalFailed, lost, s.stallTier, s.menuTier,
                           s.locationTier, s.staffCount + s.farmerCount + s.veteranAlbaCount, s.warehouse, s.warehouseCapacity,
                           s.menuStock.reduce(0, +), store.farm.plots.count, p.totalFevers,
                           p.totalGoldenHarvested, p.totalTipsCollected, autoplayState.purchases,
                           max(autoplayState.longestGap, autoplayState.clock - autoplayState.lastPurchase),
                           s.recipeLevels.map(String.init).joined(separator: "/"), s.renovationLevel,
                           store.isBoostActive ? 1 : 0, autoplayState.hurries, autoplayState.waters,
                           autoplayState.wakes, autoplayState.deadTaps, autoplayState.flyers))
    }

    private func timeText(_ store: GameStore) -> String {
        let t = Int(store.progress.totalPlaySeconds)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
#else
import Foundation
import GameCore

extension DotWorldScene {
    func autoplay(delta: TimeInterval, store: GameStore) {}
}
#endif
