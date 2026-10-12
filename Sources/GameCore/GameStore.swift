import Foundation
import Combine

public enum UpgradeType {
    case staff, menu, stall, farm, farmWorker, location
}

extension Notification.Name {
    /// Posted after a location purchase. `userInfo["tier"]` is the new `Int` tier.
    /// Scene hook only; `store.stall.locationTier` is also published.
    public static let locationTierDidChange = Notification.Name("GameStore.locationTierDidChange")
}

@MainActor
public final class GameStore: ObservableObject {

    @Published public var stall: StallState
    @Published public var farm: FarmState
    @Published public var progress: PlayerProgress
    @Published public var offlineEarnings: Double = 0

    /// Set by the UI while the tutorial or shop-name overlay is up. Frozen
    /// time: `tick` is a no-op and offline earnings are not computed, so a
    /// player reading the tutorial loses no coins or rating. Not persisted.
    public var isSimulationPaused = false {
        didSet {
            guard oldValue, !isSimulationPaused else { return }
            progress.lastActiveDate = Date()
            earningWindowCoins = 0
            earningWindowTime  = 0
            activitySaveTimer  = 0
        }
    }

    /// The three persisted blobs. `corruptKey` keeps the raw bytes of the latest blob that failed
    /// to decode, so the next `save()` cannot destroy the only copy.
    enum SaveBlob: String {
        case stall, farm, progress
        var key: String { "gameStore.\(rawValue)" }
        var corruptKey: String { "gameStore.\(rawValue).corrupt" }
    }

    private let defaults: UserDefaults
    private var cookAccumulators: [Double] = [0, 0, 0];   // per-menu
    /// In-flight manual (tap) cook progress (0..<1), keyed by menu index —
    /// presence of a key means a manual cook is running for that index.
    /// Transient like `cookAccumulators`: not part of `StallState`'s
    /// Codable keys, so a cook in flight when the app dies is simply lost.
    private var manualCookProgress: [Int: Double] = [:]
    private var cashierAccumulator: Double = 0
    private var activitySaveTimer: Double = 0            // flush lastActiveDate + earningRate to disk every 5s
    private var earningWindowCoins: Double = 0           // coins earned in current 5s window
    private var earningWindowTime: Double = 0            // time elapsed in current window

    // MARK: - Energy constants
    private static let energyRestoreRate:      Double = 1.0 / 90.0    // full in 1.5 min (when idle)
    private static let energyPerCook:          Double = 1.0 / 300.0   // 300 items per full bar
    private static let energyPerCashierCollect: Double = 1.0 / 60.0   // 60 collections per full bar
    private static let energyPerHarvest:       Double = 1.0 / 8.0     // 8 harvests per full bar

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.stall    = Self.load(StallState.self, blob: .stall, from: defaults) ?? StallState()
        self.farm     = Self.load(FarmState.self, blob: .farm, from: defaults) ?? FarmState()
        self.progress = Self.load(PlayerProgress.self, blob: .progress, from: defaults) ?? PlayerProgress()
        normalizeIdlePools()
    }

    /// nil when the blob is absent. When it exists but cannot be decoded, its bytes are copied to
    /// `corruptKey` (replacing any older copy) before the caller falls back to fresh state.
    private static func load<T: Decodable>(_ type: T.Type, blob: SaveBlob, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: blob.key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            if defaults.data(forKey: blob.corruptKey) != data {
                defaults.set(data, forKey: blob.corruptKey)
            }
            SaveDiagnostics.corruptBlob(blob.rawValue, bytes: data.count)
            return nil
        }
    }

    /// Raw bytes of the latest undecodable copy of `blob`, if any.
    func corruptBackup(of blob: SaveBlob) -> Data? {
        defaults.data(forKey: blob.corruptKey)
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
        case 5: return stall.veteranAlbaIdleEnergies.isEmpty ? 1.0 : stall.veteranAlbaIdleEnergies.removeFirst()
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
        case 5: stall.veteranAlbaIdleEnergies.append(snapped)
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

        let expectedFarmers  = max(0, stall.farmerCount - farmersAssigned)
        let cashier5         = stall.cashierTier == 5 ? stall.cashierCount : 0
        let expectedVetAlbas = max(0, stall.veteranAlbaCount - veteranAlbasAssigned - cashier5)
        normalize(pool: &stall.farmerIdleEnergies,      to: expectedFarmers)
        normalize(pool: &stall.veteranAlbaIdleEnergies, to: expectedVetAlbas)
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
        guard !isSimulationPaused else { return }
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
        for i in 0..<stall.farmerIdleEnergies.count {
            stall.farmerIdleEnergies[i] = min(1, stall.farmerIdleEnergies[i] + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<stall.veteranAlbaIdleEnergies.count {
            stall.veteranAlbaIdleEnergies[i] = min(1, stall.veteranAlbaIdleEnergies[i] + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<stall.menuCookEnergy.count {
            // Restore when unassigned OR warehouse empty (no work to do)
            // Depletion happens per item cooked (see auto-cook loop below)
            let isWorking = i < stall.menuCooks.count && stall.menuCooks[i] > 0 && stall.warehouse > 0
            if !isWorking {
                stall.menuCookEnergy[i] = min(1, stall.menuCookEnergy[i] + Self.energyRestoreRate * deltaTime)
            }
        }
        // Cashier restore when no pending coins; depletion per collection (see cashier loop below)
        if stall.cashierCount == 0 || stall.pendingCoins == 0 {
            stall.cashierEnergy = min(1, stall.cashierEnergy + Self.energyRestoreRate * deltaTime)
        }
        for i in 0..<farm.plots.count {
            if !farm.plots[i].hasWorker || !farm.plots[i].isPlanted || !farm.plots[i].isReady {
                // Restore when unassigned OR waiting for crop to grow
                farm.plots[i].workerEnergy = min(1, farm.plots[i].workerEnergy + Self.energyRestoreRate * deltaTime)
            }
            // Depletion happens per harvest (see auto-harvest loop below)
        }

        // Grow planted plots
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].isPlanted, !farm.plots[i].isReady else { continue }
            let boost: Double
            switch farm.plots[i].workerType {
            case .farmer:      boost = UpgradeDefinitions.farmer[0].productionMultiplier
            case .veteranAlba: boost = UpgradeDefinitions.veteranAlba[0].productionMultiplier
            default:           boost = 1.0
            }
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
                farm.plots[i].workerEnergy = max(0, farm.plots[i].workerEnergy - Self.energyPerHarvest)
            }
            // A worker replants only while one more seed stays in hand
            // afterwards, so an idle fresh save settles at seedCost coins
            // instead of draining to 0 (manual planting is unaffected).
            if !farm.plots[i].isPlanted, stall.coins >= FarmSystem.seedCost * 2 {
                stall.coins -= FarmSystem.seedCost
                farm.plots[i].isPlanted = true
            }
        }

        // Per-menu auto-cook: dedicated cook produces at tier-based speed
        let maxStock = EarningsSystem.maxStock(for: stall)
        for i in 0..<stall.menuCooks.count {
            guard canAutoCook(menuIndex: i, maxStock: maxStock) else { continue }
            let tier = stall.menuCooks[i]
            let energy = i < stall.menuCookEnergy.count ? stall.menuCookEnergy[i] : 1.0;
            cookAccumulators[i] += cookRate(forTier: tier) * energyMultiplier(energy) * deltaTime;
            while cookAccumulators[i] >= 1.0,
                  stall.warehouse > 0,
                  stall.menuStock[i] < maxStock {
                cookAccumulators[i] -= 1.0
                stall.warehouse    -= 1
                stall.menuStock[i] += 1
                stall.menuCookEnergy[i] = max(0, stall.menuCookEnergy[i] - Self.energyPerCook)
            }
        }

        // Manual (tap) cook: one running session per menu index, advanced
        // at the fixed `manualCookRate` (slower than any hired cook — see
        // its own doc comment). Unlike the auto-cook loop above, a session
        // produces at most one portion, so this checks the threshold once
        // rather than draining it in a `while`. Preconditions are
        // re-checked at completion, not just at start — the warehouse can
        // empty or stock can fill while the cook is running, in which case
        // it ends without producing.
        for menuIndex in manualCookProgress.keys.sorted() {
            manualCookProgress[menuIndex, default: 0] += Self.manualCookRate * deltaTime
            guard manualCookProgress[menuIndex] ?? 0 >= 1.0 else { continue }
            manualCookProgress[menuIndex] = nil
            guard canManualCook(menuIndex: menuIndex) else { continue }
            stall.warehouse -= 1
            stall.menuStock[menuIndex] += 1
            save()
        }

        // Without a cashier, pendingCoins pays out immediately: the tap-a-bubble
        // collect was removed, so a sale must never wait on a hire that a
        // fresh tier-0 save does not have (coins would never rise).
        if stall.cashierCount == 0, stall.pendingCoins > 0 {
            collectCoins()
        }

        // A cashier keeps its 1 s collect cadence and energy cost
        if stall.cashierCount > 0, stall.pendingCoins > 0 {
            cashierAccumulator += deltaTime
            if cashierAccumulator >= 1.0 {
                cashierAccumulator = 0
                collectCoins()
                stall.cashierEnergy = max(0, stall.cashierEnergy - Self.energyPerCashierCollect)
            }
        }

        // Rating slowly decays — active serving easily overcomes it, idle play drifts down
        progress.rating = max(1.0, progress.rating - 0.0002 * deltaTime)

        // Persist lastActiveDate + earningRate every 5 s
        if offlineEarnings == 0 {
            earningWindowTime += deltaTime
            activitySaveTimer += deltaTime
            if activitySaveTimer >= 5 {
                if earningWindowTime > 0, earningWindowCoins > 0 {
                    let sample = earningWindowCoins / earningWindowTime
                    // Exponential moving average: weight new sample at 30%
                    // Only update when coins were actually earned — idle windows must not decay the rate
                    progress.earningRate = progress.earningRate == 0
                        ? sample
                        : progress.earningRate * 0.7 + sample * 0.3
                }
                earningWindowCoins = 0
                earningWindowTime  = 0
                activitySaveTimer  = 0
                progress.lastActiveDate = Date()
                save()
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
        let cashierBonus = stall.cashierTier == 5 ? 1.4 : 1.0
        let price = EarningsSystem.pricePerItem(for: stall, menuIndex: menuIndex) * cashierBonus
        stall.pendingCoins += price
        earningWindowCoins += price
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

    /// Progress toward `menuIndex`'s next portion, for gauge display. Clamped
    /// to 0...1 because the accumulator can sit briefly above 1.0 — between
    /// the `tick` that pushes it over the threshold and the `while` loop
    /// there draining it back down — so a caller reading it mid-tick must
    /// not see a raw value past 1. An out-of-range index reads as 0.
    public func cookProgress(menuIndex: Int) -> Double {
        // A manual cook running with no dedicated cook assigned owns the
        // gauge — once a cook is hired for this menu, the auto-cook
        // accumulator is the one actually producing, so it takes over
        // display even if a manual session happens to still be in flight.
        let hasDedicatedCook = menuIndex < stall.menuCooks.count && stall.menuCooks[menuIndex] > 0
        if !hasDedicatedCook, let manual = manualCookProgress[menuIndex] {
            return min(max(manual, 0), 1)
        }
        guard cookAccumulators.indices.contains(menuIndex) else { return 0 }
        return min(max(cookAccumulators[menuIndex], 0), 1)
    }

    /// Whether a manual (tap) cook is currently running for `menuIndex` —
    /// lets a caller show the gauge even in the first instant after
    /// starting, before `cookProgress` has anything above 0 to report.
    public func isManualCookRunning(menuIndex: Int) -> Bool {
        manualCookProgress[menuIndex] != nil
    }

    /// Whether `menuIndex` is actually producing right now — a manual
    /// session in flight, or a hired cook that `tick`'s auto-cook loop
    /// would currently advance. False whenever there's nothing to show:
    /// no cook and no manual session, warehouse empty, tier locked, or
    /// stock already at max.
    public func isCooking(menuIndex: Int) -> Bool {
        isManualCookRunning(menuIndex: menuIndex)
            || canAutoCook(menuIndex: menuIndex, maxStock: EarningsSystem.maxStock(for: stall))
    }

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

    /// Starts a timed manual cook for `menuIndex` (a tap on its bowl) if
    /// one isn't already running there; `tick` advances it and lands the
    /// portion on completion. Returns whether it actually started, so a
    /// caller (the tap handler) knows whether to play accept feedback —
    /// tapping again mid-cook is a no-op.
    @discardableResult
    public func startManualCook(menuIndex: Int) -> Bool {
        guard manualCookProgress[menuIndex] == nil, canManualCook(menuIndex: menuIndex) else { return false }
        manualCookProgress[menuIndex] = 0
        return true
    }

    /// Preconditions a manual cook needs both to start and, since the
    /// warehouse or stock can change while one is running, to actually
    /// produce at completion.
    private func canManualCook(menuIndex: Int) -> Bool {
        let maxStock = EarningsSystem.maxStock(for: stall)
        return menuIndex <= stall.menuTier
            && menuIndex < stall.menuStock.count
            && stall.warehouse > 0
            && stall.menuStock[menuIndex] < maxStock
    }

    /// Shared by `tick`'s auto-cook loop and `isCooking` so the two can't
    /// drift: a hired cook only actually produces when the warehouse has
    /// stock, its menu tier is unlocked, and its stock isn't already full.
    private func canAutoCook(menuIndex: Int, maxStock: Int) -> Bool {
        menuIndex >= 0 && menuIndex < stall.menuCooks.count && stall.menuCooks[menuIndex] > 0
            && stall.warehouse > 0
            && menuIndex <= stall.menuTier
            && menuIndex < stall.menuStock.count && stall.menuStock[menuIndex] < maxStock
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

    /// Items per second a manual (tap) cook produces — one portion per
    /// 10s. Deliberately below tier-1's auto-cook rate (0.14/s, ~7s/item):
    /// staff has to buy both speed and automation, so tap-spamming a bowl
    /// can never outpace hiring the cheapest cook.
    private static let manualCookRate: Double = 0.10

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

    private var farmAssigned: Int        { farm.plots.filter { $0.workerType == .alba }.count }
    private var farmersAssigned: Int     { farm.plots.filter { $0.workerType == .farmer }.count }
    private var veteranAlbasAssigned: Int { farm.plots.filter { $0.workerType == .veteranAlba }.count }

    /// Workers not yet placed anywhere
    public var availableWorkers: Int {
        stall.staffCount - farmAssigned - stall.cashierCount - stall.menuCooks.filter { $0 > 0 }.count
    }

    /// Only unassigned tier-1 albas can go to farm
    public var availableForFarm: Int {
        let menu1    = stall.menuCooks.filter { $0 == 1 }.count
        let cashier1 = stall.cashierTier == 1 ? stall.cashierCount : 0
        return stall.tier1Count - farmAssigned - menu1 - cashier1
    }

    public var availableFarmers: Int     { stall.farmerCount - farmersAssigned }
    public var availableVeteranAlbas: Int { stall.veteranAlbaCount - veteranAlbasAssigned }

    public func hireFarmer() {
        let cost = UpgradeDefinitions.farmer[0].coinCost
        guard stall.coins >= cost else { return }
        stall.coins -= cost
        stall.farmerCount += 1
        stall.farmerIdleEnergies.append(1.0)
        save()
    }

    public func hireVeteranAlba() {
        let cost = UpgradeDefinitions.veteranAlba[0].coinCost
        guard stall.coins >= cost else { return }
        stall.coins -= cost
        stall.veteranAlbaCount += 1
        stall.veteranAlbaIdleEnergies.append(1.0)
        save()
    }

    /// Toggle a farm worker of any type on/off a plot.
    public func toggleFarmWorker(plotIndex: Int, workerType: FarmWorkerType = .alba, displayedEnergy: Double? = nil, addToIdle: Bool = true, directEnergy: Double? = nil) {
        guard plotIndex < farm.plots.count else { return }
        if farm.plots[plotIndex].hasWorker {
            let energy = displayedEnergy ?? farm.plots[plotIndex].workerEnergy
            if addToIdle {
                switch farm.plots[plotIndex].workerType {
                case .alba:        pushIdleEnergy(energy, for: 1)
                case .farmer:      stall.farmerIdleEnergies.append(energy)
                case .veteranAlba: stall.veteranAlbaIdleEnergies.append(energy)
                case .none: break
                }
            }
            farm.plots[plotIndex].workerEnergy = 1.0
            farm.plots[plotIndex].workerType   = .none
        } else {
            let energy: Double
            switch workerType {
            case .alba:
                guard availableForFarm > 0 else { return }
                energy = directEnergy ?? popIdleEnergy(for: 1)
            case .farmer:
                guard availableFarmers > 0 else { return }
                energy = directEnergy ?? (stall.farmerIdleEnergies.isEmpty ? 1.0 : stall.farmerIdleEnergies.removeFirst())
            case .veteranAlba:
                guard availableVeteranAlbas > 0 else { return }
                energy = directEnergy ?? (stall.veteranAlbaIdleEnergies.isEmpty ? 1.0 : stall.veteranAlbaIdleEnergies.removeFirst())
            case .none: return
            }
            farm.plots[plotIndex].workerEnergy = energy
            farm.plots[plotIndex].workerType   = workerType
        }
        stall.farmWorkers = farmAssigned
        save()
    }

    /// Legacy shim — toggles an alba worker.
    public func toggleWorker(plotIndex: Int, displayedEnergy: Double? = nil, addToIdle: Bool = true, directEnergy: Double? = nil) {
        toggleFarmWorker(plotIndex: plotIndex, workerType: .alba, displayedEnergy: displayedEnergy, addToIdle: addToIdle, directEnergy: directEnergy)
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
        case 5: stall.veteranAlbaCount
        default: 0
        }
    }

    /// Number of unassigned (idle) workers for a given tier.
    private func unassignedCount(for tier: Int) -> Int {
        let menuUsed    = stall.menuCooks.filter { $0 == tier }.count
        let cashierUsed = stall.cashierTier == tier ? stall.cashierCount : 0
        let farmUsed    = tier == 1 ? farmAssigned : (tier == 5 ? veteranAlbasAssigned : 0)
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

    /// Calculate offline earnings (cold start or bg→fg) using the stored live earning rate.
    /// Does NOT add coins or change lastActiveDate.
    public func calculateOfflineEarnings() {
        guard !isSimulationPaused,
              !progress.isFirstLaunch,
              progress.isShopNameSet else { return }   // tutorial/naming time is not offline time
        guard let lastActive = progress.lastActiveDate else {
            print("[Offline] first launch — seeding lastActiveDate")
            progress.lastActiveDate = Date()
            save()
            return
        }
        let rate = progress.earningRate
        guard rate > 0 else {
            print("[Offline] earningRate=0 — no earnings recorded yet")
            return
        }
        let elapsed = min(Date().timeIntervalSince(lastActive), OfflineProgressSystem.maxOfflineHours * 3600)
        let earned = rate * elapsed * OfflineProgressSystem.offlineEfficiency
        print("[Offline] lastActive=\(lastActive), elapsed=\(Int(elapsed))s, rate=\(String(format:"%.4f",rate))/s, earned=\(Int(earned))")
        offlineEarnings = earned >= 1 ? earned : 0
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
        // Grace until the first sale: the manual cook (10 s) is slower than
        // customer patience (8 s), so a new player cannot avoid these.
        if progress.totalServed > 0 {
            progress.rating = max(1.0, progress.rating - 0.05)
        }
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

        case .location:
            let nextTier = stall.locationTier + 1
            guard nextTier < UpgradeDefinitions.location.count else { return }
            let next = UpgradeDefinitions.location[nextTier]
            guard stall.stallTier >= next.requiredStallTier,
                  stall.coins >= next.coinCost else { return }
            stall.coins -= next.coinCost
            stall.locationTier = nextTier
            save()
            NotificationCenter.default.post(
                name: .locationTierDidChange, object: self, userInfo: ["tier": nextTier])
            return
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
        if let d = try? JSONEncoder().encode(stall)    { defaults.set(d, forKey: SaveBlob.stall.key) }
        if let d = try? JSONEncoder().encode(farm)     { defaults.set(d, forKey: SaveBlob.farm.key) }
        if let d = try? JSONEncoder().encode(progress) { defaults.set(d, forKey: SaveBlob.progress.key) }
    }
}
