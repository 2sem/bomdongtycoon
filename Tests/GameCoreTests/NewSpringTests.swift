import XCTest
@testable import GameCore

@MainActor
final class NewSpringTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "NewSpringTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    // MARK: Fixtures

    /// A late-game run: final location and stall, every run field moved off its default, and a
    /// non-trivial lifetime record, so a reset that misses a field cannot pass by coincidence.
    private func makeReadyStore(prestigeCount: Int = 0) -> GameStore {
        let store = GameStore(defaults: defaults)
        store.stall.coins = 123_456
        store.stall.menuTier = 2
        store.stall.staffTier = 3
        store.stall.stallTier = 2
        store.stall.locationTier = 2
        store.stall.pendingCoins = 31
        store.stall.tier1Count = 3
        store.stall.tier2Count = 2
        store.stall.tier3Count = 1
        store.stall.cashierCount = 1
        store.stall.cashierTier = 2
        store.stall.cashierEnergy = 0.4
        store.stall.menuCooks = [1, 2, 3]
        store.stall.menuCookEnergy = [0.2, 0.5, 0.7]
        store.stall.tier1IdleEnergies = [0.3]
        store.stall.tier2IdleEnergies = [0.6]
        store.stall.warehouse = 33
        store.stall.warehouseCapacity = 60
        store.stall.menuStock = [10, 20, 30]
        store.stall.farmerCount = 1
        store.stall.farmerIdleEnergies = [0.9]
        store.stall.veteranAlbaCount = 1
        store.stall.veteranAlbaIdleEnergies = [0.8]
        store.farm.plots.append(contentsOf: [FarmPlot(), FarmPlot(), FarmPlot()])
        store.farm.plots[2].workerType = .farmer
        store.farm.plots[3].isPlanted = true
        store.farm.plots[3].growth = 0.8

        var p = store.progress
        p.isFirstLaunch = false
        p.isShopNameSet = true
        p.shopName = "내 봄동 가게"
        p.lastActiveDate = Date().addingTimeInterval(-7200)
        p.totalEarned = 500_000
        p.earningRate = 77
        p.rating = 4.2
        p.totalServed = 900
        p.totalFailed = 30
        p.prestigeCount = prestigeCount
        p.totalPlaySeconds = 5_000
        p.runBaselinePlaySeconds = 1_000
        p.runBaselineEarned = 100_000
        p.runBaselineServed = 200
        p.runBaselineFailed = 10
        p.bestRating = 4.6
        p.fastestRunSeconds = 9_000
        p.hasSeenPrestigeIntro = prestigeCount > 0
        store.progress = p
        return store
    }

    private func encoded(_ store: GameStore) throws -> [Data] {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return [try e.encode(store.stall), try e.encode(store.farm), try e.encode(store.progress)]
    }

    private func persisted() -> [Data?] {
        ["gameStore.stall", "gameStore.farm", "gameStore.progress"].map { defaults.data(forKey: $0) }
    }

    // MARK: Availability

    func test_availabilityMatrix() {
        let store = GameStore(defaults: defaults)
        for location in 0..<UpgradeDefinitions.location.count {
            for stall in 0..<UpgradeDefinitions.stall.count {
                store.stall.locationTier = location
                store.stall.stallTier = stall
                let both = location == UpgradeDefinitions.location.count - 1
                    && stall == UpgradeDefinitions.stall.count - 1
                XCTAssertEqual(store.isPrestigeAvailable, both, "location \(location), stall \(stall)")
                XCTAssertEqual(store.canStartNewRun, both)
            }
        }
    }

    func test_availabilityHolds_whileConditionsHold() {
        let store = makeReadyStore()
        XCTAssertTrue(store.isPrestigeAvailable)
        store.stall.coins = 0
        store.stall.menuTier = 0
        XCTAssertTrue(store.isPrestigeAvailable, "spending coins does not close it")
    }

    func test_requirementsReportProgress() {
        var stall = StallState()
        stall.locationTier = 1
        stall.stallTier = 1
        let location = PrestigeSystem.locationRequirement(for: stall)
        XCTAssertFalse(location.isMet)
        XCTAssertEqual(location.currentName, "시장")
        XCTAssertEqual(location.requiredName, "강남")
        XCTAssertEqual(PrestigeSystem.stallRequirement(for: stall).requiredName, "봄동 전문점")
        stall.locationTier = 2
        stall.stallTier = 2
        XCTAssertTrue(PrestigeSystem.locationRequirement(for: stall).isMet)
        XCTAssertTrue(PrestigeSystem.stallRequirement(for: stall).isMet)
    }

    // MARK: Refusals and cancel leave everything alone

    func test_unavailable_refusesAndChangesNothing() throws {
        let store = makeReadyStore()
        store.stall.stallTier = 1
        let before = try encoded(store)
        let blobs = persisted()
        XCTAssertFalse(store.startNewRun())
        XCTAssertEqual(try encoded(store), before)
        XCTAssertEqual(persisted(), blobs)
        XCTAssertNil(store.preRestartSnapshot)
    }

    func test_pendingOfflinePopup_refusesAndChangesNothing() throws {
        let store = makeReadyStore()
        store.offlineEarnings = 1_500
        XCTAssertTrue(store.isPrestigeAvailable)
        XCTAssertFalse(store.canStartNewRun)
        let before = try encoded(store)
        XCTAssertFalse(store.startNewRun())
        XCTAssertEqual(try encoded(store), before)
        XCTAssertEqual(store.offlineEarnings, 1_500)
        XCTAssertNil(store.preRestartSnapshot)
        store.collectOfflineEarnings()
        XCTAssertTrue(store.canStartNewRun, "settling the popup re-opens the spring")
    }

    func test_cancelPath_storeIsByteIdentical() throws {
        // Opening the sheet and the alert only reads; closing, swiping down and "계속 운영하기"
        // call nothing. What the views read must not write.
        let store = makeReadyStore()
        store.markFirstLaunchComplete()   // flush a baseline to disk
        let state = try encoded(store)
        let blobs = persisted()
        _ = store.isPrestigeAvailable
        _ = store.canStartNewRun
        _ = PrestigeSystem.hasUnspentPlots(farm: store.farm)
        _ = PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount + 1)
        XCTAssertEqual(try encoded(store), state)
        XCTAssertEqual(persisted(), blobs)
        XCTAssertNil(store.preRestartSnapshot)
        XCTAssertNil(defaults.object(forKey: GameStore.preRestartSnapshotKey))
    }

    // MARK: The reset

    func test_keptFieldsAreUntouched_andCountersAdvance() throws {
        let store = makeReadyStore(prestigeCount: 1)
        let old = store.progress
        let oldRun = old.runPlaySeconds
        XCTAssertTrue(store.startNewRun())
        let p = store.progress

        XCTAssertEqual(p.prestigeCount, 2)
        XCTAssertEqual(p.totalEarned, 500_000)
        XCTAssertEqual(p.totalServed, 900)
        XCTAssertEqual(p.totalFailed, 30)
        XCTAssertEqual(p.totalPlaySeconds, 5_000)
        XCTAssertEqual(p.bestRating, 4.6)
        XCTAssertEqual(p.shopName, "내 봄동 가게")
        XCTAssertTrue(p.isShopNameSet)
        XCTAssertFalse(p.isFirstLaunch)
        XCTAssertTrue(p.hasSeenPrestigeIntro)
        XCTAssertEqual(p.runBaselinePlaySeconds, p.totalPlaySeconds)
        XCTAssertEqual(p.runBaselineEarned, p.totalEarned)
        XCTAssertEqual(p.runBaselineServed, p.totalServed)
        XCTAssertEqual(p.runBaselineFailed, p.totalFailed)
        XCTAssertEqual(p.runPlaySeconds, 0)
        XCTAssertEqual(p.runEarned, 0)
        XCTAssertEqual(p.runServed, 0)
        XCTAssertEqual(p.runFailed, 0)
        XCTAssertEqual(p.fastestRunSeconds, min(9_000, oldRun))
        XCTAssertEqual(oldRun, 4_000)
    }

    func test_runFieldsAreDefaults() {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        let fresh = StallState()
        XCTAssertEqual(store.stall.coins, 50)
        XCTAssertEqual(store.stall.locationTier, 0)
        XCTAssertEqual(store.stall.stallTier, 0)
        XCTAssertEqual(store.stall.menuTier, 0)
        XCTAssertEqual(store.stall.staffTier, 0)
        XCTAssertEqual(store.stall.warehouseCapacity, 10)
        XCTAssertEqual(store.stall.menuStock, fresh.menuStock)
        XCTAssertEqual(store.stall.cashierCount, 0)
        XCTAssertEqual(store.farm.plots.count, FarmSystem.startingPlots)
        XCTAssertEqual(store.progress.rating, 3.0)
        XCTAssertEqual(store.progress.earningRate, 0)
        XCTAssertFalse(store.isPrestigeAvailable)
    }

    func test_fastestRun_isMinimumOfOldAndThisRun() {
        let slow = makeReadyStore()   // this run: 4000 s, old fastest 9000 s
        XCTAssertTrue(slow.startNewRun())
        XCTAssertEqual(slow.progress.fastestRunSeconds, 4_000)

        let fast = makeReadyStore()
        fast.progress.fastestRunSeconds = 1_500
        XCTAssertTrue(fast.startNewRun())
        XCTAssertEqual(fast.progress.fastestRunSeconds, 1_500)

        let first = makeReadyStore()
        first.progress.fastestRunSeconds = nil
        XCTAssertTrue(first.startNewRun())
        XCTAssertEqual(first.progress.fastestRunSeconds, 4_000)
    }

    func test_bestRating_keepsLiveRatingWhenHigher() {
        let store = makeReadyStore()
        store.progress.bestRating = 0   // an older save: only the live rating carries it
        store.progress.rating = 4.9
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.progress.bestRating, 4.9)
        XCTAssertEqual(store.progress.rating, 3.0)
    }

    /// Every stored field of the three models is either on the keep list or equals its default
    /// after a spring. Both lists are written out and must cover the model exactly, so a field
    /// added later fails here until someone classifies it.
    func test_everyField_isKeptOrDefault() throws {
        // PlayerProgress: kept or deliberately set, vs reset.
        let progressKept: Set<String> = [
            "isFirstLaunch", "isShopNameSet", "shopName", "totalEarned", "totalServed", "totalFailed",
            "totalPlaySeconds", "bestRating", "hasSeenPrestigeIntro", "prestigeCount",
            "fastestRunSeconds", "runBaselinePlaySeconds", "runBaselineEarned", "runBaselineServed",
            "runBaselineFailed", "lastActiveDate"]
        let progressReset: Set<String> = ["earningRate", "rating"]

        let store = makeReadyStore()
        let before = Mirror(reflecting: store.progress).children.compactMap(\.label)
        XCTAssertEqual(Set(before), progressKept.union(progressReset),
                       "a PlayerProgress field is unclassified: keep it (and copy it in startNewRun) or reset it")
        XCTAssertTrue(store.startNewRun())

        let defaultProgress = Mirror(reflecting: PlayerProgress()).children
        let nowProgress = Mirror(reflecting: store.progress).children
        for (fresh, now) in zip(defaultProgress, nowProgress) {
            guard let label = fresh.label, progressReset.contains(label) else { continue }
            XCTAssertEqual(String(describing: now.value), String(describing: fresh.value), "\(label) must reset")
        }
        let moved = try XCTUnwrap(store.progress.lastActiveDate)
        XCTAssertEqual(moved.timeIntervalSinceNow, 0, accuracy: 5, "lastActiveDate restarts at now")

        // StallState and FarmState keep nothing: every stored field is its default.
        let stallLabels = Mirror(reflecting: store.stall).children.compactMap(\.label)
        XCTAssertFalse(stallLabels.isEmpty)
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        XCTAssertEqual(try e.encode(store.stall), try e.encode(StallState()))
        XCTAssertEqual(try e.encode(store.farm), try e.encode(FarmState()))
        XCTAssertEqual(Mirror(reflecting: store.farm).children.compactMap(\.label), ["plots"])
    }

    func test_transientsReset() {
        let store = makeReadyStore()
        store.stall.menuStock = [5, 5, 5]
        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        _ = store.sellItem(menuIndex: 0)
        XCTAssertTrue(store.isManualCookRunning(menuIndex: 0))
        XCTAssertTrue(store.startNewRun())
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
        XCTAssertFalse(store.cashierRecentlySold)
        XCTAssertEqual(store.cookProgress(menuIndex: 0), 0)
    }

    func test_secondCallIsRefused() {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        XCTAssertFalse(store.startNewRun(), "a double tap cannot spring twice")
        XCTAssertEqual(store.progress.prestigeCount, 1)
    }

    // MARK: Safety

    func test_snapshotIsWrittenBeforeReset_andReplaced() throws {
        let store = makeReadyStore()
        let oldStall = try JSONEncoder().encode(store.stall)
        XCTAssertNil(store.preRestartSnapshot)
        XCTAssertTrue(store.startNewRun())

        let first = try XCTUnwrap(store.preRestartSnapshot)
        XCTAssertEqual(first.stall, oldStall)
        let oldRun = try JSONDecoder().decode(StallState.self, from: first.stall)
        XCTAssertEqual(oldRun.coins, 123_456)
        XCTAssertEqual(oldRun.locationTier, 2)
        let oldProgress = try JSONDecoder().decode(PlayerProgress.self, from: first.progress)
        XCTAssertEqual(oldProgress.prestigeCount, 0)
        XCTAssertEqual(try JSONDecoder().decode(FarmState.self, from: first.farm).plots.count, 5)

        // A second spring replaces it: latest only, one key.
        store.stall.locationTier = 2
        store.stall.stallTier = 2
        store.stall.coins = 777
        XCTAssertTrue(store.startNewRun())
        let second = try XCTUnwrap(store.preRestartSnapshot)
        let secondStall = try JSONDecoder().decode(StallState.self, from: second.stall)
        XCTAssertEqual(secondStall.coins, 777)
        XCTAssertEqual(try JSONDecoder().decode(PlayerProgress.self, from: second.progress).prestigeCount, 1)
        XCTAssertNotNil(defaults.dictionary(forKey: GameStore.preRestartSnapshotKey))
    }

    func test_saveIsCommittedBeforeReturn_andSurvivesRelaunch() throws {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        // No tick, no further call: a kill right here must load the new run.
        let relaunched = GameStore(defaults: defaults)
        XCTAssertEqual(relaunched.progress.prestigeCount, 1)
        XCTAssertEqual(relaunched.stall.coins, 50)
        XCTAssertEqual(relaunched.stall.locationTier, 0)
        XCTAssertEqual(relaunched.farm.plots.count, 2)
        XCTAssertEqual(relaunched.progress.totalEarned, 500_000)
        XCTAssertEqual(relaunched.progress.runEarned, 0)
        XCTAssertEqual(relaunched.progress.shopName, "내 봄동 가게")
        XCTAssertNil(relaunched.corruptBackup(of: .progress))
    }

    func test_corruptBackupsSurviveASpring() throws {
        defaults.set(Data("junk".utf8), forKey: "gameStore.farm.corrupt")
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(defaults.data(forKey: "gameStore.farm.corrupt"), Data("junk".utf8))
    }

    // MARK: After the spring

    func test_offlineEarnings_useTheNewRate() {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())

        // Straight after: the old rate (77/s over two hours) must not be paid to the new shop.
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 0)
        XCTAssertEqual(try XCTUnwrap(store.progress.lastActiveDate).timeIntervalSinceNow, 0, accuracy: 5)

        store.progress.earningRate = 4
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 4 * 3600 * GameStore.offlineEfficiency, accuracy: 5)
    }

    func test_firstSaleGrace_usesRunBaseline() {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.progress.totalServed, 900)
        XCTAssertEqual(store.progress.runServed, 0)

        store.recordFailed()
        XCTAssertEqual(store.progress.rating, 3.0, "no rating loss before this run's first sale")
        store.recordServed(waitTime: 0)
        let after = store.progress.rating
        store.recordFailed()
        XCTAssertLessThan(store.progress.rating, after)
        XCTAssertEqual(store.progress.totalFailed, 32)
        XCTAssertEqual(store.progress.runFailed, 2)
    }

    func test_legacyMultiplierAppliesAtX1_40AfterTheFirstSpring() throws {
        let store = makeReadyStore()
        XCTAssertTrue(store.startNewRun())
        store.stall.menuStock[0] = 1
        let price = try XCTUnwrap(store.sellItem(menuIndex: 0))
        XCTAssertEqual(price, 30 * 1.4, accuracy: 0.0001)
        XCTAssertEqual(PrestigeSystem.multiplierText(prestigeCount: store.progress.prestigeCount), "x1.4")
    }

    // MARK: Encoding and decoding

    func test_prestigedSaveRoundTripsOnThePreviousEncoderShape() throws {
        let store = makeReadyStore(prestigeCount: 2)
        XCTAssertTrue(store.startNewRun())

        let data = try JSONEncoder().encode(store.progress)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // The shape of the previous release: no key invented by the spring.
        let previous: Set<String> = [
            "isFirstLaunch", "isShopNameSet", "shopName", "lastActiveDate", "totalEarned", "earningRate",
            "rating", "totalServed", "totalFailed", "prestigeCount", "totalPlaySeconds",
            "runBaselinePlaySeconds", "runBaselineEarned", "runBaselineServed", "runBaselineFailed",
            "bestRating", "fastestRunSeconds", "hasSeenPrestigeIntro"]
        XCTAssertTrue(Set(object.keys).isSubset(of: previous), "\(Set(object.keys).subtracting(previous))")

        let back = try JSONDecoder().decode(PlayerProgress.self, from: data)
        XCTAssertEqual(back.prestigeCount, 3)
        XCTAssertEqual(back.fastestRunSeconds, store.progress.fastestRunSeconds)
        XCTAssertEqual(back.runBaselineEarned, store.progress.totalEarned)
        XCTAssertEqual(back.bestRating, 4.6)

        // And the whole store reloads equal.
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(try JSONEncoder().encode(reloaded.progress).count, data.count)
    }

    func test_negativeCountAndBaselinesAreClampedOnDecode() throws {
        let json = #"""
        {"prestigeCount": -4, "runBaselinePlaySeconds": -10, "runBaselineEarned": -1,
         "runBaselineServed": -2, "runBaselineFailed": -3, "totalServed": 5}
        """#
        let p = try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
        XCTAssertEqual(p.prestigeCount, 0)
        XCTAssertEqual(p.runBaselinePlaySeconds, 0)
        XCTAssertEqual(p.runBaselineEarned, 0)
        XCTAssertEqual(p.runBaselineServed, 0)
        XCTAssertEqual(p.runBaselineFailed, 0)
        XCTAssertEqual(p.totalServed, 5)
    }

    func test_durationDoesNotTrapOnHugeSeconds() {
        XCTAssertNotNil(StatsFormat.duration(seconds: 1e18, locale: Locale(identifier: "ko_KR")))
        XCTAssertNotNil(StatsFormat.duration(seconds: .greatestFiniteMagnitude, locale: Locale(identifier: "en_US")))
        XCTAssertNil(StatsFormat.duration(seconds: .infinity))
    }

    func test_unspentPlots() {
        var farm = FarmState()
        XCTAssertTrue(PrestigeSystem.hasUnspentPlots(farm: farm))
        while farm.plots.count < FarmSystem.maxPlots { farm.plots.append(FarmPlot()) }
        // Cost table ends before maxPlots; the helper follows the table, not the constant.
        XCTAssertEqual(PrestigeSystem.hasUnspentPlots(farm: farm),
                       FarmSystem.costForNextPlot(currentCount: farm.plots.count) != nil)
    }
}
