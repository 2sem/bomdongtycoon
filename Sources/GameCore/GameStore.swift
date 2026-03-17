import Foundation
import Combine

public enum UpgradeType {
    case staff, menu, stall, location, farm
}

@MainActor
public final class GameStore: ObservableObject {

    @Published public var stall: StallState
    @Published public var farm: FarmState
    @Published public var progress: PlayerProgress
    @Published public var season: SeasonState
    @Published public var offlineEarnings: Double = 0

    private enum DefaultsKey {
        static let stall    = "gameStore.stall"
        static let farm     = "gameStore.farm"
        static let progress = "gameStore.progress"
    }

    private let defaults: UserDefaults
    private var cookAccumulators: [Double] = [0, 0, 0]   // per-menu
    private var cashierAccumulator: Double = 0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: DefaultsKey.stall),
           let saved = try? JSONDecoder().decode(StallState.self, from: data) {
            self.stall = saved
        } else {
            self.stall = StallState()
        }

        if let data = defaults.data(forKey: DefaultsKey.farm),
           let saved = try? JSONDecoder().decode(FarmState.self, from: data) {
            self.farm = saved
        } else {
            self.farm = FarmState()
        }

        var loadedProgress: PlayerProgress
        if let data = defaults.data(forKey: DefaultsKey.progress),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            loadedProgress = saved
        } else {
            loadedProgress = PlayerProgress()
        }
        if loadedProgress.seasonStartDate == nil {
            loadedProgress.seasonStartDate = Date()
        }
        self.progress = loadedProgress
        self.season   = SeasonSystem.currentState(seasonStart: loadedProgress.seasonStartDate!)

        // Migration from old save format
        migrate()
    }

    private func migrate() {
        // Old save had staffCount (stored) — distribute into tierXCount
        // Detect by checking if all tier counts are 0 but staffTier > 0
        if stall.tier1Count == 0 && stall.tier2Count == 0 && stall.tier3Count == 0 && stall.staffTier > 0 {
            // We lost staffCount from old format; best estimate: staffTier workers hired
            switch stall.staffTier {
            case 1: stall.tier1Count = 1
            case 2: stall.tier1Count = 1; stall.tier2Count = 1
            case 3: stall.tier1Count = 1; stall.tier2Count = 1; stall.tier3Count = 1
            default: break
            }
        }
        // Old shopWorkers → cashierCount
        if stall.cashierCount == 0 && stall.shopWorkers == 0 && stall.staffCount > 0 {
            let farmAssigned = farm.plots.filter { $0.hasWorker }.count
            stall.cashierCount = max(0, stall.staffCount - farmAssigned)
        }

        // menuCooks migration: old format stored count (could be > 3); new format stores tier (0-3).
        if stall.menuCooks.contains(where: { $0 > 3 }) {
            for i in 0..<stall.menuCooks.count {
                stall.menuCooks[i] = stall.menuCooks[i] > 0 ? max(1, min(stall.staffTier, 3)) : 0
            }
        }
    }

    // MARK: - Tick

    public func tick(deltaTime: Double) {
        let seasonMult = SeasonSystem.earningsMultiplier(for: season.currentSeason)
        let growRate   = FarmSystem.growthRate(for: farm) * seasonMult
        let activePlots = FarmSystem.activePlotCount(for: farm)

        // Grow planted plots
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].isPlanted, !farm.plots[i].isReady else { continue }
            farm.plots[i].growth = min(farm.plots[i].growth + growRate * deltaTime, 1.0)
        }

        // Farm workers (tier1 only) auto-harvest and replant
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].hasWorker else { continue }
            if farm.plots[i].isReady {
                guard stall.warehouse < stall.warehouseCapacity else { continue }
                stall.warehouse += FarmSystem.harvestYield
                farm.plots[i].growth   = 0
                farm.plots[i].isPlanted = false
            }
            if !farm.plots[i].isPlanted, stall.coins >= FarmSystem.seedCost {
                stall.coins -= FarmSystem.seedCost
                farm.plots[i].isPlanted = true
            }
        }

        // Per-menu auto-cook: dedicated cook produces at tier-based speed
        let maxStock = EarningsSystem.maxStock(for: stall)
        for i in 0..<stall.menuCooks.count {
            let tier = stall.menuCooks[i]
            guard tier > 0, stall.warehouse > 0, i <= stall.menuTier else { continue }
            guard i < stall.menuStock.count, stall.menuStock[i] < maxStock else { continue }
            cookAccumulators[i] += cookRate(forTier: tier) * deltaTime
            while cookAccumulators[i] >= 1.0,
                  stall.warehouse > 0,
                  stall.menuStock[i] < maxStock {
                cookAccumulators[i] -= 1.0
                stall.warehouse    -= 1
                stall.menuStock[i] += 1
            }
        }

        // Cashier auto-collect pendingCoins
        if stall.cashierCount > 0, stall.pendingCoins > 0 {
            cashierAccumulator += deltaTime
            if cashierAccumulator >= 1.0 {
                cashierAccumulator = 0
                collectCoins()
            }
        }
    }

    // MARK: - Collect

    public func collectCoins() {
        stall.coins += stall.pendingCoins
        progress.totalEarned += stall.pendingCoins
        stall.pendingCoins = 0
        save()
    }

    // MARK: - Sell

    public func sellItem(menuIndex: Int) -> Double? {
        guard menuIndex < stall.menuStock.count,
              stall.menuStock[menuIndex] > 0 else { return nil }
        stall.menuStock[menuIndex] -= 1
        let price = EarningsSystem.pricePerItem(for: stall)
        stall.pendingCoins += price
        return price
    }

    // MARK: - Farm

    public func plantSeed(plotIndex: Int) {
        guard plotIndex < farm.plots.count,
              !farm.plots[plotIndex].isPlanted,
              stall.coins >= FarmSystem.seedCost else { return }
        stall.coins -= FarmSystem.seedCost
        farm.plots[plotIndex].isPlanted = true
        farm.plots[plotIndex].growth    = 0
        save()
    }

    public func harvest(plotIndex: Int) {
        guard plotIndex < farm.plots.count,
              farm.plots[plotIndex].isReady,
              stall.warehouse < stall.warehouseCapacity else { return }
        stall.warehouse += FarmSystem.harvestYield
        farm.plots[plotIndex].growth    = 0
        farm.plots[plotIndex].isPlanted = false
        save()
    }

    // MARK: - Warehouse

    public func expandWarehouse() {
        guard let cost = WarehouseSystem.costForNextExpansion(current: stall.warehouseCapacity),
              stall.coins >= cost else { return }
        stall.coins -= cost
        stall.warehouseCapacity += WarehouseSystem.expansionStep
        save()
    }

    // MARK: - Manual cook

    /// Auto-cook accumulators exposed for progress bar display (0.0–1.0 each).
    public var cookProgress: [Double] { cookAccumulators }

    /// Manually cook 1 item for the given menu (regardless of cook assignment).
    public func manualCook(menuIndex: Int) {
        let maxStock = EarningsSystem.maxStock(for: stall)
        guard menuIndex <= stall.menuTier,
              menuIndex < stall.menuStock.count,
              stall.warehouse > 0,
              stall.menuStock[menuIndex] < maxStock else { return }
        stall.warehouse    -= 1
        stall.menuStock[menuIndex] += 1
        save()
    }

    /// Cooks 1 item for each menu that has no dedicated cook assigned.
    public func batchCook() {
        guard stall.warehouse > 0 else { return }
        let maxStock = EarningsSystem.maxStock(for: stall)
        var changed = false
        for i in 0...stall.menuTier {
            guard stall.menuCooks[i] == 0,          // skip auto-cook menus
                  i < stall.menuStock.count,
                  stall.warehouse > 0,
                  stall.menuStock[i] < maxStock else { continue }
            stall.warehouse    -= 1
            stall.menuStock[i] += 1
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Cook rate

    /// Items per second a cook of the given tier produces.
    private func cookRate(forTier tier: Int) -> Double {
        guard tier > 0, tier <= UpgradeDefinitions.staff.count else { return 0 }
        return 0.15 * UpgradeDefinitions.staff[tier - 1].productionMultiplier
        // tier1 (×2.0) → 0.30/s  ~3.3s per item
        // tier2 (×4.0) → 0.60/s  ~1.7s per item
        // tier3 (×7.0) → 1.05/s  ~1.0s per item
    }

    /// Human-readable cook speed label for the given tier.
    public static func cookSpeedLabel(forTier tier: Int) -> String {
        switch tier {
        case 1: return "3.3초/개"
        case 2: return "1.7초/개"
        case 3: return "1.0초/개"
        default: return ""
        }
    }

    // MARK: - Staff workers

    private var farmAssigned: Int { farm.plots.filter { $0.hasWorker }.count }

    /// Workers not yet placed anywhere
    public var availableWorkers: Int {
        stall.staffCount - farmAssigned - stall.cashierCount - stall.menuCooks.filter { $0 > 0 }.count
    }

    /// Only tier1 workers can be on farm
    public var availableForFarm: Int {
        stall.tier1Count - farmAssigned
    }

    public func toggleWorker(plotIndex: Int) {
        guard plotIndex < farm.plots.count else { return }
        if farm.plots[plotIndex].hasWorker {
            farm.plots[plotIndex].hasWorker = false
        } else {
            guard availableForFarm > 0 else { return }
            farm.plots[plotIndex].hasWorker = true
        }
        stall.farmWorkers = farmAssigned
        save()
    }

    public func assignToCashier() {
        guard availableWorkers > 0 else { return }
        stall.cashierCount += 1
        save()
    }

    public func removeFromCashier() {
        guard stall.cashierCount > 0 else { return }
        stall.cashierCount -= 1
        save()
    }

    public func assignMenuCook(menuIndex: Int) {
        guard menuIndex <= stall.menuTier,
              menuIndex < stall.menuCooks.count,
              stall.menuCooks[menuIndex] == 0,    // one cook per menu
              availableWorkers > 0 else { return }
        stall.menuCooks[menuIndex] = highestAvailableTier()
        save()
    }

    public func removeMenuCook(menuIndex: Int) {
        guard menuIndex < stall.menuCooks.count,
              stall.menuCooks[menuIndex] > 0 else { return }
        stall.menuCooks[menuIndex] = 0
        save()
    }

    private func highestAvailableTier() -> Int {
        for tier in [3, 2, 1] {
            let total: Int
            switch tier {
            case 1: total = stall.tier1Count
            case 2: total = stall.tier2Count
            case 3: total = stall.tier3Count
            default: continue
            }
            let used = stall.menuCooks.filter { $0 == tier }.count
            if total > used { return tier }
        }
        return 1
    }

    /// Legacy: kept so old call sites compile
    public func assignWorkerToShop() { assignToCashier() }
    public func removeWorkerFromShop() { removeFromCashier() }

    public func hireWorker() {
        guard stall.staffTier > 0 else { return }
        let idx  = stall.staffTier - 1
        let cost = UpgradeDefinitions.staff[idx].coinCost
        guard stall.coins >= cost else { return }
        stall.coins -= cost
        switch stall.staffTier {
        case 1: stall.tier1Count += 1
        case 2: stall.tier2Count += 1
        case 3: stall.tier3Count += 1
        default: break
        }
        save()
    }

    public func hireWorker(tier: Int) {
        guard tier >= 1, tier <= UpgradeDefinitions.staff.count else { return }
        let cost = UpgradeDefinitions.staff[tier - 1].coinCost
        guard stall.coins >= cost else { return }
        stall.coins -= cost
        switch tier {
        case 1: stall.tier1Count += 1
        case 2: stall.tier2Count += 1
        case 3: stall.tier3Count += 1
        default: break
        }
        stall.staffTier = max(stall.staffTier, tier)
        save()
    }

    // MARK: - Offline

    public func applyOfflineEarnings(multiplier: Double = 1.0) {
        let earned = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: progress.lastActiveDate,
            multiplier: multiplier,
            seasonMultiplier: SeasonSystem.earningsMultiplier(for: season.currentSeason)
        )
        offlineEarnings = earned
        stall.coins    += earned
        progress.totalEarned += earned
        progress.lastActiveDate = Date()
        save()
    }

    public func clearOfflineEarnings() { offlineEarnings = 0 }

    // MARK: - Upgrades

    public func purchaseUpgrade(_ type: UpgradeType) {
        switch type {
        case .staff:
            let nextTier = stall.staffTier
            guard nextTier < UpgradeDefinitions.staff.count else { return }
            let cost = UpgradeDefinitions.staff[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins    -= cost
            stall.staffTier += 1
            switch stall.staffTier {
            case 1: stall.tier1Count += 1
            case 2: stall.tier2Count += 1
            case 3: stall.tier3Count += 1
            default: break
            }

        case .menu:
            let nextTier = stall.menuTier + 1
            guard nextTier < UpgradeDefinitions.menu.count else { return }
            let cost = UpgradeDefinitions.menu[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            stall.menuTier += 1

        case .stall:
            let nextTier = stall.stallTier + 1
            guard nextTier < UpgradeDefinitions.stall.count else { return }
            let cost = UpgradeDefinitions.stall[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            stall.stallTier += 1

        case .location:
            let nextTier = stall.locationTier + 1
            guard nextTier < UpgradeDefinitions.location.count else { return }
            let cost = UpgradeDefinitions.location[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            stall.locationTier += 1

        case .farm:
            guard let cost = FarmSystem.costForNextPlot(currentCount: farm.plots.count) else { return }
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            farm.plots.append(FarmPlot())
        }
        save()
    }

    // MARK: - Lifecycle

    public func markFirstLaunchComplete() { progress.isFirstLaunch = false; save() }

    public func setShopName(_ name: String) {
        progress.shopName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "봄동 가게" : name
        progress.isShopNameSet = true
        save()
    }

    public func recordBackground() { progress.lastActiveDate = Date(); save() }

    private func save() {
        if let d = try? JSONEncoder().encode(stall)    { defaults.set(d, forKey: DefaultsKey.stall) }
        if let d = try? JSONEncoder().encode(farm)     { defaults.set(d, forKey: DefaultsKey.farm) }
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: DefaultsKey.progress) }
    }
}
