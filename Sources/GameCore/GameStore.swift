import Foundation
import Combine

public enum UpgradeType: Equatable {
    case staff, menu, stall, farm, location, warehouse, renovation
    case recipe(menuIndex: Int)
}

@MainActor
public final class GameStore: ObservableObject {

    @Published public var stall: StallState
    @Published public var farm: FarmState
    @Published public var progress: PlayerProgress
    @Published public var offlineEarnings: Double = 0
    /// Daily missions. Not part of a run: `startNewRun` leaves them alone.
    @Published public private(set) var missionState: MissionState
    /// 봄바람 부스트 end and cooldown, as wall-clock dates so a killed app neither refunds nor loses them.
    @Published public private(set) var adState = AdRewardState()
    /// The latest payday, for the HUD toast and sound. `id` changes on every payday that owed something.
    @Published public private(set) var payday: Payday?

    public struct Payday: Equatable {
        public let id: Int
        public let paid: Double
        public let paidCount: Int
        public let unpaidCount: Int
    }
    private var paydayCount = 0
    /// The latest level-ups, for the HUD toast and sound.
    @Published public private(set) var levelUps: LevelUps?
    private var levelUpCount = 0

    /// Set by the UI while the tutorial or shop-name overlay is up. Frozen
    /// time: `tick` is a no-op and offline earnings are not computed, so a
    /// player reading the tutorial loses no coins or rating. Not persisted.
    public var isSimulationPaused = false {
        didSet {
            guard oldValue, !isSimulationPaused else { return }
            progress.lastActiveDate = Date()
            transients.earningWindowCoins = 0
            transients.earningWindowTime  = 0
            transients.activitySaveTimer  = 0
        }
    }

    /// The persisted blobs. `corruptKey` keeps the raw bytes of the latest blob that failed
    /// to decode, so the next `save()` cannot destroy the only copy.
    enum SaveBlob: String {
        case stall, farm, progress, missions
        var key: String { "gameStore.\(rawValue)" }
        var corruptKey: String { "gameStore.\(rawValue).corrupt" }
    }

    /// False while the scene is inactive or backgrounded; set from `scenePhase`. Only gates
    /// `progress.totalPlaySeconds`: the scene's own update loop already stops off-screen.
    public var isAppActive = true

    /// A gift dialog is open: the crate must not leave while the player decides or an ad plays.
    /// While held, the crate's payout is frozen at the amount the dialog shows.
    public var isGiftHeld = false {
        didSet {
            guard isGiftHeld != oldValue else { return }
            transients.giftOfferAmount = isGiftHeld ? liveGiftAmount : nil
        }
    }

    private let defaults: UserDefaults
    static let adStateKey = "gameStore.adRewards"

    /// Everything the simulation keeps in memory that is not in the three blobs. One value type
    /// so `startNewRun` resets it by assigning a fresh one: a field added here resets by default.
    private struct RunTransients {
        var cookAccumulators: [Double] = [0, 0, 0]       // per-menu
        /// In-flight manual (tap) cook progress (0..<1), keyed by menu index: presence of a key
        /// means a manual cook is running for that index. A cook in flight when the app dies is lost.
        var manualCookProgress: [Int: Double] = [:]
        /// Seconds the cashier still counts as busy after a sale.
        var cashierBusyRemaining: Double = 0
        var activitySaveTimer: Double = 0                // flush lastActiveDate + earningRate to disk every 5s
        var earningWindowCoins: Double = 0               // coins earned in current 5s window
        var earningWindowTime: Double = 0                // time elapsed in current window
        var fever = FeverState()
        var weather = WeatherState()
        var missionCheckTimer: Double = 0                // day rollover is checked once a second
        /// Seconds an uncollected golden plot has been ripe while the app was active, by plot index.
        var goldenAge: [Int: Double] = [:]
        /// Sale coins taken during the current or latest fever; reset when the next one starts.
        var feverEarned: Double = 0
        /// Seconds until the fever recharge ad is offered again.
        var adFeverCooldown: Double = 0
        /// Active play seconds since the last crate left the yard (or since launch).
        var giftClock: Double = 0
        /// Interval the clock must reach, rolled the first time a crate is allowed.
        var giftDue: Double?
        var giftRemaining: Double = 0
        var giftOfferAmount: Double?
        /// Seconds of simulated time (sum of `tick` deltas): the clock the tap cooldowns run on, so
        /// they hold at any `-dotSpeed` and tests drive them with `tick`.
        var clock: Double = 0
        var lastHurry: [Int: Double] = [:]
        var lastWater: [Int: Double] = [:]
        var lastWake: [WorkerTarget: Double] = [:]
        /// Clock time at which the flyer can be used again.
        var flyerReadyAt: Double = 0
        /// A flyer tap the scene has not answered yet.
        var flyerRequested = false
    }
    private var transients = RunTransients()

    // MARK: - Energy constants
    private static let energyRestoreRate:      Double = 1.0 / 90.0    // full in 1.5 min (when idle)
    private static let energyPerCook:          Double = 1.0 / 300.0   // 300 items per full bar
    private static let energyPerCashierSale:   Double = 1.0 / 60.0   // 60 sales per full bar
    private static let cashierBusyWindow:      Double = 2.0          // no restore this long after a sale
    private static let energyPerHarvest:       Double = 1.0 / 8.0     // 8 harvests per full bar
    /// Drained energy is a sum of fractions, so "reached 0" is a tolerance, not an exact compare.
    private static let exhaustedEnergy:        Double = 1e-6

    // MARK: - Offline constants
    static let maxOfflineHours: Double = 8
    /// Offline earnings rate relative to real-time: keeps progression rewarding but not trivial.
    static let offlineEfficiency: Double = 0.25

    /// Returns a value in 0..<1. Injected so golden, gourmet and weather rolls are testable.
    public typealias RandomSource = () -> Double

    private var persistedMissions: MissionState?
    private let random: RandomSource
    private let now: () -> Date
    private let calendar: Calendar

    public init(defaults: UserDefaults = .standard,
                random: @escaping RandomSource = { Double.random(in: 0..<1) },
                now: @escaping () -> Date = Date.init,
                calendar: Calendar = .current) {
        self.defaults = defaults
        self.random = random
        self.now = now
        self.calendar = calendar

        self.stall    = Self.load(StallState.self, blob: .stall, from: defaults) ?? StallState()
        self.farm     = Self.load(FarmState.self, blob: .farm, from: defaults) ?? FarmState()
        self.progress = Self.load(PlayerProgress.self, blob: .progress, from: defaults) ?? PlayerProgress()
        let loadedMissions = Self.load(MissionState.self, blob: .missions, from: defaults)
        if let data = defaults.data(forKey: Self.adStateKey),
           let state = try? JSONDecoder().decode(AdRewardState.self, from: data) {
            self.adState = state
        }
        self.missionState = loadedMissions ?? MissionState()
        self.persistedMissions = loadedMissions
        normalizeIdlePools()
        if let marker = defaults.object(forKey: Self.springInFlightKey) {
            if let target = marker as? Int {
                recoverInterruptedSpring(targetPrestigeCount: target)
            } else {
                defaults.removeObject(forKey: Self.springInFlightKey)
            }
        }
        refreshMissionsIfNeeded()
    }

    /// nil when the blob is absent or undecodable. Whenever the stored bytes are damaged, whether
    /// the whole blob (decode throws) or only parts the tolerant decoders had to default or drop,
    /// they are copied to `corruptKey` before the value is used, so the next `save()` cannot
    /// destroy the only copy. Absent keys and `{}` are not damage.
    private static func load<T: Decodable>(_ type: T.Type, blob: SaveBlob, from defaults: UserDefaults) -> T? {
        guard let object = defaults.object(forKey: blob.key) else { return nil }
        guard let data = object as? Data else {
            // A foreign non-Data write: keep a best-effort plist rendering, then start fresh.
            if let rendered = try? PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0) {
                keepBackup(rendered, blob: blob, in: defaults)
            }
            SaveDiagnostics.corruptBlob(blob.rawValue, bytes: 0)
            return nil
        }
        do {
            let (value, mismatches) = try SaveDiagnostics.countingMismatches {
                try JSONDecoder().decode(type, from: data)
            }
            if mismatches > 0 { keepBackup(data, blob: blob, in: defaults) }
            return value
        } catch {
            keepBackup(data, blob: blob, in: defaults)
            SaveDiagnostics.corruptBlob(blob.rawValue, bytes: data.count)
            return nil
        }
    }

    /// Latest-only. An empty copy never displaces a non-empty one: a 0-byte blob carries nothing
    /// worth keeping, and the older backup may be the only good data left.
    private static func keepBackup(_ data: Data, blob: SaveBlob, in defaults: UserDefaults) {
        let existing = defaults.data(forKey: blob.corruptKey)
        if data.isEmpty, let existing, !existing.isEmpty { return }
        if existing != data { defaults.set(data, forKey: blob.corruptKey) }
    }

    /// Raw bytes of the latest undecodable copy of `blob`, if any.
    func corruptBackup(of blob: SaveBlob) -> Data? {
        defaults.data(forKey: blob.corruptKey)
    }

    // MARK: - Energy

    private func energyMultiplier(_ energy: Double) -> Double {
        max(0.2, energy);   // minimum 20% speed when exhausted
    }

    private struct IdlePools {
        let energies: WritableKeyPath<StallState, [Double]>
        let levels: WritableKeyPath<StallState, [Int]>
        let exp: WritableKeyPath<StallState, [Double]>
    }

    /// A tier's idle pools: energy, level and experience, always the same length (one entry per benched worker).
    private func idlePools(_ tier: Int) -> IdlePools? {
        switch tier {
        case 1: IdlePools(energies: \.tier1IdleEnergies, levels: \.tier1IdleLevels, exp: \.tier1IdleExp)
        case 2: IdlePools(energies: \.tier2IdleEnergies, levels: \.tier2IdleLevels, exp: \.tier2IdleExp)
        case 3: IdlePools(energies: \.tier3IdleEnergies, levels: \.tier3IdleLevels, exp: \.tier3IdleExp)
        case 4: IdlePools(energies: \.farmerIdleEnergies, levels: \.farmerIdleLevels, exp: \.farmerIdleExp)
        case 5: IdlePools(energies: \.veteranAlbaIdleEnergies, levels: \.veteranAlbaIdleLevels, exp: \.veteranAlbaIdleExp)
        default: nil
        }
    }

    /// Pads the level and experience pools to the energy pool, so a pool written without them reads as Lv.1, 0 exp.
    private func alignLevels(_ pools: IdlePools) {
        let count = stall[keyPath: pools.energies].count
        func fit<T>(_ path: WritableKeyPath<StallState, [T]>, _ fill: T) {
            let missing = count - stall[keyPath: path].count
            if missing > 0 { stall[keyPath: path] += Array(repeating: fill, count: missing) }
            else if missing < 0 { stall[keyPath: path].removeLast(-missing) }
        }
        fit(pools.levels, 1)
        fit(pools.exp, 0.0)
    }

    /// Takes one benched worker of `tier` out of the pools: the oldest, or the one at `index`
    /// (the row the player tapped, since levels make workers differ). An empty pool gives a fresh Lv.1.
    @discardableResult
    private func popIdle(for tier: Int, at index: Int = 0) -> (energy: Double, skill: StaffSkill) {
        guard let pools = idlePools(tier), !stall[keyPath: pools.energies].isEmpty else { return (1.0, StaffSkill()) }
        alignLevels(pools)
        let i = min(max(index, 0), stall[keyPath: pools.energies].count - 1)
        return (stall[keyPath: pools.energies].remove(at: i),
                StaffSkill(level: stall[keyPath: pools.levels].remove(at: i), exp: stall[keyPath: pools.exp].remove(at: i)))
    }

    /// The worker a post receives: carried straight from another post when `directEnergy` is given,
    /// otherwise taken from the bench.
    private func takeWorker(tier: Int, idleIndex: Int, directEnergy: Double?, directSkill: StaffSkill?) -> (energy: Double, skill: StaffSkill) {
        if let directEnergy { return (directEnergy, directSkill ?? StaffSkill()) }
        return popIdle(for: tier, at: idleIndex)
    }

    /// Benches a worker with her current energy, level and experience.
    /// Values below 5% are snapped to exactly 0.0 so the bar shows cleanly empty.
    private func pushIdle(energy: Double, skill: StaffSkill = StaffSkill(), for tier: Int) {
        guard let pools = idlePools(tier) else { return }
        alignLevels(pools)
        stall[keyPath: pools.energies].append(tier == 4 || energy >= 0.05 ? energy : 0.0)
        stall[keyPath: pools.levels].append(StaffLevelSystem.clamped(skill.level))
        stall[keyPath: pools.exp].append(max(0, skill.exp))
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

        for tier in 1...5 { if let pools = idlePools(tier) { alignLevels(pools) } }
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
        // Play time is held in memory and rides the 5 s activity save below; no extra disk writes.
        if isAppActive { progress.totalPlaySeconds += deltaTime }
        settleWagesIfDue()
        transients.clock += deltaTime
        FeverSystem.tick(&transients.fever, deltaTime: deltaTime)
        transients.adFeverCooldown = max(0, transients.adFeverCooldown - deltaTime)
        advanceGift(deltaTime: deltaTime)
        WeatherSystem.advance(&transients.weather, deltaTime: deltaTime, roll: random)
        transients.missionCheckTimer += deltaTime
        if transients.missionCheckTimer >= 1 {
            transients.missionCheckTimer = 0
            refreshMissionsIfNeeded()
        }
        let growRate   = FarmSystem.growthRate(for: farm) * WeatherSystem.growthMultiplier(transients.weather)
            * (FeverSystem.isActive(transients.fever) ? FeverSystem.growthMultiplier : 1)

        let activePlots = FarmSystem.activePlotCount(for: farm);
        accrueExperience(deltaTime: deltaTime)

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
            if !isWorking || stall.menuCookResting[i] {
                stall.menuCookEnergy[i] = min(1, stall.menuCookEnergy[i] + Self.energyRestoreRate * deltaTime)
                if stall.menuCookResting[i], stall.menuCookEnergy[i] >= 1 { stall.menuCookResting[i] = false }
            }
        }
        // Cashier restores once no sale landed for `cashierBusyWindow`; depletion is per sale (see `sellItem`)
        transients.cashierBusyRemaining = max(0, transients.cashierBusyRemaining - deltaTime)
        if stall.cashierCount == 0 || stall.cashierResting || transients.cashierBusyRemaining == 0 {
            stall.cashierEnergy = min(1, stall.cashierEnergy + Self.energyRestoreRate * deltaTime)
            if stall.cashierResting, stall.cashierEnergy >= 1 { stall.cashierResting = false }
        }
        for i in 0..<farm.plots.count {
            if !farm.plots[i].hasWorker || farm.plots[i].workerResting || !farm.plots[i].isPlanted || !farm.plots[i].isReady {
                // Restore when unassigned, asleep, OR waiting for crop to grow
                farm.plots[i].workerEnergy = min(1, farm.plots[i].workerEnergy + Self.energyRestoreRate * deltaTime)
                if farm.plots[i].workerResting, farm.plots[i].workerEnergy >= 1 { farm.plots[i].workerResting = false }
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
            let skill = farm.plots[i].hasWorker
                ? StaffLevelSystem.speedMultiplier(level: farm.plots[i].workerLevel) : 1.0
            farm.plots[i].growth = min(farm.plots[i].growth + growRate * boost * skill * deltaTime, 1.0)
            if farm.plots[i].isReady, random() < Self.goldenChance { farm.plots[i].isGolden = true }
        }
        advanceGoldenAges(deltaTime: deltaTime)

        // Farm workers (tier1 only) auto-harvest and replant
        for i in 0..<min(activePlots, farm.plots.count) {
            guard farm.plots[i].hasWorker, !farm.plots[i].workerResting else { continue }
            if farm.plots[i].isReady {
                guard stall.warehouse < stall.warehouseCapacity else { continue }
                // A golden crop waits for the player's finger; its bonus only pays on a manual harvest.
                if farm.plots[i].isGolden, (transients.goldenAge[i] ?? 0) < Self.goldenWorkerGraceSeconds { continue }
                stall.warehouse += FarmSystem.harvestYield
                farm.plots[i].growth   = 0
                farm.plots[i].isPlanted = false
                farm.plots[i].isGolden = false
                advanceMissions(.harvest)
                farm.plots[i].workerEnergy = max(0, farm.plots[i].workerEnergy - Self.energyPerHarvest)
                if farm.plots[i].workerEnergy < Self.exhaustedEnergy { farm.plots[i].workerResting = true; continue }
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
            let skill = StaffLevelSystem.speedMultiplier(level: stall.menuCookLevels[safe: i] ?? 1)
            transients.cookAccumulators[i] += cookRate(forTier: tier) * skill * energyMultiplier(energy) * deltaTime;
            while transients.cookAccumulators[i] >= 1.0,
                  !stall.menuCookResting[i],
                  stall.warehouse > 0,
                  stall.menuStock[i] < maxStock {
                transients.cookAccumulators[i] -= 1.0
                stall.warehouse    -= 1
                stall.menuStock[i] += 1
                advanceMissions(.cookDishes)
                stall.menuCookEnergy[i] = max(0, stall.menuCookEnergy[i] - Self.energyPerCook)
                if stall.menuCookEnergy[i] < Self.exhaustedEnergy { stall.menuCookResting[i] = true }
            }
        }

        // Manual (self-serve) cook: one running session per menu index at the fixed `manualCookRate`.
        // A session keeps producing portion after portion (see `settleManualCook`); a hired cook
        // takes over the dish, so a session left running for it ends.
        for menuIndex in transients.manualCookProgress.keys.sorted() {
            if hasWorkingCook(menuIndex: menuIndex) {
                transients.manualCookProgress[menuIndex] = nil
                continue
            }
            transients.manualCookProgress[menuIndex, default: 0] += Self.manualCookRate * deltaTime
            settleManualCook(menuIndex: menuIndex)
        }

        // pendingCoins always pays out immediately, cashier or not: the tap-a-bubble
        // collect was removed, and a hired cashier must never collect slower than none.
        if stall.pendingCoins > 0 {
            collectCoins()
        }

        // Rating above the floor slowly decays — active serving easily overcomes it, idle play drifts down
        if progress.rating > Self.ratingRecoveryFloor {
            let decayed = progress.rating - Self.ratingDecayPerSecond * max(1, progress.rating - 2) * deltaTime
            progress.rating = max(Self.ratingRecoveryFloor, decayed)
        }

        // Persist lastActiveDate + earningRate every 5 s
        if offlineEarnings == 0 {
            transients.earningWindowTime += deltaTime
            transients.activitySaveTimer += deltaTime
            if transients.activitySaveTimer >= 5 {
                if transients.earningWindowTime > 0, transients.earningWindowCoins > 0 {
                    let sample = transients.earningWindowCoins / transients.earningWindowTime
                    // Exponential moving average: weight new sample at 30%
                    // Only update when coins were actually earned — idle windows must not decay the rate
                    progress.earningRate = progress.earningRate == 0
                        ? sample
                        : progress.earningRate * 0.7 + sample * 0.3
                }
                transients.earningWindowCoins = 0
                transients.earningWindowTime  = 0
                transients.activitySaveTimer  = 0
                progress.lastActiveDate = Date()
                save()
            }
        }
    }

    /// One settlement per day boundary crossed, in order, so a long tick cannot skip a payday and
    /// a day never pays twice. Offline time is not play time and never reaches this.
    private func settleWagesIfDue() {
        let today = DayCycle.dayIndex(playSeconds: progress.totalPlaySeconds)
        guard today > progress.lastWageDay else { return }
        normalizeIdlePools()
        var total = WageSystem.Settlement()
        while progress.lastWageDay < today {
            progress.lastWageDay += 1
            let day = WageSystem.settle(stall: &stall, farm: &farm)
            total.paid += day.paid; total.paidCount += day.paidCount; total.unpaidCount += day.unpaidCount
        }
        guard total.paidCount + total.unpaidCount > 0 else { return }
        progress.totalWagesPaid += total.paid
        paydayCount += 1
        payday = Payday(id: paydayCount, paid: total.paid, paidCount: total.paidCount, unpaidCount: total.unpaidCount)
        save()
    }

    /// What the next payday will cost with today's staff.
    public var dailyPayroll: Double { WageSystem.payroll(stall: stall, farm: farm) }

    /// Play seconds until the next payday.
    public var secondsUntilPayday: Double { DayCycle.secondsUntilNextDay(playSeconds: progress.totalPlaySeconds) }

    private func advanceGoldenAges(deltaTime: Double) {
        for i in farm.plots.indices {
            guard farm.plots[i].isReady, farm.plots[i].isGolden else {
                transients.goldenAge[i] = nil
                continue
            }
            // Only app-active time counts: a golden crop must not ripen and be taken while the player is away.
            transients.goldenAge[i, default: 0] += isAppActive ? deltaTime : 0
        }
    }

    /// Lands every portion the session's progress has paid for. Preconditions are re-checked per
    /// portion (the warehouse can empty or the stock fill while it cooks): a session that can no
    /// longer produce ends without one. It also ends on reaching `selfServeStock`, and stays
    /// running only while the next portion is possible.
    private func settleManualCook(menuIndex: Int) {
        while let progress = transients.manualCookProgress[menuIndex], progress >= 1 {
            guard canManualCook(menuIndex: menuIndex) else {
                transients.manualCookProgress[menuIndex] = nil
                return
            }
            completeManualCook(menuIndex: menuIndex)
            guard stall.menuStock[menuIndex] < Self.selfServeStock, canManualCook(menuIndex: menuIndex) else {
                transients.manualCookProgress[menuIndex] = nil
                return
            }
            transients.manualCookProgress[menuIndex] = progress - 1
        }
    }

    private func completeManualCook(menuIndex: Int) {
        stall.warehouse -= 1
        stall.menuStock[menuIndex] += 1
        advanceMissions(.cookDishes)
        save()
    }

    /// True for `cashierBusyWindow` seconds after each sale, so the cashier figure keeps its
    /// working pose long enough to read. Transient; never saved.
    public var cashierRecentlySold: Bool { transients.cashierBusyRemaining > 0 }

    // MARK: - Collect

    public func collectCoins() {
        stall.coins += stall.pendingCoins
        progress.totalEarned += stall.pendingCoins
        stall.pendingCoins = 0
        save()
    }

    // MARK: - Sell

    public func sellItem(menuIndex: Int, isGourmet: Bool = false) -> Double? {
        guard menuIndex < stall.menuStock.count,
              stall.menuStock[menuIndex] > 0 else { return nil }
        stall.menuStock[menuIndex] -= 1
        // Priced before this sale's energy cost, so the sale that tires her still earns the bonus.
        let basePrice = EarningsSystem.salePrice(for: stall, menuIndex: menuIndex, prestigeCount: progress.prestigeCount)
        let price = EarningsSystem.salePrice(
            for: stall, menuIndex: menuIndex, prestigeCount: progress.prestigeCount,
            feverMultiplier: FeverSystem.isActive(transients.fever) ? FeverSystem.priceMultiplier : 1,
            gourmetMultiplier: isGourmet ? EarningsSystem.gourmetMultiplier : 1,
            boostMultiplier: isBoostActive ? AdBoostSystem.priceMultiplier : 1,
            weatherMultiplier: weatherEffect.price)
        if stall.cashierCount > 0, !stall.cashierResting {
            stall.cashierEnergy = max(0, stall.cashierEnergy - Self.energyPerCashierSale)
            if stall.cashierEnergy < Self.exhaustedEnergy { stall.cashierResting = true }
            transients.cashierBusyRemaining = Self.cashierBusyWindow
        }
        stall.pendingCoins += price
        if isFeverActive { transients.feverEarned += price }
        // Fever, boost and gourmet are active-play bonuses: offline earnings stay priced on the base economy.
        transients.earningWindowCoins += basePrice
        advanceMissions(.earnCoins, by: Int(price.rounded()))
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
        farm.plots[plotIndex].isGolden  = false
        save()
    }

    public struct HarvestResult: Equatable {
        public let isGolden: Bool
        /// Coins paid straight to the wallet on top of the crop; 0 unless golden.
        public let bonusCoins: Double
    }

    static let goldenChance: Double = 0.06
    static let goldenBonusSales: Double = 15
    /// A golden crop is also worth this many seconds of live income, so it still matters once the
    /// bank dwarfs 15 sales.
    static let goldenBonusIncomeSeconds: Double = 45
    /// How long a worker leaves a ripe golden plot for the player to tap.
    public static let goldenWorkerGraceSeconds: Double = 20

    /// Manual harvest. nil when nothing was harvested. A golden plot pays `goldenBonusSales`
    /// sales of the best unlocked menu on top of the normal yield.
    @discardableResult
    public func harvest(plotIndex: Int) -> HarvestResult? {
        guard plotIndex < farm.plots.count,
              farm.plots[plotIndex].isReady,
              stall.warehouse < stall.warehouseCapacity else { return nil }
        let isGolden = farm.plots[plotIndex].isGolden
        stall.warehouse += FarmSystem.harvestYield
        farm.plots[plotIndex].growth    = 0
        farm.plots[plotIndex].isPlanted = false
        farm.plots[plotIndex].isGolden  = false
        var bonus = 0.0
        if isGolden {
            bonus = Self.goldenBonus(stall: stall, progress: progress)
            stall.coins += bonus
            progress.totalEarned += bonus
            progress.totalGoldenHarvested += 1
            advanceMissions(.earnCoins, by: Int(bonus.rounded()))
        }
        advanceMissions(.harvest)
        save()
        return HarvestResult(isGolden: isGolden, bonusCoins: bonus)
    }

    /// max(15 best sales, 45 s of live income).
    static func goldenBonus(stall: StallState, progress: PlayerProgress) -> Double {
        max(goldenBonusSales * EarningsSystem.salePrice(
                for: stall, menuIndex: stall.menuTier, prestigeCount: progress.prestigeCount),
            goldenBonusIncomeSeconds * progress.earningRate)
    }

    // MARK: - Tips

    static let tipChance: Double = 0.20
    static let tipFeverChance: Double = 0.35
    static let tipSaleShare: Double = 0.5
    static let gourmetTipSaleShare: Double = 1.0

    /// Whether a served customer leaves a tip coin on the street. Gourmets always do and consume no roll.
    public func rollTip(isGourmet: Bool) -> Bool {
        if isGourmet { return true }
        return random() < (isFeverActive ? Self.tipFeverChance : Self.tipChance) + weatherEffect.tipChance
    }

    public static func tipAmount(forSale price: Double, isGourmet: Bool) -> Double {
        price * (isGourmet ? gourmetTipSaleShare : tipSaleShare)
    }

    /// Pays a tapped tip. It is earned, but not part of `earningWindowCoins`: a tap bonus must not
    /// inflate the offline rate.
    public func collectTip(amount: Double) {
        guard amount > 0 else { return }
        stall.coins += amount
        progress.totalEarned += amount
        progress.totalTipsCollected += 1
        advanceMissions(.earnCoins, by: Int(amount.rounded()))
        save()
    }

    // MARK: - Fever

    public var feverCharge: Double { transients.fever.charge }
    public var isFeverReady: Bool { FeverSystem.isReady(transients.fever) }
    public var isFeverActive: Bool { FeverSystem.isActive(transients.fever) }
    public var feverRemaining: Double { transients.fever.remaining }
    /// Coins the current (or just-ended) fever's sales paid.
    public var feverEarned: Double { transients.feverEarned }

    /// False, changing nothing, unless the gauge is full and fever is not already running.
    @discardableResult
    public func startFever() -> Bool {
        guard FeverSystem.start(&transients.fever) else { return false }
        let maxStock = EarningsSystem.maxStock(for: stall)
        for i in stall.menuStock.indices where RecipeSystem.isUnlocked(menuIndex: i, stall: stall) {
            stall.menuStock[i] = min(maxStock, stall.menuStock[i] + FeverSystem.startingPortions)
        }
        transients.feverEarned = 0
        progress.totalFevers += 1
        advanceMissions(.triggerFever)
        save()
        return true
    }

    // MARK: - Flyer (전단지)

    /// Offered while the HUD shows a rating under 3.0, the stretch where customers are sparse.
    public var isFlyerAvailable: Bool {
        MissionSystem.displayedRating(progress.rating) < Self.ratingRecoveryFloor
    }

    public var flyerCooldownRemaining: Double { max(0, transients.flyerReadyAt - transients.clock) }

    /// 0...1 progress of the cooldown, 1 when ready.
    public var flyerCooldownProgress: Double { 1 - min(1, flyerCooldownRemaining / Self.flyerCooldown) }

    public var isFlyerReady: Bool {
        isFlyerAvailable && flyerCooldownRemaining == 0 && !transients.flyerRequested
    }

    /// A tap. The store only decides whether it is accepted; the scene performs the spawn and then
    /// calls `completeFlyer` or `declineFlyer`, so a tap the queue could not take costs no cooldown.
    @discardableResult
    public func requestFlyer() -> Bool {
        guard isFlyerReady, !isSimulationPaused else { return false }
        transients.flyerRequested = true
        return true
    }

    public var hasFlyerRequest: Bool { transients.flyerRequested }

    public func completeFlyer() {
        guard transients.flyerRequested else { return }
        transients.flyerRequested = false
        transients.flyerReadyAt = transients.clock + Self.flyerCooldown
    }

    public func declineFlyer() { transients.flyerRequested = false }

    public static let flyerCooldown: Double = baseIntervalAtThree

    // MARK: - Grand reopening (리뉴얼 오픈)

    private var bestSalePrice: Double {
        EarningsSystem.salePrice(for: stall, menuIndex: stall.menuTier, prestigeCount: progress.prestigeCount)
    }

    public var renewalFee: Double { RenewalSystem.fee(bestSalePrice: bestSalePrice) }

    public var renewalCooldownRemaining: Double {
        guard let last = progress.lastRenewalPlaySeconds else { return 0 }
        return min(RenewalSystem.cooldown, max(0, RenewalSystem.cooldown - (progress.totalPlaySeconds - last)))
    }

    public var isRenewalAvailable: Bool {
        MissionSystem.displayedRating(progress.rating) < RenewalSystem.eligibleBelowRating
            && renewalCooldownRemaining == 0
    }

    public var canAffordRenewal: Bool { stall.coins >= renewalFee }

    /// Sets the rating to 3.0 and nothing else but the fee. False, changing nothing, when it is not
    /// offered or the coins are short. The ad path is the caller's to earn: pass `.ad` once it played.
    @discardableResult
    public func renewShop(payment: RenewalSystem.Payment) -> Bool {
        guard isRenewalAvailable else { return false }
        if payment == .coins {
            let fee = renewalFee
            guard stall.coins >= fee else { return false }
            stall.coins -= fee
        }
        progress.rating = RenewalSystem.resultingRating
        progress.lastRenewalPlaySeconds = progress.totalPlaySeconds
        save()
        return true
    }

    // MARK: - Rewarded placements

    private var hasPassedAdGrace: Bool { progress.totalPlaySeconds >= AdBoostSystem.graceSeconds }

    /// The fever recharge is offered while the gauge is under `AdBoostSystem.feverAdMaxCharge` and fever
    /// is not running, off cooldown, and after the install's first minutes.
    public var isFeverAdAvailable: Bool {
        hasPassedAdGrace && !isFeverActive && transients.fever.charge < AdBoostSystem.feverAdMaxCharge
            && transients.adFeverCooldown <= 0
    }

    /// The player closed the offer without watching: the button stays away for a while.
    public func declineFeverAd() {
        transients.adFeverCooldown = max(transients.adFeverCooldown, AdBoostSystem.feverDeclineCooldown)
    }

    public var adFeverCooldownRemaining: Double { transients.adFeverCooldown }

    /// The reward of the fever recharge ad: fills the gauge. False, changing nothing, when not offered.
    @discardableResult
    public func claimFeverAdCharge() -> Bool {
        guard isFeverAdAvailable else { return false }
        transients.fever.charge = 1
        transients.fever.secondsSinceSale = 0
        transients.adFeverCooldown = AdBoostSystem.feverCooldown
        return true
    }

    public var boostRemaining: Double {
        max(0, adState.boostEndsAt?.timeIntervalSince(now()) ?? 0)
    }
    public var isBoostActive: Bool { boostRemaining > 0 }

    /// Seconds until a boost can be bought again; 0 while one is running or when none is cooling.
    public var boostCooldownRemaining: Double {
        guard !isBoostActive else { return 0 }
        return max(0, adState.boostCooldownEndsAt?.timeIntervalSince(now()) ?? 0)
    }

    public var isBoostAvailable: Bool {
        hasPassedAdGrace && !isBoostActive && boostCooldownRemaining <= 0
    }

    /// A running boost can take one more ad while the banked time stays within `AdBoostSystem.maxBankedSeconds`.
    public var isBoostExtendable: Bool {
        isBoostActive && boostRemaining + AdBoostSystem.boostDuration <= AdBoostSystem.maxBankedSeconds
    }

    /// Starts 180 s of x2 sale price, or adds 180 s to a running one; the cooldown runs from the end.
    @discardableResult
    public func claimBoost() -> Bool {
        let start: Date
        if isBoostAvailable {
            start = now()
        } else if isBoostExtendable, let endsAt = adState.boostEndsAt {
            start = endsAt
        } else {
            return false
        }
        let end = start.addingTimeInterval(AdBoostSystem.boostDuration)
        adState.boostEndsAt = end
        adState.boostCooldownEndsAt = end.addingTimeInterval(AdBoostSystem.boostCooldown)
        saveAdState()
        return true
    }

    public var isGiftPresent: Bool { transients.giftRemaining > 0 }
    public var giftRemaining: Double { transients.giftRemaining }

    /// Coins the crate pays right now.
    public var giftAmount: Double { transients.giftOfferAmount ?? liveGiftAmount }

    private var liveGiftAmount: Double {
        GiftSystem.amount(
            bestSalePrice: EarningsSystem.salePrice(for: stall, menuIndex: stall.menuTier,
                                                    prestigeCount: progress.prestigeCount),
            earningRate: progress.earningRate)
    }

    private var hasHired: Bool {
        stall.staffTier > 0 || stall.farmerCount > 0 || stall.veteranAlbaCount > 0
    }

    private func advanceGift(deltaTime: Double) {
        if transients.giftRemaining > 0 {
            if !isGiftHeld { transients.giftRemaining = max(0, transients.giftRemaining - deltaTime) }
            if transients.giftRemaining == 0 { transients.giftClock = 0; transients.giftDue = nil }
            return
        }
        transients.giftClock += deltaTime
        guard progress.totalPlaySeconds >= GiftSystem.firstGiftPlaySeconds, hasHired else { return }
        let due = transients.giftDue ?? GiftSystem.interval(roll: random())
        transients.giftDue = due
        if transients.giftClock >= due { transients.giftRemaining = GiftSystem.lifetime }
    }

    /// The reward of the crate's ad. nil when no crate is in the yard.
    @discardableResult
    public func claimGift() -> Double? {
        guard isGiftPresent else { return nil }
        let amount = giftAmount
        stall.coins += amount
        progress.totalEarned += amount
        transients.giftRemaining = 0
        transients.giftClock = 0
        transients.giftDue = nil
        save()
        return amount
    }

    private func saveAdState() {
        if let d = try? JSONEncoder().encode(adState) { defaults.set(d, forKey: Self.adStateKey) }
    }

    // MARK: - Weather

    public var weather: Weather { transients.weather.weather }

    /// Seconds left of the running event; 0 while clear.
    public var weatherRemaining: Double {
        transients.weather.weather == .clear ? 0 : transients.weather.timer ?? 0
    }

    /// Seconds until the next event starts; 0 while one is running or before the first roll.
    public var secondsUntilWeather: Double {
        transients.weather.weather == .clear ? transients.weather.timer ?? 0 : 0
    }

    /// The event the current clear gap leads into; nil while one is running or before the first roll.
    public var upcomingWeather: Weather? {
        transients.weather.weather == .clear ? transients.weather.upcoming : nil
    }

    public var weatherEffect: WeatherEffect { WeatherEffect.effect(for: transients.weather.weather) }

    /// Scales how long a queued customer waits.
    public var customerPatienceMultiplier: Double { weatherEffect.patience }

    /// Scales how fast customers walk on the street.
    public var customerWalkSpeedMultiplier: Double { weatherEffect.walkSpeed }

    // MARK: - Missions

    public var missions: [Mission] { missionState.missions }

    public var unclaimedCompletedMissionCount: Int {
        missionState.missions.filter { $0.isComplete && !$0.isClaimed }.count + (missionState.isBonusReady ? 1 : 0)
    }

    public var isDailyBonusReady: Bool { missionState.isBonusReady }
    public var dailyBonusReward: Double { missionState.bonusReward }
    public var isDailyBonusClaimed: Bool { missionState.isBonusClaimed }

    /// Pays "오늘의 미션 완료" once, when every mission of the day is complete.
    @discardableResult
    public func claimDailyBonus(multiplier: Double = 1) -> Double? {
        guard missionState.isBonusReady else { return nil }
        let reward = missionState.bonusReward * multiplier
        missionState.isBonusClaimed = true
        stall.coins += reward
        progress.totalEarned += reward
        save()
        return reward
    }

    /// Pays the reward fixed at roll time, once. nil when unknown, incomplete or already claimed.
    @discardableResult
    public func claimMission(id: String, multiplier: Double = 1) -> Double? {
        guard let index = missionState.missions.firstIndex(where: { $0.id == id }),
              missionState.missions[index].isComplete,
              !missionState.missions[index].isClaimed else { return nil }
        let reward = missionState.missions[index].reward * multiplier
        missionState.missions[index].isClaimed = true
        stall.coins += reward
        progress.totalEarned += reward
        save()
        return reward
    }

    private func advanceMissions(_ kind: MissionKind, by amount: Int = 1) {
        guard amount > 0,
              let index = missionState.missions.firstIndex(where: { $0.kind == kind }),
              !missionState.missions[index].isClaimed else { return }
        let mission = missionState.missions[index]
        missionState.missions[index].progress = min(mission.target, mission.progress + amount)
    }

    #if DEBUG
    /// QA only (`-dotMissionsDone`): marks every mission of the day complete.
    public func debugCompleteAllMissions() {
        for i in missionState.missions.indices { missionState.missions[i].progress = missionState.missions[i].target }
    }

    /// QA only (`-dotGift`): puts a crate in the yard now.
    public func debugSpawnGift() { transients.giftRemaining = GiftSystem.lifetime }

    /// QA only (`-dotWeather`): starts `weather` now with a full event timer.
    public func debugStartWeather(_ weather: Weather) {
        transients.weather = WeatherState(weather: weather, timer: WeatherSystem.eventDuration)
    }

    /// QA only: re-rolls today's missions from the current stall and earning rate (a seed changes both after init).
    public func debugRerollMissions() {
        missionState = MissionState()
        refreshMissionsIfNeeded()
    }
    #endif

    func replaceMissionsForTesting(_ state: MissionState) { missionState = state }

    private func refreshMissionsIfNeeded() {
        let key = MissionSystem.dayKey(for: now(), calendar: calendar)
        guard key != missionState.dayKey || missionState.missions.isEmpty else { return }
        missionState = MissionState(dayKey: key, missions: MissionSystem.roll(
            dayKey: key, stallTier: stall.stallTier,
            earningRate: progress.earningRate, rating: progress.rating,
            bestSalePrice: EarningsSystem.salePrice(for: stall, menuIndex: stall.menuTier,
                                                    prestigeCount: progress.prestigeCount)))
        saveMissionsIfChanged()
    }

    // MARK: - Orders

    /// The dish the next customer asks for: one the shop can actually serve (`EarningsSystem.orderableMenus`).
    public func rollOrderedMenu() -> Int {
        let menus = EarningsSystem.orderableMenus(for: stall)
        return menus[min(Int(random() * Double(menus.count)), menus.count - 1)]
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
        if !hasWorkingCook(menuIndex: menuIndex), let manual = transients.manualCookProgress[menuIndex] {
            return min(max(manual, 0), 1)
        }
        guard transients.cookAccumulators.indices.contains(menuIndex) else { return 0 }
        return min(max(transients.cookAccumulators[menuIndex], 0), 1)
    }

    /// Whether a manual (tap) cook is currently running for `menuIndex` —
    /// lets a caller show the gauge even in the first instant after
    /// starting, before `cookProgress` has anything above 0 to report.
    public func isManualCookRunning(menuIndex: Int) -> Bool {
        transients.manualCookProgress[menuIndex] != nil
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
        baseSpawnInterval * (isFeverActive ? FeverSystem.spawnIntervalMultiplier : 1) * weatherEffect.spawnInterval
    }

    /// The spawn interval of a 3.0 shop. The flyer's cooldown is this same number: a flyer tap must
    /// never make a low-rated shop busier than a 3.0 one.
    static let baseIntervalAtThree: Double = 5.0

    private var baseSpawnInterval: Double {
        switch progress.rating {
        case ..<1.5: return 20.0
        case 1.5..<2.0: return 16.0
        case 2.0..<2.5: return 12.0
        case 2.5..<3.0: return 8.0
        case 3.0..<3.5: return Self.baseIntervalAtThree
        case 3.5..<4.0: return 3.5
        case 4.0..<4.5: return 2.5
        case 4.5..<5.0: return 1.8
        default:         return 1.2
        }
    }

    /// Stock a self-serve session cooks a dish up to. A tap always yields at least one portion
    /// (the cap only decides whether the session carries on), so the player can still stock past it.
    public static let selfServeStock = 5
    /// Progress a tap adds to the portion in flight: three taps are about one portion.
    public static let hurryPerTap: Double = 0.34
    public static let hurryDebounce: Double = 0.08

    public enum DishTap: Equatable {
        /// The dish is not unlocked yet.
        case locked
        /// A self-serve session began, or fever made the tap an instant portion.
        case started
        /// The portion in flight moved on.
        case hurried
        /// Nothing to cook with or no room: warehouse empty, stock full, or a cook with nothing to do.
        case blocked
        /// Closer to the last hurry than `hurryDebounce`; no feedback is due.
        case ignored
    }

    /// What a tap on a dish does. Cooking already (a session, or a hired cook who can work): it
    /// hurries the portion. Otherwise it starts a self-serve session, unless a cook is hired for
    /// the dish (a cook with nothing to work on has nothing a tap can speed up). During fever a tap
    /// is an instant portion.
    @discardableResult
    public func tapDish(menuIndex: Int) -> DishTap {
        guard menuIndex >= 0, menuIndex <= stall.menuTier, menuIndex < stall.menuStock.count else { return .locked }
        if isFeverActive, canManualCook(menuIndex: menuIndex) {
            transients.manualCookProgress[menuIndex] = nil
            completeManualCook(menuIndex: menuIndex)
            return .started
        }
        let maxStock = EarningsSystem.maxStock(for: stall)
        if hasWorkingCook(menuIndex: menuIndex) {
            guard canAutoCook(menuIndex: menuIndex, maxStock: maxStock) else { return .blocked }
            guard consumeHurry(menuIndex: menuIndex) else { return .ignored }
            transients.cookAccumulators[menuIndex] += hurryAmount(menuIndex: menuIndex)
            return .hurried
        }
        if transients.manualCookProgress[menuIndex] != nil {
            guard consumeHurry(menuIndex: menuIndex) else { return .ignored }
            transients.manualCookProgress[menuIndex, default: 0] += hurryAmount(menuIndex: menuIndex)
            settleManualCook(menuIndex: menuIndex)
            return .hurried
        }
        guard canManualCook(menuIndex: menuIndex) else { return .blocked }
        transients.manualCookProgress[menuIndex] = 0
        return .started
    }

    /// Progress one tap adds to `menuIndex`'s portion in flight.
    public func hurryAmount(menuIndex: Int) -> Double { Self.hurryPerTap }

    private func consumeHurry(menuIndex: Int) -> Bool {
        if let last = transients.lastHurry[menuIndex], transients.clock - last < Self.hurryDebounce { return false }
        transients.lastHurry[menuIndex] = transients.clock
        return true
    }

    /// Kept for callers that only care whether a tap began a cook: true for `.started`.
    @discardableResult
    public func startManualCook(menuIndex: Int) -> Bool {
        tapDish(menuIndex: menuIndex) == .started
    }

    /// A customer is waiting on `menuIndex`: starts a self-serve session when nobody cooks it and
    /// it is below `selfServeStock`. True when one began.
    @discardableResult
    public func requestSelfServe(menuIndex: Int) -> Bool {
        guard menuIndex >= 0, menuIndex < stall.menuStock.count,
              !hasWorkingCook(menuIndex: menuIndex),
              transients.manualCookProgress[menuIndex] == nil,
              stall.menuStock[menuIndex] < Self.selfServeStock,
              canManualCook(menuIndex: menuIndex) else { return false }
        transients.manualCookProgress[menuIndex] = 0
        return true
    }

    // MARK: - Watering

    public static let waterGrowth: Double = 0.15
    public static let waterInterval: Double = 0.25

    /// A tap on a growing plot: +`waterGrowth`, at most once per `waterInterval` per plot. False
    /// when the plot is not growing or was watered a moment ago.
    @discardableResult
    public func waterPlot(plotIndex: Int) -> Bool {
        guard farm.plots.indices.contains(plotIndex),
              farm.plots[plotIndex].isPlanted, !farm.plots[plotIndex].isReady else { return false }
        if let last = transients.lastWater[plotIndex], transients.clock - last < Self.waterInterval { return false }
        transients.lastWater[plotIndex] = transients.clock
        farm.plots[plotIndex].growth = min(1, farm.plots[plotIndex].growth + Self.waterGrowth)
        if farm.plots[plotIndex].isReady, random() < Self.goldenChance { farm.plots[plotIndex].isGolden = true }
        return true
    }

    // MARK: - Waking

    public enum WorkerTarget: Hashable {
        case cook(menuIndex: Int), cashier, farm(plotIndex: Int)
    }

    public static let wakeEnergy: Double = 0.5
    public static let wakeInterval: Double = 30

    /// A worker at the post who is asleep: out of energy, and back to work only at full energy.
    public func isResting(_ target: WorkerTarget) -> Bool {
        switch target {
        case .cook(let i):
            return stall.menuCooks.indices.contains(i) && stall.menuCooks[i] > 0
                && stall.menuCookResting.indices.contains(i) && stall.menuCookResting[i]
        case .cashier:
            return stall.cashierCount > 0 && stall.cashierResting
        case .farm(let i):
            return farm.plots.indices.contains(i) && farm.plots[i].hasWorker && farm.plots[i].workerResting
        }
    }

    /// A tap on a sleeping worker hurries the nap: +`wakeEnergy`, at most once per `wakeInterval`
    /// per worker. She keeps sleeping unless that brings her to full energy.
    @discardableResult
    public func wakeWorker(_ target: WorkerTarget) -> Bool {
        guard isResting(target) else { return false }
        if let last = transients.lastWake[target], transients.clock - last < Self.wakeInterval { return false }
        transients.lastWake[target] = transients.clock
        switch target {
        case .cook(let i):
            stall.menuCookEnergy[i] = min(1, stall.menuCookEnergy[i] + Self.wakeEnergy)
            if stall.menuCookEnergy[i] >= 1 { stall.menuCookResting[i] = false }
        case .cashier:
            stall.cashierEnergy = min(1, stall.cashierEnergy + Self.wakeEnergy)
            if stall.cashierEnergy >= 1 { stall.cashierResting = false }
        case .farm(let i):
            farm.plots[i].workerEnergy = min(1, farm.plots[i].workerEnergy + Self.wakeEnergy)
            if farm.plots[i].workerEnergy >= 1 { farm.plots[i].workerResting = false }
        }
        return true
    }

    /// A worker placed on a post starts asleep when she arrives that drained.
    private static func startsResting(_ energy: Double) -> Bool { energy < ShopStaffPresence.lowEnergyThreshold }

    public var isWarehouseFull: Bool { stall.warehouse >= stall.warehouseCapacity }

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

    /// A hired cook who is awake. A sleeping one leaves the dish to the player, so manual cooking
    /// treats the post as empty until she is back to full energy.
    private func hasWorkingCook(menuIndex: Int) -> Bool {
        stall.menuCooks.indices.contains(menuIndex) && stall.menuCooks[menuIndex] > 0
            && !(stall.menuCookResting.indices.contains(menuIndex) && stall.menuCookResting[menuIndex])
    }

    /// Shared by `tick`'s auto-cook loop and `isCooking` so the two can't
    /// drift: a hired cook only actually produces when the warehouse has
    /// stock, its menu tier is unlocked, and its stock isn't already full.
    private func canAutoCook(menuIndex: Int, maxStock: Int) -> Bool {
        hasWorkingCook(menuIndex: menuIndex)
            && stall.warehouse > 0
            && menuIndex <= stall.menuTier
            && menuIndex < stall.menuStock.count && stall.menuStock[menuIndex] < maxStock
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

    /// Items per second a manual (tap) cook produces: one portion per 4 s. Customer patience is
    /// 12 s, so a first-minute player who cooks by hand is not punished for it. A hired cook
    /// (0.14/s) is slower per dish but works all three dishes with no taps, so hiring still buys
    /// automation, not speed.
    private static let manualCookRate: Double = 0.25

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

    /// Where a new hire went. Tiers are the hire list's: 1-3 staff, 4 farmer, 5 veteran alba.
    public enum StaffPlacement: Equatable {
        case cook(menuIndex: Int), cashier, farm(plotIndex: Int), unassigned
    }

    public struct HireResult: Equatable {
        public let tier: Int
        public let placement: StaffPlacement
    }

    /// Puts the newest idle worker of `tier` on the most useful free job. Each tier only takes jobs it
    /// may do; with none free the worker stays idle.
    ///
    /// An alba fills the empty plots first, then a dish with no cook (lowest first), then the cashier.
    /// Cabbages are what a shop that nobody taps runs out of (a plot only feeds the warehouse while a
    /// worker harvests it), and with the first 300-coin hire cooking instead, a fully idle 12-minute
    /// run lost 17% of its customers and earned a seventh of an active one; farm-first loses none and
    /// earns about 0.4x. Self-serve prep already cooks a dish up to 5 with nobody hired.
    /// 이모님 and the chef cannot farm: dish first, then (이모님) the cashier. The veteran takes the
    /// till, then a plot.
    private func autoPlace(tier: Int) -> StaffPlacement {
        let canCook = (1...3).contains(tier)
        let canCashier = [1, 2, 5].contains(tier)
        let farmType: FarmWorkerType? = [1: .alba, 4: .farmer, 5: .veteranAlba][tier]
        func placeOnFarm() -> StaffPlacement? {
            guard let farmType, let plot = farm.plots.indices.first(where: { !farm.plots[$0].hasWorker }) else { return nil }
            toggleFarmWorker(plotIndex: plot, workerType: farmType)
            return farm.plots[plot].workerType == farmType ? .farm(plotIndex: plot) : nil
        }
        if tier == 1, let placed = placeOnFarm() { return placed }
        if canCook,
           let menu = stall.menuCooks.indices.first(where: { $0 <= stall.menuTier && stall.menuCooks[$0] == 0 }) {
            assignMenuCook(menuIndex: menu, tier: tier)
            if stall.menuCooks[menu] == tier { return .cook(menuIndex: menu) }
        }
        if canCashier, stall.cashierCount == 0 {
            assignToCashier(tier: tier)
            if stall.cashierCount > 0 { return .cashier }
        }
        if tier != 1, let placed = placeOnFarm() { return placed }
        return .unassigned
    }

    @discardableResult
    public func hireFarmer() -> HireResult? {
        let cost = UpgradeDefinitions.farmer[0].coinCost
        guard stall.coins >= cost else { return nil }
        stall.coins -= cost
        stall.farmerCount += 1
        pushIdle(energy: 1.0, for: 4)
        let placement = autoPlace(tier: 4)
        save()
        return HireResult(tier: 4, placement: placement)
    }

    @discardableResult
    public func hireVeteranAlba() -> HireResult? {
        let cost = UpgradeDefinitions.veteranAlba[0].coinCost
        guard stall.coins >= cost else { return nil }
        stall.coins -= cost
        stall.veteranAlbaCount += 1
        pushIdle(energy: 1.0, for: 5)
        let placement = autoPlace(tier: 5)
        save()
        return HireResult(tier: 5, placement: placement)
    }

    /// Toggle a farm worker of any type on/off a plot. Putting one on takes the oldest benched worker of
    /// the type, or the one at `idleIndex`; `directEnergy` and `directSkill` carry a worker straight
    /// from another post instead.
    public func toggleFarmWorker(plotIndex: Int, workerType: FarmWorkerType = .alba, displayedEnergy: Double? = nil, addToIdle: Bool = true, directEnergy: Double? = nil, idleIndex: Int = 0, directSkill: StaffSkill? = nil) {
        guard plotIndex < farm.plots.count else { return }
        if farm.plots[plotIndex].hasWorker {
            let energy = displayedEnergy ?? farm.plots[plotIndex].workerEnergy
            if addToIdle {
                let tier: Int
                switch farm.plots[plotIndex].workerType {
                case .alba:        tier = 1
                case .farmer:      tier = 4
                case .veteranAlba: tier = 5
                case .none:        tier = 0
                }
                pushIdle(energy: energy, skill: StaffSkill(level: farm.plots[plotIndex].workerLevel, exp: farm.plots[plotIndex].workerExp), for: tier)
            }
            farm.plots[plotIndex].workerEnergy = 1.0
            farm.plots[plotIndex].workerResting = false
            farm.plots[plotIndex].workerLevel = 1
            farm.plots[plotIndex].workerExp = 0
            farm.plots[plotIndex].workerType   = .none
        } else {
            let tier: Int
            switch workerType {
            case .alba:
                guard availableForFarm > 0 else { return }
                tier = 1
            case .farmer:
                guard availableFarmers > 0 else { return }
                tier = 4
            case .veteranAlba:
                guard availableVeteranAlbas > 0 else { return }
                tier = 5
            case .none: return
            }
            let worker = takeWorker(tier: tier, idleIndex: idleIndex, directEnergy: directEnergy, directSkill: directSkill)
            farm.plots[plotIndex].workerEnergy = worker.energy
            farm.plots[plotIndex].workerResting = Self.startsResting(worker.energy)
            farm.plots[plotIndex].workerLevel = StaffLevelSystem.clamped(worker.skill.level)
            farm.plots[plotIndex].workerExp = worker.skill.exp
            farm.plots[plotIndex].workerType   = workerType
        }
        save()
    }

    public func assignToCashier(tier: Int = 0, directEnergy: Double? = nil, idleIndex: Int = 0, directSkill: StaffSkill? = nil) {
        let t = tier > 0 ? tier : 1
        guard unassignedCount(for: t) > 0, stall.cashierCount == 0 else { return }
        let worker = takeWorker(tier: t, idleIndex: idleIndex, directEnergy: directEnergy, directSkill: directSkill)
        stall.cashierEnergy = worker.energy
        stall.cashierLevel = StaffLevelSystem.clamped(worker.skill.level)
        stall.cashierExp = worker.skill.exp
        stall.cashierResting = Self.startsResting(stall.cashierEnergy)
        stall.cashierTier   = t
        stall.cashierCount += 1
        save()
    }

    public func removeFromCashier(displayedEnergy: Double? = nil, addToIdle: Bool = true) {
        guard stall.cashierCount > 0 else { return }
        let energy = displayedEnergy ?? stall.cashierEnergy
        if addToIdle { pushIdle(energy: energy, skill: StaffSkill(level: stall.cashierLevel, exp: stall.cashierExp), for: stall.cashierTier) }
        stall.cashierLevel = 1
        stall.cashierExp = 0
        stall.cashierEnergy = 1.0
        stall.cashierResting = false
        transients.cashierBusyRemaining = 0
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
    public func assignMenuCook(menuIndex: Int, tier: Int, directEnergy: Double? = nil, idleIndex: Int = 0, directSkill: StaffSkill? = nil) {
        guard menuIndex <= stall.menuTier,
              menuIndex < stall.menuCooks.count,
              stall.menuCooks[menuIndex] == 0 else { return }
        guard unassignedCount(for: tier) > 0 else { return }
        stall.menuCooks[menuIndex] = tier
        let worker = takeWorker(tier: tier, idleIndex: idleIndex, directEnergy: directEnergy, directSkill: directSkill)
        stall.menuCookLevels[menuIndex] = StaffLevelSystem.clamped(worker.skill.level)
        stall.menuCookExp[menuIndex] = worker.skill.exp
        stall.menuCookEnergy[menuIndex] = worker.energy
        stall.menuCookResting[menuIndex] = Self.startsResting(stall.menuCookEnergy[menuIndex])
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
        if addToIdle { pushIdle(energy: energy, skill: StaffSkill(level: stall.menuCookLevels[safe: menuIndex] ?? 1, exp: stall.menuCookExp[safe: menuIndex] ?? 0), for: tier) }
        stall.menuCookLevels[menuIndex] = 1
        stall.menuCookExp[menuIndex] = 0
        stall.menuCookEnergy[menuIndex] = 1.0
        stall.menuCookResting[menuIndex] = false
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

    @discardableResult
    public func hireWorker(tier: Int) -> HireResult? {
        guard UpgradeDefinitions.isStaffTierUnlocked(tier, stallTier: stall.stallTier) else { return nil }
        let cost = UpgradeDefinitions.staff[tier - 1].coinCost
        guard stall.coins >= cost else { return nil }
        stall.coins -= cost
        switch tier {
        case 1: stall.tier1Count += 1
        case 2: stall.tier2Count += 1
        case 3: stall.tier3Count += 1
        default: break
        }
        pushIdle(energy: 1.0, for: tier)
        stall.staffTier = max(stall.staffTier, tier)
        let placement = autoPlace(tier: tier)
        save()
        return HireResult(tier: tier, placement: placement)
    }

    // MARK: - Firing

    /// Who to let go: the worker at a post, or a benched one (`index` into that tier's idle pool).
    public enum FireTarget: Equatable {
        case cook(menuIndex: Int), cashier, farm(plotIndex: Int), idle(tier: Int, index: Int)
    }

    /// Lets one worker go for good: the post is freed as `remove*` would but she does not return
    /// to the bench, and the headcount drops. No refund; hiring again pays the full price.
    /// `staffTier` stays: it is the highest tier ever hired, which the goal bar and the gift
    /// crate read as progress, so letting someone go never sets the player back.
    /// False, changing nothing, when the target does not hold a worker.
    @discardableResult
    public func fireWorker(_ target: FireTarget) -> Bool {
        let tier: Int
        switch target {
        case .cook(let i):
            guard stall.menuCooks.indices.contains(i), stall.menuCooks[i] > 0 else { return false }
            tier = stall.menuCooks[i]
            removeMenuCook(menuIndex: i, addToIdle: false)
            transients.cookAccumulators[i] = 0
        case .cashier:
            guard stall.cashierCount > 0 else { return false }
            tier = stall.cashierTier
            removeFromCashier(addToIdle: false)
        case .farm(let i):
            guard farm.plots.indices.contains(i), farm.plots[i].hasWorker else { return false }
            switch farm.plots[i].workerType {
            case .alba: tier = 1
            case .farmer: tier = 4
            case .veteranAlba: tier = 5
            case .none: return false
            }
            toggleFarmWorker(plotIndex: i, addToIdle: false)
        case .idle(let t, let index):
            guard (1...5).contains(t), benchedCount(tier: t) > 0 else { return false }
            tier = t
            removeIdleEntry(tier: t, index: index)
        }
        decrementCount(for: tier)
        if let wake = workerTarget(for: target) { transients.lastWake[wake] = nil }
        normalizeIdlePools()
        save()
        return true
    }

    private func benchedCount(tier: Int) -> Int {
        tier == 4 ? availableFarmers : unassignedCount(for: tier)
    }

    private func workerTarget(for target: FireTarget) -> WorkerTarget? {
        switch target {
        case .cook(let i): .cook(menuIndex: i)
        case .cashier: .cashier
        case .farm(let i): .farm(plotIndex: i)
        case .idle: nil
        }
    }

    private func removeIdleEntry(tier: Int, index: Int) {
        popIdle(for: tier, at: index)
    }

    private func decrementCount(for tier: Int) {
        switch tier {
        case 1: stall.tier1Count = max(0, stall.tier1Count - 1)
        case 2: stall.tier2Count = max(0, stall.tier2Count - 1)
        case 3: stall.tier3Count = max(0, stall.tier3Count - 1)
        case 4: stall.farmerCount = max(0, stall.farmerCount - 1)
        default: stall.veteranAlbaCount = max(0, stall.veteranAlbaCount - 1)
        }
    }

    // MARK: - Levels

    /// A worker's tier, level and experience, nil when the target holds nobody.
    private func skill(of target: FireTarget) -> (tier: Int, skill: StaffSkill)? {
        switch target {
        case .cook(let i):
            guard stall.menuCooks.indices.contains(i), stall.menuCooks[i] > 0 else { return nil }
            return (stall.menuCooks[i], StaffSkill(level: stall.menuCookLevels[safe: i] ?? 1, exp: stall.menuCookExp[safe: i] ?? 0))
        case .cashier:
            return stall.cashierCount > 0
                ? (stall.cashierTier, StaffSkill(level: stall.cashierLevel, exp: stall.cashierExp)) : nil
        case .farm(let i):
            guard farm.plots.indices.contains(i), farm.plots[i].hasWorker else { return nil }
            let tier: Int
            switch farm.plots[i].workerType {
            case .alba: tier = 1
            case .farmer: tier = 4
            case .veteranAlba: tier = 5
            case .none: return nil
            }
            return (tier, StaffSkill(level: farm.plots[i].workerLevel, exp: farm.plots[i].workerExp))
        case .idle(let tier, let index):
            guard benchedCount(tier: tier) > 0, let pools = idlePools(tier) else { return nil }
            alignLevels(pools)
            let count = stall[keyPath: pools.levels].count
            guard count > 0 else { return nil }
            let i = min(max(index, 0), count - 1)
            return (tier, StaffSkill(level: stall[keyPath: pools.levels][i], exp: stall[keyPath: pools.exp][i]))
        }
    }

    public func level(of target: FireTarget) -> Int? { skill(of: target)?.skill.level }
    public func experience(of target: FireTarget) -> Double? { skill(of: target)?.skill.exp }

    // MARK: - Experience

    /// One worker levelling up by working, for the HUD toast and sound.
    public struct LevelUp: Equatable {
        public let tier: Int
        public let level: Int
        public let wageBefore: Double
        public let wageAfter: Double
    }

    /// Every level-up of one tick. `id` changes on each tick that promoted somebody.
    public struct LevelUps: Equatable {
        public let id: Int
        public let events: [LevelUp]
    }

    /// Working time: a worker on a post and awake earns `deltaTime` of experience. The bench, sleep and
    /// strike, a paused simulation, an inactive app and offline time earn none, and the same
    /// rule applies to cooks, the cashier and farm hands.
    private func accrueExperience(deltaTime: Double) {
        guard isAppActive, deltaTime > 0 else { return }
        var events: [LevelUp] = []
        func work(tier: Int, _ current: StaffSkill) -> StaffSkill {
            var skill = current
            let gained = StaffLevelSystem.work(&skill, seconds: deltaTime)
            if gained > 0 {
                events.append(LevelUp(tier: tier, level: skill.level,
                                      wageBefore: WageSystem.wage(forTier: tier, level: current.level),
                                      wageAfter: WageSystem.wage(forTier: tier, level: skill.level)))
            }
            return skill
        }
        for i in stall.menuCooks.indices where stall.menuCooks[i] > 0 && !stall.menuCookResting[i] {
            let skill = work(tier: stall.menuCooks[i], StaffSkill(level: stall.menuCookLevels[i], exp: stall.menuCookExp[i]))
            stall.menuCookLevels[i] = skill.level; stall.menuCookExp[i] = skill.exp
        }
        if stall.cashierCount > 0, !stall.cashierResting {
            let skill = work(tier: stall.cashierTier, StaffSkill(level: stall.cashierLevel, exp: stall.cashierExp))
            stall.cashierLevel = skill.level; stall.cashierExp = skill.exp
        }
        for i in farm.plots.indices where farm.plots[i].hasWorker && !farm.plots[i].workerResting {
            let tier = farm.plots[i].workerType == .farmer ? 4 : (farm.plots[i].workerType == .veteranAlba ? 5 : 1)
            let skill = work(tier: tier, StaffSkill(level: farm.plots[i].workerLevel, exp: farm.plots[i].workerExp))
            farm.plots[i].workerLevel = skill.level; farm.plots[i].workerExp = skill.exp
        }
        guard !events.isEmpty else { return }
        levelUpCount += 1
        levelUps = LevelUps(id: levelUpCount, events: events)
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
        let elapsed = min(Date().timeIntervalSince(lastActive), Self.maxOfflineHours * 3600)
        let earned = rate * elapsed * Self.offlineEfficiency
        print("[Offline] lastActive=\(lastActive), elapsed=\(Int(elapsed))s, rate=\(String(format:"%.4f",rate))/s, earned=\(Int(earned))")
        guard earned >= 1 else { return }
        let bestSale = EarningsSystem.salePrice(for: stall, menuIndex: stall.menuTier, prestigeCount: progress.prestigeCount)
        if elapsed < Self.offlinePopupMinSeconds || earned < Self.offlinePopupMinSales * bestSale {
            // Not worth a popup (or an ad offer): credit it quietly.
            stall.coins += earned
            progress.totalEarned += earned
            progress.lastActiveDate = Date()
            save()
            return
        }
        offlineEarnings = earned
    }

    /// The welcome-back popup needs at least this long away and this many sales of the best dish.
    static let offlinePopupMinSeconds: Double = 60
    static let offlinePopupMinSales: Double = 10

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

    public func recordServed(waitTime: Double, isGourmet: Bool = false) {
        progress.totalServed += 1
        let headroom = min(1, (5.0 - progress.rating) / 2)
        let delta = (waitTime < 3.0 ? Self.ratingGainFast : Self.ratingGainSlow) * (isGourmet ? 2 : 1) * headroom
            * Self.comebackMultiplier(rating: progress.rating)
        progress.rating = min(5.0, progress.rating + delta)
        progress.bestRating = max(progress.bestRating, progress.rating)
        FeverSystem.recordServed(&transients.fever, waitTime: waitTime,
                                 baseCharge: FeverSystem.charge(perServeAtInterval: baseSpawnInterval))
        advanceMissions(.serveCustomers)
        if isGourmet {
            progress.totalGourmetServed += 1
            advanceMissions(.serveGourmets)
        }
        save()
    }

    static let gourmetChance: Double = 0.08
    /// Rating gains 0.02/0.01 a customer (fast < 3 s / slow), tapering to nothing between 3.0 and 5.0,
    /// and falls this much per second at 3.0, scaling up with the rating (3x at 5.0): a high rating
    /// takes steady service and settles below 5.0 instead of pinning there.
    static let ratingDecayPerSecond: Double = 0.0005
    static let ratingGainFast: Double = 0.02
    static let ratingGainSlow: Double = 0.01
    /// Decay stops here and serve gains are boosted below it. Without this a 1.0 shop is stuck:
    /// customers come every 20 s, decay costs 0.0005 * 20 = 0.01 per gap and a slow serve earns
    /// exactly 0.01, so the net is zero and even perfect service needs ~40 minutes to reach 3.0.
    static let ratingRecoveryFloor: Double = 3.0

    /// Serve-gain multiplier: 1 at the floor and above, rising by 1 per rating point below it (3x at 1.0).
    static func comebackMultiplier(rating: Double) -> Double {
        1 + max(0, ratingRecoveryFloor - rating)
    }

    /// Whether the next customer is a gourmet. No roll is consumed below the rating floor.
    public func rollGourmet() -> Bool {
        MissionSystem.displayedRating(progress.rating) >= MissionSystem.gourmetRatingFloor && random() < Self.gourmetChance
    }

    public func recordFailed(isGourmet: Bool = false) {
        progress.totalFailed += 1
        // Grace until the first sale: the first customers arrive before any dish is cooked, so a new
        // player cannot avoid these. Per run: a new spring restarts the grace with the empty shelf.
        if progress.runServed > 0 {
            progress.rating = max(1.0, progress.rating - (isGourmet ? 0.10 : 0.05))
        }
        save()
    }

    // MARK: - Upgrades

    /// Free portions of a dish the moment its tier is bought.
    static let newDishStartingStock = 3

    public func purchaseUpgrade(_ type: UpgradeType) {
        switch type {
        case .staff:
            return   // a goal tag only: hiring goes through `hireWorker(tier:)`

        case .menu:
            guard case .available(_, let cost) = MenuUnlockSystem.status(for: stall, menuIndex: stall.menuTier + 1) else { return }
            stall.coins -= cost
            stall.menuTier += 1
            // The new dish starts with a few portions, so the first customers who ask for it are served.
            let maxStock = EarningsSystem.maxStock(for: stall)
            stall.menuStock[stall.menuTier] = min(maxStock, stall.menuStock[stall.menuTier] + Self.newDishStartingStock)

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

        case .location:
            let nextTier = stall.locationTier + 1
            guard nextTier < UpgradeDefinitions.location.count else { return }
            let next = UpgradeDefinitions.location[nextTier]
            guard stall.stallTier >= next.requiredStallTier,
                  stall.coins >= next.coinCost else { return }
            stall.coins -= next.coinCost
            stall.locationTier = nextTier
            save()
            return

        case .warehouse:
            expandWarehouse()   // saves itself
            return

        case .recipe(let menuIndex):
            guard let cost = RecipeSystem.nextCost(for: stall, menuIndex: menuIndex),
                  stall.coins >= cost else { return }
            stall.coins -= cost
            stall.recipeLevels[menuIndex] += 1

        case .renovation:
            guard let cost = RenovationSystem.nextCost(for: stall), stall.coins >= cost else { return }
            stall.coins -= cost
            stall.renovationLevel += 1
        }
        save()
    }

    // MARK: - New spring

    /// Where the previous run's three blobs are copied before `startNewRun` replaces them. A single
    /// key holding the latest only: a support or recovery path, never read by the game itself.
    static let preRestartSnapshotKey = "gameStore.preRestartSnapshot"

    public struct PreRestartSnapshot {
        public let stall: Data
        public let farm: Data
        public let progress: Data
        public let takenAt: Date
    }

    public var preRestartSnapshot: PreRestartSnapshot? {
        guard let dict = defaults.dictionary(forKey: Self.preRestartSnapshotKey),
              let stall = dict[SaveBlob.stall.rawValue] as? Data,
              let farm = dict[SaveBlob.farm.rawValue] as? Data,
              let progress = dict[SaveBlob.progress.rawValue] as? Data,
              let takenAt = dict["takenAt"] as? Date else { return nil }
        return PreRestartSnapshot(stall: stall, farm: farm, progress: progress, takenAt: takenAt)
    }

    /// The final location and the final stall tier. Pure state: whether the CTA is also enabled
    /// (an offline popup can be pending) is `canStartNewRun`.
    public var isPrestigeAvailable: Bool { PrestigeSystem.isAvailable(for: stall) }

    /// False while the offline-earnings popup is pending: its coins belong to the old run and its
    /// rate to the old shop, so the player settles it first.
    public var canStartNewRun: Bool { isPrestigeAvailable && offlineEarnings == 0 }

    /// 새봄 맞이. Destructive, so: the old run is snapshotted first, the new state is built from a
    /// fresh default with a whitelist copied over (a run field added later resets by default; a
    /// kept field must be named here), and the save is flushed before this returns. Nothing
    /// animates until it has. Returns false, changing nothing, when the spring is not available.
    @discardableResult
    public func startNewRun() -> Bool {
        guard canStartNewRun else { return false }

        // Order matters: the marker may only exist once the snapshot it points at is complete.
        if takePreRestartSnapshot() {
            defaults.set(progress.prestigeCount + 1, forKey: Self.springInFlightKey)
        }
        replaceRun(from: progress)
        defaults.removeObject(forKey: Self.springInFlightKey)
        return true
    }

    /// Present only between "snapshot written" and "all three blobs written"; the value is the
    /// prestige count the spring is heading to. A launch that finds it knows the blobs may be a
    /// mix of old and new, which `save()`'s three separate writes cannot rule out.
    static let springInFlightKey = "gameStore.springInFlight"

    /// Finishes a spring that was killed mid-write: the snapshot holds the complete old run, so
    /// replaying the same replacement from it lands on one consistent new run, whichever of the
    /// blobs had already been written. Idempotent: the snapshot is untouched until the marker is
    /// cleared, so a second kill during recovery just recovers again. A snapshot that is missing,
    /// undecodable or not the one this marker was written for is never trusted over the blobs.
    /// `save()` writes stall, farm, then progress last, so a loaded progress that already reached
    /// the target means all three blobs are new: the marker is stale, and replaying the spring
    /// from the older snapshot would overwrite the live run.
    private func recoverInterruptedSpring(targetPrestigeCount: Int) {
        let decoder = JSONDecoder()
        if let snapshot = preRestartSnapshot,
           let oldProgress = try? decoder.decode(PlayerProgress.self, from: snapshot.progress),
           oldProgress.prestigeCount + 1 == targetPrestigeCount,
           progress.prestigeCount < targetPrestigeCount,
           let oldStall = try? decoder.decode(StallState.self, from: snapshot.stall),
           let oldFarm = try? decoder.decode(FarmState.self, from: snapshot.farm) {
            stall = oldStall
            farm = oldFarm
            progress = oldProgress
            replaceRun(from: oldProgress)
        }
        defaults.removeObject(forKey: Self.springInFlightKey)
    }

    private func replaceRun(from old: PlayerProgress) {
        var next = PlayerProgress()
        // Kept: identity and everything lifetime.
        next.isFirstLaunch          = old.isFirstLaunch
        next.isShopNameSet          = old.isShopNameSet
        next.shopName               = old.shopName
        next.totalEarned            = old.totalEarned
        next.totalServed            = old.totalServed
        next.totalFailed            = old.totalFailed
        next.totalPlaySeconds       = old.totalPlaySeconds
        next.bestRating             = old.highestRating
        next.hasSeenPrestigeIntro   = true
        next.totalGourmetServed     = old.totalGourmetServed
        next.totalGoldenHarvested   = old.totalGoldenHarvested
        next.totalFevers            = old.totalFevers
        next.totalTipsCollected     = old.totalTipsCollected
        next.totalWagesPaid         = old.totalWagesPaid
        // The play clock is kept, so the new shop starts mid-day: no wages for the days already behind it.
        next.lastWageDay            = DayCycle.dayIndex(playSeconds: old.totalPlaySeconds)
        // Changed on purpose.
        next.prestigeCount          = old.prestigeCount + 1
        next.fastestRunSeconds      = min(old.fastestRunSeconds ?? .infinity, old.runPlaySeconds)
        next.runBaselinePlaySeconds = old.totalPlaySeconds
        next.runBaselineEarned      = old.totalEarned
        next.runBaselineServed      = old.totalServed
        next.runBaselineFailed      = old.totalFailed
        // Anchored to now: the old shop's elapsed time must not be paid out as offline earnings of
        // the new one (its `earningRate` is already back to 0).
        next.lastActiveDate         = Date()

        stall = StallState()
        stall.coins = PrestigeSystem.startingCoins(prestigeCount: next.prestigeCount)
        farm = FarmState()
        progress = next
        transients = RunTransients()
        normalizeIdlePools()
        save()
    }

    /// False when the state could not be encoded, in which case nothing was written.
    private func takePreRestartSnapshot() -> Bool {
        let encoder = JSONEncoder()
        guard let stallData = try? encoder.encode(stall),
              let farmData = try? encoder.encode(farm),
              let progressData = try? encoder.encode(progress) else { return false }
        defaults.set([
            SaveBlob.stall.rawValue: stallData,
            SaveBlob.farm.rawValue: farmData,
            SaveBlob.progress.rawValue: progressData,
            "takenAt": Date(),
        ] as [String: Any], forKey: Self.preRestartSnapshotKey)
        return true
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
        saveMissionsIfChanged()
    }

    /// Missions change only on a rollover or a counted event, so the blob is written only then:
    /// the 5 s save cadence of the other blobs must not grow a fourth write every time.
    private func saveMissionsIfChanged() {
        guard missionState != persistedMissions,
              let d = try? JSONEncoder().encode(missionState) else { return }
        defaults.set(d, forKey: SaveBlob.missions.key)
        persistedMissions = missionState
    }
}
