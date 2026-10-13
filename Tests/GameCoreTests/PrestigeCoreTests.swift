import XCTest
@testable import GameCore

@MainActor
final class PrestigeCoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "PrestigeCoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    private func makeStore() -> GameStore {
        let store = GameStore(defaults: defaults)
        store.farm.plots[0].workerType = .none
        return store
    }

    private func decodeProgress(_ json: String) throws -> PlayerProgress {
        try JSONDecoder().decode(PlayerProgress.self, from: Data(json.utf8))
    }

    // MARK: Multiplier

    func test_multiplierTable() {
        let expected = [1.00, 1.40, 1.67, 1.91, 2.13, 2.34]
        for (n, want) in expected.enumerated() {
            XCTAssertEqual(PrestigeSystem.legacyMultiplier(prestigeCount: n), want, accuracy: 0.005, "n=\(n)")
        }
    }

    func test_multiplierAtZeroIsExactlyOne_andNegativeIsClamped() {
        XCTAssertEqual(PrestigeSystem.legacyMultiplier(prestigeCount: 0), 1.0)
        XCTAssertEqual(PrestigeSystem.legacyMultiplier(prestigeCount: -3), 1.0)
    }

    func test_multiplierText_trimsToTwoDecimals() {
        XCTAssertEqual(PrestigeSystem.multiplierText(prestigeCount: 1), "x1.4")
        XCTAssertEqual(PrestigeSystem.multiplierText(prestigeCount: 2), "x1.67")
        XCTAssertEqual(PrestigeSystem.multiplierText(prestigeCount: 5), "x2.34")
        XCTAssertEqual(PrestigeSystem.multiplierText(prestigeCount: 0), "x1")
        XCTAssertEqual(PrestigeSystem.multiplierNumber(2.0), "2")
        XCTAssertEqual(PrestigeSystem.multiplierNumber(2 * 1.4), "2.8")
    }

    // MARK: Sale price

    func test_salePrice_composesMenuLocationCashierLegacy() {
        var stall = StallState()
        stall.locationTier = 2          // x4
        stall.cashierCount = 1
        stall.cashierTier = 1
        stall.cashierEnergy = 1
        let legacy = PrestigeSystem.legacyMultiplier(prestigeCount: 2)
        let price = EarningsSystem.salePrice(for: stall, menuIndex: 2, prestigeCount: 2)
        XCTAssertEqual(price, 30 * 6.0 * 4.0 * 1.25 * legacy, accuracy: 0.0001)
    }

    func test_salePrice_veteranReplacesBonus_tiredLosesIt_legacyStays() {
        var stall = StallState()
        stall.cashierCount = 1
        stall.cashierTier = EarningsSystem.veteranCashierTier
        stall.cashierEnergy = 1
        let legacy = PrestigeSystem.legacyMultiplier(prestigeCount: 1)
        XCTAssertEqual(EarningsSystem.salePrice(for: stall, menuIndex: 0, prestigeCount: 1), 30 * 1.4 * legacy, accuracy: 0.0001)
        stall.cashierEnergy = ShopStaffPresence.lowEnergyThreshold - 0.01
        XCTAssertEqual(EarningsSystem.salePrice(for: stall, menuIndex: 0, prestigeCount: 1), 30 * legacy, accuracy: 0.0001)
    }

    func test_sellItem_readsPrestigeCountFromProgress() {
        let store = makeStore()
        store.stall.menuStock[0] = 5
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.0001)
        store.progress.prestigeCount = 3
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.9118, accuracy: 0.01)
    }

    func test_coinsPerSecond_includesLegacy_costsUnscaled() {
        var stall = StallState()
        stall.menuCooks = [1, 0, 0]
        let base = EarningsSystem.coinsPerSecond(for: stall, prestigeCount: 0)
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: stall, prestigeCount: 1), base * 1.4, accuracy: 0.0001)
        // Upgrade costs are definition data, untouched by the multiplier.
        XCTAssertEqual(UpgradeDefinitions.menu[1].coinCost, 1_000)
    }

    func test_offlineEarnings_doNotApplyLegacyAgain() {
        let store = makeStore()
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.prestigeCount = 4
        store.progress.earningRate = 10
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.calculateOfflineEarnings()
        // rate x elapsed x efficiency only: the EMA already holds legacy-priced sales.
        XCTAssertEqual(store.offlineEarnings, 10 * 3600 * GameStore.offlineEfficiency, accuracy: 5)
    }

    // MARK: Decoding

    func test_newFieldsDefault_whenAbsentOrEmptyObject() throws {
        for json in ["{}", #"{"rating": 4.0, "totalServed": 3}"#] {
            let p = try decodeProgress(json)
            XCTAssertEqual(p.prestigeCount, 0)
            XCTAssertEqual(p.totalPlaySeconds, 0)
            XCTAssertEqual(p.runBaselinePlaySeconds, 0)
            XCTAssertEqual(p.runBaselineEarned, 0)
            XCTAssertEqual(p.runBaselineServed, 0)
            XCTAssertEqual(p.runBaselineFailed, 0)
            XCTAssertEqual(p.bestRating, 0)
            XCTAssertNil(p.fastestRunSeconds)
            XCTAssertFalse(p.hasSeenPrestigeIntro)
        }
    }

    func test_newFieldsDefault_whenMistyped() throws {
        let p = try decodeProgress("""
        {"prestigeCount": "two", "totalPlaySeconds": "x", "runBaselinePlaySeconds": [], "runBaselineEarned": {},
         "runBaselineServed": true, "runBaselineFailed": "1", "bestRating": "high",
         "fastestRunSeconds": "fast", "hasSeenPrestigeIntro": 7, "totalServed": 9}
        """)
        XCTAssertEqual(p.prestigeCount, 0)
        XCTAssertEqual(p.totalPlaySeconds, 0)
        XCTAssertEqual(p.runBaselinePlaySeconds, 0)
        XCTAssertEqual(p.runBaselineEarned, 0)
        XCTAssertEqual(p.runBaselineServed, 0)
        XCTAssertEqual(p.runBaselineFailed, 0)
        XCTAssertEqual(p.bestRating, 0)
        XCTAssertNil(p.fastestRunSeconds)
        XCTAssertFalse(p.hasSeenPrestigeIntro)
        XCTAssertEqual(p.totalServed, 9, "a bad new field must not cost the rest of the blob")
    }

    func test_newFieldsRoundTrip() throws {
        var p = PlayerProgress()
        p.prestigeCount = 2; p.totalPlaySeconds = 4000; p.runBaselinePlaySeconds = 1500
        p.runBaselineEarned = 99_000; p.runBaselineServed = 120; p.runBaselineFailed = 8
        p.bestRating = 4.7; p.fastestRunSeconds = 2400; p.hasSeenPrestigeIntro = true
        let back = try JSONDecoder().decode(PlayerProgress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.prestigeCount, 2)
        XCTAssertEqual(back.totalPlaySeconds, 4000)
        XCTAssertEqual(back.runBaselinePlaySeconds, 1500)
        XCTAssertEqual(back.runBaselineEarned, 99_000)
        XCTAssertEqual(back.runBaselineServed, 120)
        XCTAssertEqual(back.runBaselineFailed, 8)
        XCTAssertEqual(back.bestRating, 4.7)
        XCTAssertEqual(back.fastestRunSeconds, 2400)
        XCTAssertTrue(back.hasSeenPrestigeIntro)
    }

    func test_oldSave_loadsWithoutBackup_andUnchanged() throws {
        let json = #"""
        {"isFirstLaunch": false, "isShopNameSet": true, "shopName": "옛날 분식", "totalEarned": 98765,
         "earningRate": 3.25, "rating": 4.1, "totalServed": 500, "totalFailed": 12}
        """#
        defaults.set(Data(json.utf8), forKey: "gameStore.progress")
        let store = GameStore(defaults: defaults)
        XCTAssertNil(store.corruptBackup(of: .progress))
        let p = store.progress
        XCTAssertEqual(p.totalEarned, 98765)
        XCTAssertEqual(p.totalServed, 500)
        XCTAssertEqual(p.rating, 4.1)
        XCTAssertEqual(p.prestigeCount, 0)
        // With zero baselines the run reads as the lifetime.
        XCTAssertEqual(p.runEarned, 98765)
        XCTAssertEqual(p.runServed, 500)
        XCTAssertEqual(p.highestRating, 4.1, "an old save has no bestRating; the live rating stands in")
    }

    // MARK: Run-relative values

    func test_runValues_subtractBaselines() {
        var p = PlayerProgress()
        p.totalEarned = 1000; p.runBaselineEarned = 400
        p.totalServed = 50; p.runBaselineServed = 30
        p.totalFailed = 9; p.runBaselineFailed = 4
        p.totalPlaySeconds = 900; p.runBaselinePlaySeconds = 600
        XCTAssertEqual(p.runEarned, 600)
        XCTAssertEqual(p.runServed, 20)
        XCTAssertEqual(p.runFailed, 5)
        XCTAssertEqual(p.runPlaySeconds, 300)
        p.runBaselineServed = 80   // a damaged baseline never reads negative
        XCTAssertEqual(p.runServed, 0)
    }

    func test_firstSaleGrace_usesRunBaseline() {
        let store = makeStore()
        store.progress.totalServed = 40
        store.progress.runBaselineServed = 40   // new run: nothing served yet
        let rating = store.progress.rating
        store.recordFailed()
        XCTAssertEqual(store.progress.rating, rating, accuracy: 0.0001)
        store.recordServed(waitTime: 0)
        let after = store.progress.rating
        store.recordFailed()
        XCTAssertEqual(store.progress.rating, after - 0.05, accuracy: 0.0001)
    }

    func test_bestRating_followsRatingUp_andNeverDown() {
        let store = makeStore()
        store.recordServed(waitTime: 0)
        let peak = store.progress.rating
        XCTAssertEqual(store.progress.bestRating, peak, accuracy: 0.0001)
        store.recordServed(waitTime: 0)
        store.recordFailed()
        XCTAssertGreaterThan(store.progress.bestRating, store.progress.rating)
        XCTAssertEqual(store.progress.highestRating, store.progress.bestRating)
    }

    // MARK: Play time

    func test_playTime_accumulatesWhileActive() {
        let store = makeStore()
        for _ in 0..<10 { store.tick(deltaTime: 0.5) }
        XCTAssertEqual(store.progress.totalPlaySeconds, 5, accuracy: 0.0001)
    }

    func test_playTime_excludesPausedIntroAndBackground() {
        let store = makeStore()
        store.isSimulationPaused = true
        store.tick(deltaTime: 10)
        store.isSimulationPaused = false
        store.isAppActive = false
        store.tick(deltaTime: 10)
        store.isAppActive = true
        XCTAssertEqual(store.progress.totalPlaySeconds, 0)
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.progress.totalPlaySeconds, 1, accuracy: 0.0001)
    }

    func test_playTime_excludesOfflineTime() {
        let store = makeStore()
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = 5
        store.progress.lastActiveDate = Date().addingTimeInterval(-7200)
        store.calculateOfflineEarnings()
        store.collectOfflineEarnings()
        XCTAssertEqual(store.progress.totalPlaySeconds, 0)
    }

    func test_playTime_isFlushedOnTheActivitySaveCadence() {
        let store = makeStore()
        store.tick(deltaTime: 4)
        XCTAssertNil(defaults.data(forKey: "gameStore.progress"), "no per-tick disk write")
        store.tick(deltaTime: 1.5)   // crosses the 5 s window
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.progress.totalPlaySeconds, 5.5, accuracy: 0.0001)
    }

    // MARK: Formatting

    func test_duration_underAMinuteIsNil() {
        XCTAssertNil(StatsFormat.duration(seconds: 0))
        XCTAssertNil(StatsFormat.duration(seconds: 59.9))
    }

    func test_duration_abbreviatesHoursAndWholeMinutes() throws {
        let locale = Locale(identifier: "en_US")
        let text = try XCTUnwrap(StatsFormat.duration(seconds: 3600 + 5 * 60 + 59, locale: locale))
        XCTAssertTrue(text.contains("1") && text.contains("5"), text)
        XCTAssertFalse(text.contains("59"), "seconds are dropped: \(text)")
        let minutesOnly = try XCTUnwrap(StatsFormat.duration(seconds: 125, locale: locale))
        XCTAssertTrue(minutesOnly.contains("2"), minutesOnly)
        XCTAssertFalse(minutesOnly.contains("0"), "no zero-hour unit: \(minutesOnly)")
    }

    func test_successRate() {
        XCTAssertNil(StatsFormat.successRate(served: 0, failed: 0))
        XCTAssertEqual(StatsFormat.successRate(served: 3, failed: 1), "75%")
        XCTAssertEqual(StatsFormat.successRate(served: 0, failed: 4), "0%")
        XCTAssertEqual(StatsFormat.successRate(served: 199, failed: 1), "99%")
    }

    // MARK: Cashier working pose

    func test_cashierRecentlySold_holdsForTheBusyWindow() {
        let store = makeStore()
        store.stall.cashierCount = 1
        store.stall.menuStock[0] = 3
        XCTAssertFalse(store.cashierRecentlySold)
        _ = store.sellItem(menuIndex: 0)
        XCTAssertTrue(store.cashierRecentlySold)
        store.tick(deltaTime: 1.0)
        XCTAssertTrue(store.cashierRecentlySold)
        store.tick(deltaTime: 1.1)
        XCTAssertFalse(store.cashierRecentlySold)
    }

    func test_presence_workingFollowsRecentSale() {
        var stall = StallState()
        stall.cashierCount = 1
        XCTAssertEqual(ShopStaffPresence(stall: stall).cashier?.isWorking, false)
        XCTAssertEqual(ShopStaffPresence(stall: stall, cashierRecentlySold: true).cashier?.isWorking, true)
    }

    func test_noCashier_neverSetsBusyWindow() {
        let store = makeStore()
        store.stall.menuStock[0] = 3
        _ = store.sellItem(menuIndex: 0)
        XCTAssertFalse(store.cashierRecentlySold)
    }
}
