import Foundation
import Combine

// MARK: - UpgradeType

public enum UpgradeType {
    case staff
    case menu
    case stall
    case location
    case farm
}

// MARK: - GameStore

@MainActor
public final class GameStore: ObservableObject {

    // MARK: Published state

    @Published public var stall: StallState
    @Published public var farm: FarmState
    @Published public var progress: PlayerProgress
    @Published public var season: SeasonState
    @Published public var offlineEarnings: Double = 0

    // MARK: Persistence keys

    private enum DefaultsKey {
        static let stall = "gameStore.stall"
        static let farm = "gameStore.farm"
        static let progress = "gameStore.progress"
    }

    private let defaults: UserDefaults

    // MARK: Init

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load persisted stall
        if let data = defaults.data(forKey: DefaultsKey.stall),
           let saved = try? JSONDecoder().decode(StallState.self, from: data) {
            self.stall = saved
        } else {
            self.stall = StallState()
        }

        // Load persisted farm
        if let data = defaults.data(forKey: DefaultsKey.farm),
           let saved = try? JSONDecoder().decode(FarmState.self, from: data) {
            self.farm = saved
        } else {
            self.farm = FarmState()
        }

        // Load persisted progress into a local so we can mutate before assigning to self
        var loadedProgress: PlayerProgress
        if let data = defaults.data(forKey: DefaultsKey.progress),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            loadedProgress = saved
        } else {
            loadedProgress = PlayerProgress()
        }

        // Set seasonStartDate on first launch
        if loadedProgress.seasonStartDate == nil {
            loadedProgress.seasonStartDate = Date()
        }

        // Derive initial season before assigning self properties
        let seasonStart = loadedProgress.seasonStartDate!
        self.progress = loadedProgress
        self.season = SeasonSystem.currentState(seasonStart: seasonStart)
    }

    // MARK: Tick

    public func tick(deltaTime: Double) {
        let seasonMult = SeasonSystem.earningsMultiplier(for: season.currentSeason)
        let rate = FarmSystem.growthRate(for: farm) * seasonMult
        let activePlots = FarmSystem.activePlotCount(for: farm)

        // Grow only planted plots
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].isPlanted, !farm.plots[i].isReady else { continue }
            farm.plots[i].growth = min(farm.plots[i].growth + rate * deltaTime, 1.0)
        }

        // Farm workers auto-harvest ready plots then auto-replant
        if farm.farmWorkers > 0 {
            let yield = FarmSystem.harvestYield
            let maxStock = Double(EarningsSystem.maxStock(for: stall))
            for i in 0..<min(activePlots, farm.plots.count) {
                if farm.plots[i].isReady {
                    stall.stock = min(stall.stock + Double(yield), maxStock)
                    farm.plots[i].growth = 0
                    farm.plots[i].isPlanted = false
                }
                if !farm.plots[i].isPlanted, stall.coins >= FarmSystem.seedCost {
                    stall.coins -= FarmSystem.seedCost
                    farm.plots[i].isPlanted = true
                }
            }
        }
    }

    // MARK: Collect

    public func collectCoins() {
        stall.coins += stall.pendingCoins
        progress.totalEarned += stall.pendingCoins
        stall.pendingCoins = 0
        save()
    }

    // MARK: Farm

    /// Plant a seed in an empty plot. Costs `FarmSystem.seedCost` coins.
    public func plantSeed(plotIndex: Int) {
        guard plotIndex < farm.plots.count,
              !farm.plots[plotIndex].isPlanted,
              stall.coins >= FarmSystem.seedCost else { return }
        stall.coins -= FarmSystem.seedCost
        farm.plots[plotIndex].isPlanted = true
        farm.plots[plotIndex].growth = 0
        save()
    }

    /// Harvest a fully-grown plot. Resets to empty.
    public func harvest(plotIndex: Int) {
        guard plotIndex < farm.plots.count,
              farm.plots[plotIndex].isReady else { return }
        let yield = FarmSystem.harvestYield
        let maxStock = Double(EarningsSystem.maxStock(for: stall))
        stall.stock = min(stall.stock + Double(yield), maxStock)
        farm.plots[plotIndex].growth = 0
        farm.plots[plotIndex].isPlanted = false
        save()
    }

    public func assignWorkerToFarm() {
        guard stall.shopWorkers > 0 else { return }
        stall.shopWorkers -= 1
        stall.farmWorkers += 1
        farm.farmWorkers = stall.farmWorkers
        syncWorkerMarkers()
        save()
    }

    public func assignWorkerToShop() {
        guard stall.farmWorkers > 0 else { return }
        stall.farmWorkers -= 1
        stall.shopWorkers += 1
        farm.farmWorkers = stall.farmWorkers
        syncWorkerMarkers()
        save()
    }

    private func syncWorkerMarkers() {
        for i in 0..<farm.plots.count {
            farm.plots[i].hasWorker = i < stall.farmWorkers
        }
    }

    // MARK: Offline earnings

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

    public func clearOfflineEarnings() {
        offlineEarnings = 0
    }

    // MARK: Upgrades

    public func purchaseUpgrade(_ type: UpgradeType) {
        switch type {
        case .staff:
            let nextTier = stall.staffTier
            guard nextTier < UpgradeDefinitions.staff.count else { return }
            let cost = UpgradeDefinitions.staff[nextTier].coinCost
            guard stall.coins >= cost else { return }
            stall.coins -= cost
            stall.staffTier += 1
            stall.shopWorkers += 1  // new worker defaults to shop

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

    // MARK: Lifecycle

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

    // MARK: Persistence

    private func save() {
        if let stallData = try? JSONEncoder().encode(stall) {
            defaults.set(stallData, forKey: DefaultsKey.stall)
        }
        if let farmData = try? JSONEncoder().encode(farm) {
            defaults.set(farmData, forKey: DefaultsKey.farm)
        }
        if let progressData = try? JSONEncoder().encode(progress) {
            defaults.set(progressData, forKey: DefaultsKey.progress)
        }
    }
}
