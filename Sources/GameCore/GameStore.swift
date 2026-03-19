import Foundation
import Combine

public enum UpgradeType {
    case staff, menu, stall, farm, farmWorker
}

@MainActor
public final class GameStore: ObservableObject {

    @Published public var stall: StallState
    @Published public var farm: FarmState
    @Published public var progress: PlayerProgress
    @Published public var offlineEarnings: Double = 0

    private enum DefaultsKey {
        static let stall    = "gameStore.stall"
        static let farm     = "gameStore.farm"
        static let progress = "gameStore.progress"
    }

    private let defaults: UserDefaults
    private var cookAccumulators: [Double] = [0, 0, 0];   // per-menu
    private var cashierAccumulator: Double = 0;

    // MARK: - Energy constants
    private static let energyDepletionRate: Double = 1.0 / 180.0;  // empties in 3 min
    private static let energyRestoreRate:   Double = 1.0 / 90.0;   // full in 1.5 min

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
        self.progress = loadedProgress
        normalizeIdlePools()
    }

    // MARK: - Energy

    private func energyMultiplier(_ energy: Double) -> Double {
        max(0.2, energy);   // minimum 20% speed when exhausted
    }

    /// Pop the oldest idle energy for a tier (returns 1.0 if pool is empty).
    @discardableResult
    private func popIdleEnergy(for tier: Int) -> Double {
        switch tier {
        case 1: return stall.tier1IdleEnergies.isEmpty ? 1.0 : stall.tier1IdleEnergies.removeFirst()
        case 2: return stall.tier2IdleEnergies.isEmpty ? 1.0 : stall.tier2IdleEnergies.removeFirst()
        case 3: return stall.tier3IdleEnergies.isEmpty ? 1.0 : stall.tier3IdleEnergies.removeFirst()
        default: return 1.0
        }
    }

    /// Push a worker's current energy into the idle pool for their tier.
    /// Values below 5% are snapped to exactly 0.0 so the bar shows cleanly empty.
    private func pushIdleEnergy(_ energy: Double, for tier: Int) {
        let snapped = energy < 0.05 ? 0.0 : energy
        switch tier {
        case 1: stall.tier1IdleEnergies.append(snapped)
        case 2: stall.tier2IdleEnergies.append(snapped)
        case 3: stall.tier3IdleEnergies.append(snapped)
        default: break
        }
    }

    /// Fix any pool size mismatch left by old bugs: trim excess (oldest entries) or pad with 1.0.
    private func normalizeIdlePools() {
        let menu1 = stall.menuCooks.filter { $0 == 1 }.count
        let menu2 = stall.menuCooks.filter { $0 == 2 }.count
        let menu3 = stall.menuCooks.filter { $0 == 3 }.count
        let cashier1 = stall.cashierTier == 1 ? stall.cashierCount : 0
        let cashier2 = stall.cashierTier == 2 ? stall.cashierCount : 0
        let farm1 = farmAssigned

        let expected1 = max(0, stall.tier1Count - menu1 - cashier1 - farm1)
        let expected2 = max(0, stall.tier2Count - menu2 - cashier2)
        let expected3 = max(0, stall.tier3Count - menu3)

        normalize(pool: &stall.tier1IdleEnergies, to: expected1)
        normalize(pool: &stall.tier2IdleEnergies, to: expected2)
        normalize(pool: &stall.tier3IdleEnergies, to: expected3)
    }

    private func normalize(pool: inout [Double], to expected: Int) {
        if pool.count > expected {
            pool.removeFirst(pool.count - expected)
        } else if pool.count < expected {
            pool.append(contentsOf: Array(repeating: 1.0, count: expected - pool.count))
        }
    }

    // MARK: - Tick

    public func tick(deltaTime: Double) {
        let growRate   = FarmSystem.growthRate(for: farm);
        let activePlots = FarmSystem.activePlotCount(for: farm);

        // Energy: deplete while working, restore while resting
        for i in 0..<stall.tier1IdleEnergies.count {
            stall.tier1IdleEnergies[i] = min(1, stall.tier1IdleEnergies[i] + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<stall.tier2IdleEnergies.count {
            stall.tier2IdleEnergies[i] = min(1, stall.tier2IdleEnergies[i] + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<stall.tier3IdleEnergies.count {
            stall.tier3IdleEnergies[i] = min(1, stall.tier3IdleEnergies[i] + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<stall.menuCookEnergy.count {
            if i < stall.menuCooks.count, stall.menuCooks[i] > 0 {
                stall.menuCookEnergy[i] = max(0, stall.menuCookEnergy[i] - Self.energyDepletionRate * deltaTime);
            } else {
                stall.menuCookEnergy[i] = min(1, stall.menuCookEnergy[i] + Self.energyRestoreRate * deltaTime);
            }
        }
        if stall.cashierCount > 0 {
            stall.cashierEnergy = max(0, stall.cashierEnergy - Self.energyDepletionRate * deltaTime);
        } else {
            stall.cashierEnergy = min(1, stall.cashierEnergy + Self.energyRestoreRate * deltaTime);
        }
        for i in 0..<farm.plots.count {
            if farm.plots[i].hasWorker {
                farm.plots[i].workerEnergy = max(0, farm.plots[i].workerEnergy - Self.energyDepletionRate * deltaTime);
            } else {
                farm.plots[i].workerEnergy = min(1, farm.plots[i].workerEnergy + Self.energyRestoreRate * deltaTime);
            }
        }

        // Grow planted plots
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].isPlanted, !farm.plots[i].isReady else { continue }
            let workerDef = stall.farmWorkerTier - 1 < UpgradeDefinitions.farmWorker.count
                ? UpgradeDefinitions.farmWorker[stall.farmWorkerTier - 1]
                : nil
            let boost = farm.plots[i].hasWorker ? (workerDef?.productionMultiplier ?? 1.0) : 1.0
            farm.plots[i].growth = min(farm.plots[i].growth + growRate * boost * deltaTime, 1.0);
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
            let energy = i < stall.menuCookEnergy.count ? stall.menuCookEnergy[i] : 1.0;
            cookAccumulators[i] += cookRate(forTier: tier) * energyMultiplier(energy) * deltaTime;
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

        // Rating slowly decays — active serving easily overcomes it, idle play drifts down
        progress.rating = max(1.0, progress.rating - 0.0002 * deltaTime)
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
        let price = EarningsSystem.pricePerItem(for: stall, menuIndex: menuIndex)
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

    /// Energy levels for each menu cook slot (0.0–1.0).
    public var menuCookEnergies: [Double] { stall.menuCookEnergy }

    /// Energy level for the cashier worker (0.0–1.0).
    public var cashierEnergy: Double { stall.cashierEnergy }

    /// Base spawn interval in seconds, driven by shop rating (0.5-step tiers).
    /// 1.0=20s  1.5=16s  2.0=12s  2.5=8s  3.0=5s  3.5=3.5s  4.0=2.5s  4.5=1.8s  5.0=1.2s
    public var customerSpawnInterval: Double {
        switch progress.rating {
        case ..<1.5: return 20.0
        case 1.5..<2.0: return 16.0
        case 2.0..<2.5: return 12.0
        case 2.5..<3.0: return 8.0
        case 3.0..<3.5: return 5.0
        case 3.5..<4.0: return 3.5
        case 4.0..<4.5: return 2.5
        case 4.5..<5.0: return 1.8
        default:         return 1.2
        }
    }

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
        return 0.07 * UpgradeDefinitions.staff[tier - 1].productionMultiplier
        // tier1 (×2.0) → 0.14/s  ~7s per item
        // tier2 (×4.0) → 0.28/s  ~3.6s per item
        // tier3 (×7.0) → 0.49/s  ~2s per item
    }

    /// Human-readable cook speed label for the given tier.
    public static func cookSpeedLabel(forTier tier: Int) -> String {
        switch tier {
        case 1: return "7초/개"
        case 2: return "3.6초/개"
        case 3: return "2초/개"
        default: return ""
        }
    }

    // MARK: - Staff workers

    private var farmAssigned: Int { farm.plots.filter { $0.hasWorker }.count }

    /// Workers not yet placed anywhere
    public var availableWorkers: Int {
        stall.staffCount - farmAssigned - stall.cashierCount - stall.menuCooks.filter { $0 > 0 }.count
    }

    /// Only unassigned tier-1 workers can go to farm
    public var availableForFarm: Int {
        let menu1    = stall.menuCooks.filter { $0 == 1 }.count
        let cashier1 = stall.cashierTier == 1 ? stall.cashierCount : 0
        return stall.tier1Count - farmAssigned - menu1 - cashier1
    }

    public func toggleWorker(plotIndex: Int, displayedEnergy: Double? = nil, addToIdle: Bool = true, directEnergy: Double? = nil) {
        guard plotIndex < farm.plots.count else { return }
        if farm.plots[plotIndex].hasWorker {
            let energy = displayedEnergy ?? farm.plots[plotIndex].workerEnergy
            if addToIdle { pushIdleEnergy(energy, for: 1) }
            farm.plots[plotIndex].workerEnergy = 1.0
            farm.plots[plotIndex].hasWorker = false
        } else {
            guard availableForFarm > 0 else { return }
            farm.plots[plotIndex].workerEnergy = directEnergy ?? popIdleEnergy(for: 1)
            farm.plots[plotIndex].hasWorker = true
        }
        stall.farmWorkers = farmAssigned
        save()
    }

    public func assignToCashier(tier: Int = 0, directEnergy: Double? = nil) {
        let t = tier > 0 ? tier : 1
        guard unassignedCount(for: t) > 0, stall.cashierCount == 0 else { return }
        stall.cashierEnergy = directEnergy ?? popIdleEnergy(for: t)
        stall.cashierTier   = t
        stall.cashierCount += 1
        save()
    }

    public func removeFromCashier(displayedEnergy: Double? = nil, addToIdle: Bool = true) {
        guard stall.cashierCount > 0 else { return }
        let energy = displayedEnergy ?? stall.cashierEnergy
        if addToIdle { pushIdleEnergy(energy, for: stall.cashierTier) }
        stall.cashierEnergy = 1.0
        stall.cashierTier   = 0
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

    /// Assign a worker of a specific tier directly to a menu slot.
    public func assignMenuCook(menuIndex: Int, tier: Int, directEnergy: Double? = nil) {
        guard menuIndex <= stall.menuTier,
              menuIndex < stall.menuCooks.count,
              stall.menuCooks[menuIndex] == 0 else { return }
        guard unassignedCount(for: tier) > 0 else { return }
        stall.menuCooks[menuIndex] = tier
        stall.menuCookEnergy[menuIndex] = directEnergy ?? popIdleEnergy(for: tier)
        save()
    }

    private func tierCount(for tier: Int) -> Int {
        switch tier {
        case 1: stall.tier1Count
        case 2: stall.tier2Count
        case 3: stall.tier3Count
        default: 0
        }
    }

    /// Number of unassigned (idle) workers for a given tier.
    private func unassignedCount(for tier: Int) -> Int {
        let menuUsed    = stall.menuCooks.filter { $0 == tier }.count
        let cashierUsed = stall.cashierTier == tier ? stall.cashierCount : 0
        let farmUsed    = tier == 1 ? farmAssigned : 0
        return tierCount(for: tier) - menuUsed - cashierUsed - farmUsed
    }

    public func removeMenuCook(menuIndex: Int, displayedEnergy: Double? = nil, addToIdle: Bool = true) {
        guard menuIndex < stall.menuCooks.count,
              stall.menuCooks[menuIndex] > 0 else { return }
        let tier = stall.menuCooks[menuIndex]
        let energy = displayedEnergy ?? stall.menuCookEnergy[menuIndex]
        if addToIdle { pushIdleEnergy(energy, for: tier) }
        stall.menuCookEnergy[menuIndex] = 1.0
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
        case 1: stall.tier1Count += 1; stall.tier1IdleEnergies.append(1.0)
        case 2: stall.tier2Count += 1; stall.tier2IdleEnergies.append(1.0)
        case 3: stall.tier3Count += 1; stall.tier3IdleEnergies.append(1.0)
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
        case 1: stall.tier1Count += 1; stall.tier1IdleEnergies.append(1.0)
        case 2: stall.tier2Count += 1; stall.tier2IdleEnergies.append(1.0)
        case 3: stall.tier3Count += 1; stall.tier3IdleEnergies.append(1.0)
        default: break
        }
        stall.staffTier = max(stall.staffTier, tier)
        save()
    }

    /// Upgrade one idle worker from `tier` to `tier + 1`, paying the target tier's hire cost.
    /// The worker must be idle (unassigned). `energy` is the displayed energy to preserve.
    public func upgradeWorker(fromTier tier: Int, preservingEnergy energy: Double) {
        let targetTier = tier + 1
        guard targetTier <= 3 else { return }
        let cost = UpgradeDefinitions.staff[targetTier - 1].coinCost
        guard stall.coins >= cost else { return }

        stall.coins -= cost

        // Remove one idle slot from old tier (any entry, workers are fungible)
        switch tier {
        case 1:
            if !stall.tier1IdleEnergies.isEmpty { stall.tier1IdleEnergies.removeFirst() }
            stall.tier1Count -= 1
        case 2:
            if !stall.tier2IdleEnergies.isEmpty { stall.tier2IdleEnergies.removeFirst() }
            stall.tier2Count -= 1
        default: return
        }

        // Add upgraded worker using the caller-supplied energy (what the player saw)
        switch targetTier {
        case 2: stall.tier2Count += 1; stall.tier2IdleEnergies.append(energy)
        case 3: stall.tier3Count += 1; stall.tier3IdleEnergies.append(energy)
        default: break
        }
        stall.staffTier = max(stall.staffTier, targetTier)
        save()
    }

    // MARK: - Offline

    /// Calculate offline earnings (cold start or bg→fg). Does NOT add coins or change lastActiveDate.
    public func calculateOfflineEarnings() {
        let cps = offlineCPS()
        guard let lastActive = progress.lastActiveDate else {
            print("[Offline] skip — lastActiveDate is nil")
            return
        }
        let elapsed = min(Date().timeIntervalSince(lastActive), OfflineProgressSystem.maxOfflineHours * 3600)
        guard elapsed >= 60 else {
            print("[Offline] skip — elapsed \(Int(elapsed))s < 60s")
            return
        }
        let earned = cps * elapsed * OfflineProgressSystem.offlineEfficiency
        print("[Offline] lastActive=\(lastActive), elapsed=\(Int(elapsed))s, cps=\(String(format:"%.4f",cps)), earned=\(Int(earned))")
        offlineEarnings = earned
    }

    /// Uses actual in-game cook rate (0.07/s base), not the display rate (1.0/s).
    /// Falls back to staffTier rate when no cooks are assigned to menu slots.
    private func offlineCPS() -> Double {
        var total = 0.0
        for i in 0...stall.menuTier {
            let tier = i < stall.menuCooks.count ? stall.menuCooks[i] : 0
            guard tier > 0 else { continue }
            total += cookRate(forTier: tier) * EarningsSystem.pricePerItem(for: stall, menuIndex: i)
        }
        if total == 0, stall.staffTier > 0 {
            total = cookRate(forTier: stall.staffTier) * EarningsSystem.pricePerItem(for: stall)
        }
        return total
    }

    /// Redeem the pre-calculated offline amount with a multiplier.
    public func collectOfflineEarnings(multiplier: Double = 1.0) {
        guard offlineEarnings > 0 else { return }
        let earned = offlineEarnings * multiplier
        stall.coins          += earned
        progress.totalEarned += earned
        progress.lastActiveDate = Date()
        offlineEarnings = 0
        save()
    }

    public func recordServed(waitTime: Double) {
        progress.totalServed += 1
        let delta = waitTime < 3.0 ? 0.03 : 0.01
        progress.rating = min(5.0, progress.rating + delta)
        save()
    }

    public func recordFailed() {
        progress.totalFailed += 1
        progress.rating = max(1.0, progress.rating - 0.05)
        save()
    }

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
            case 1: stall.tier1Count += 1; stall.tier1IdleEnergies.append(1.0)
            case 2: stall.tier2Count += 1; stall.tier2IdleEnergies.append(1.0)
            case 3: stall.tier3Count += 1; stall.tier3IdleEnergies.append(1.0)
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

        case .farm:
            guard let cost = FarmSystem.costForNextPlot(currentCount: farm.plots.count) else { return }
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            farm.plots.append(FarmPlot())

        case .farmWorker:
            let nextTier = stall.farmWorkerTier
            guard nextTier < UpgradeDefinitions.farmWorker.count else { return }
            let cost = UpgradeDefinitions.farmWorker[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            stall.farmWorkerTier += 1
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

    public func recordBackground() {
        guard offlineEarnings == 0 else { return }   // popup showing — don't corrupt lastActiveDate
        progress.lastActiveDate = Date()
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(stall)    { defaults.set(d, forKey: DefaultsKey.stall) }
        if let d = try? JSONEncoder().encode(farm)     { defaults.set(d, forKey: DefaultsKey.farm) }
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: DefaultsKey.progress) }
    }
}
