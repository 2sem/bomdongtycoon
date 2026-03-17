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
        static let stall = "gameStore.stall"
        static let farm  = "gameStore.farm"
        static let progress = "gameStore.progress"
    }

    private let defaults: UserDefaults
    private var cookAccumulator: Double = 0

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
        let seasonStart = loadedProgress.seasonStartDate!
        self.progress = loadedProgress
        self.season = SeasonSystem.currentState(seasonStart: seasonStart)

        // Migration: old saves have staffCount == 0 but staffTier > 0
        if self.stall.staffCount == 0 && self.stall.staffTier > 0 {
            self.stall.staffCount = self.stall.staffTier
        }
    }

    // MARK: - Tick

    public func tick(deltaTime: Double) {
        let seasonMult = SeasonSystem.earningsMultiplier(for: season.currentSeason)
        let rate = FarmSystem.growthRate(for: farm) * seasonMult
        let activePlots = FarmSystem.activePlotCount(for: farm)

        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].isPlanted, !farm.plots[i].isReady else { continue }
            farm.plots[i].growth = min(farm.plots[i].growth + rate * deltaTime, 1.0)
        }

        // Per-plot workers auto-harvest and auto-replant
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].hasWorker else { continue }
            if farm.plots[i].isReady {
                guard stall.warehouse < stall.warehouseCapacity else { continue }
                stall.warehouse += FarmSystem.harvestYield
                farm.plots[i].growth = 0
                farm.plots[i].isPlanted = false
            }
            if !farm.plots[i].isPlanted, stall.coins >= FarmSystem.seedCost {
                stall.coins -= FarmSystem.seedCost
                farm.plots[i].isPlanted = true
            }
        }

        // Shop workers auto-cook: warehouse → menuStock
        if stall.shopWorkers > 0, stall.warehouse > 0 {
            let rate = EarningsSystem.productionRate(for: stall) * Double(stall.shopWorkers)
            cookAccumulator += rate * deltaTime
            while cookAccumulator >= 1.0, stall.warehouse > 0 {
                cookAccumulator -= 1.0
                let menus = stall.menuTier + 1
                let maxStock = EarningsSystem.maxStock(for: stall)
                // Find menu with least stock to distribute evenly
                var distributed = false
                for i in 0..<menus {
                    guard i < stall.menuStock.count,
                          stall.menuStock[i] < maxStock,
                          stall.warehouse > 0 else { continue }
                    stall.menuStock[i] += 1
                    stall.warehouse -= 1
                    distributed = true
                    break
                }
                if !distributed { cookAccumulator = 0 }
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

    /// Called by CustomerNode. Returns sale price or nil if out of stock.
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
        farm.plots[plotIndex].growth = 0
        save()
    }

    public func harvest(plotIndex: Int) {
        guard plotIndex < farm.plots.count,
              farm.plots[plotIndex].isReady,
              stall.warehouse < stall.warehouseCapacity else { return }
        stall.warehouse += FarmSystem.harvestYield
        farm.plots[plotIndex].growth = 0
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

    // MARK: - Batch cook (manual)

    public func batchCook() {
        guard stall.warehouse > 0 else { return }
        let menus = stall.menuTier + 1
        let maxStock = EarningsSystem.maxStock(for: stall)
        let perWorker = stall.staffTier > 0
            ? max(1, Int(round(UpgradeDefinitions.staff[stall.staffTier - 1].productionMultiplier)))
            : 1
        let batchTotal = min(perWorker * max(1, stall.shopWorkers), stall.warehouse)
        let base = batchTotal / menus
        let rem  = batchTotal % menus
        var changed = false
        for i in 0..<menus {
            guard stall.warehouse > 0, i < stall.menuStock.count else { break }
            let want   = base + (i >= menus - rem ? 1 : 0)
            let amount = min(want, maxStock - stall.menuStock[i], stall.warehouse)
            guard amount > 0 else { continue }
            stall.warehouse    -= amount
            stall.menuStock[i] += amount
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Workers

    private var availableWorkers: Int {
        let assignedToPlots = farm.plots.filter { $0.hasWorker }.count
        return stall.staffCount - stall.shopWorkers - assignedToPlots
    }

    public func toggleWorker(plotIndex: Int) {
        guard plotIndex < farm.plots.count else { return }
        if farm.plots[plotIndex].hasWorker {
            farm.plots[plotIndex].hasWorker = false
        } else {
            guard availableWorkers > 0 else { return }
            farm.plots[plotIndex].hasWorker = true
        }
        stall.farmWorkers = farm.plots.filter { $0.hasWorker }.count
        save()
    }

    public func assignWorkerToShop() {
        guard availableWorkers > 0 else { return }
        stall.shopWorkers += 1
        save()
    }

    public func removeWorkerFromShop() {
        guard stall.shopWorkers > 0 else { return }
        stall.shopWorkers -= 1
        save()
    }

    public func hireWorker() {
        guard stall.staffTier > 0 else { return }
        let idx = stall.staffTier - 1
        let cost = UpgradeDefinitions.staff[idx].coinCost
        guard stall.coins >= cost else { return }
        stall.coins -= cost
        stall.staffCount += 1
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
        stall.coins += earned
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
            stall.coins -= cost
            stall.staffTier += 1
            stall.staffCount += 1
            stall.shopWorkers += 1

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

    public func markFirstLaunchComplete() {
        progress.isFirstLaunch = false
        save()
    }

    public func setShopName(_ name: String) {
        progress.shopName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "봄동 가게" : name
        progress.isShopNameSet = true
        save()
    }

    public func recordBackground() {
        progress.lastActiveDate = Date()
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(stall)    { defaults.set(d, forKey: DefaultsKey.stall) }
        if let d = try? JSONEncoder().encode(farm)     { defaults.set(d, forKey: DefaultsKey.farm) }
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: DefaultsKey.progress) }
    }
}
