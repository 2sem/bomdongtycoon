import XCTest
@testable import GameCore

/// The 3.0.0 fun-and-balance pass: tap cooking, fever as a rush, tips, golden scaling, missions
/// that follow income, renovation, and the rating's tension.
@MainActor
final class FunPassTests: DotWorldTestCase {

    // MARK: Manual cook and fever

    func test_manualCook_landsAfterFourSeconds() {
        store.stall.menuStock = [0, 0, 0]
        store.stall.warehouse = 3
        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        store.tick(deltaTime: 3.9)
        XCTAssertEqual(store.stall.menuStock[0], 0)
        store.tick(deltaTime: 0.2)
        XCTAssertEqual(store.stall.menuStock[0], 1)
        XCTAssertEqual(store.stall.warehouse, 2)
    }

    func test_fever_manualCookIsInstant() {
        store.stall.warehouse = 3
        chargeFever()
        store.startFever()
        let before = store.stall.menuStock[0]
        XCTAssertTrue(store.startManualCook(menuIndex: 0))
        XCTAssertEqual(store.stall.menuStock[0], before + 1)
        XCTAssertEqual(store.stall.warehouse, 2)
        XCTAssertTrue(store.startManualCook(menuIndex: 0), "no 'already cooking' lock in fever: each tap is a portion")
        XCTAssertEqual(store.stall.menuStock[0], before + 2)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    func test_fever_instantCookStillNeedsWarehouseAndRoom() {
        chargeFever()
        store.startFever()
        store.stall.warehouse = 0
        XCTAssertFalse(store.startManualCook(menuIndex: 0))
        store.stall.warehouse = 5
        store.stall.menuStock[0] = EarningsSystem.maxStock(for: store.stall)
        XCTAssertFalse(store.startManualCook(menuIndex: 0))
        XCTAssertFalse(store.startManualCook(menuIndex: 1), "a locked dish still cannot be cooked")
    }

    func test_fever_tallyCountsSalesAndResetsOnTheNextFever() {
        store.stall.menuStock[0] = 5
        _ = store.sellItem(menuIndex: 0)
        XCTAssertEqual(store.feverEarned, 0, "sales outside fever are not tallied")
        chargeFever()
        store.startFever()
        _ = store.sellItem(menuIndex: 0)
        _ = store.sellItem(menuIndex: 0)
        XCTAssertEqual(store.feverEarned, 180, accuracy: 1e-9)
        store.tick(deltaTime: 15)
        XCTAssertFalse(store.isFeverActive)
        XCTAssertEqual(store.feverEarned, 180, accuracy: 1e-9, "kept for the summary after fever ends")
        serve(36)
        store.startFever()
        XCTAssertEqual(store.feverEarned, 0)
    }

    func test_fever_cropsRipenThreeTimesFaster() {
        store.farm.plots[1].isPlanted = true
        store.farm.plots[1].growth = 0
        store.tick(deltaTime: 2)
        let normal = store.farm.plots[1].growth
        store.farm.plots[1].growth = 0
        chargeFever()
        store.startFever()
        store.tick(deltaTime: 2)
        XCTAssertEqual(store.farm.plots[1].growth, normal * 3, accuracy: 1e-9)
    }

    // MARK: Tips

    func test_rollTip_twentyPercent_thirtyFivePercentInFever_gourmetAlways() {
        script.values = [0.19, 0.20]
        XCTAssertTrue(store.rollTip(isGourmet: false))
        XCTAssertFalse(store.rollTip(isGourmet: false))

        let calls = script.calls
        XCTAssertTrue(store.rollTip(isGourmet: true))
        XCTAssertEqual(script.calls, calls, "a gourmet's tip is certain and consumes no roll")

        chargeFever()
        store.startFever()
        script.values = [0.34, 0.35]
        XCTAssertTrue(store.rollTip(isGourmet: false))
        XCTAssertFalse(store.rollTip(isGourmet: false))
    }

    func test_tipAmount_isHalfTheSale_gourmetFull() {
        XCTAssertEqual(GameStore.tipAmount(forSale: 80, isGourmet: false), 40)
        XCTAssertEqual(GameStore.tipAmount(forSale: 240, isGourmet: true), 240)
    }

    func test_collectTip_paysCoinsAndTotalEarned_butNotTheOfflineWindow() {
        let coins = store.stall.coins
        store.progress.earningRate = 0
        store.collectTip(amount: 40)
        XCTAssertEqual(store.stall.coins, coins + 40)
        XCTAssertEqual(store.progress.totalEarned, 40)
        XCTAssertEqual(store.progress.totalTipsCollected, 1)
        store.tick(deltaTime: 5)   // closes the 5 s earning window
        XCTAssertEqual(store.progress.earningRate, 0, "a tip is not income the shop earns while away")
    }

    func test_collectTip_ignoresNonPositive_andCountsTowardEarnMission() {
        store.collectTip(amount: 0)
        XCTAssertEqual(store.progress.totalTipsCollected, 0)
        store.replaceMissionsForTesting(MissionState(dayKey: MissionSystem.dayKey(for: clock.date, calendar: DotWorldTestSupport.calendar()),
            missions: [Mission(id: "x-earnCoins", kind: .earnCoins, target: 100, reward: 100)]))
        store.collectTip(amount: 30)
        XCTAssertEqual(store.missions[0].progress, 30)
    }

    // MARK: Golden

    private func ripeGoldenPlotWithWorker() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        store.farm.plots[0].isGolden = true
        store.stall.warehouse = 0
        store.stall.coins = 0
    }

    func test_golden_workerWaitsTwentySeconds_thenTakesItAsACrop() {
        ripeGoldenPlotWithWorker()
        store.tick(deltaTime: 19)
        XCTAssertTrue(store.farm.plots[0].isGolden)
        XCTAssertEqual(store.stall.warehouse, 0)
        store.tick(deltaTime: 1.5)
        XCTAssertFalse(store.farm.plots[0].isGolden)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield)
        XCTAssertEqual(store.stall.coins, 0, "taken as a normal crop: no bonus")
    }

    func test_golden_graceCountsOnlyWhileTheAppIsActive() {
        ripeGoldenPlotWithWorker()
        store.isAppActive = false
        store.tick(deltaTime: 60)
        XCTAssertTrue(store.farm.plots[0].isGolden)
        store.isAppActive = true
        store.tick(deltaTime: 19)
        XCTAssertTrue(store.farm.plots[0].isGolden)
        store.tick(deltaTime: 1.5)
        XCTAssertFalse(store.farm.plots[0].isGolden)
    }

    func test_golden_manualHarvestInsideTheWindowStillPaysTheBonus() {
        ripeGoldenPlotWithWorker()
        store.stall.warehouse = 0
        store.tick(deltaTime: 5)
        let result = store.harvest(plotIndex: 0)
        XCTAssertEqual(result?.isGolden, true)
        XCTAssertGreaterThan(result?.bonusCoins ?? 0, 0)
    }

    func test_golden_nextGoldenOnTheSamePlotGetsAFreshWindow() {
        ripeGoldenPlotWithWorker()
        store.tick(deltaTime: 15)
        store.harvest(plotIndex: 0)
        store.tick(deltaTime: 1)   // forgets the old age
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        store.farm.plots[0].isGolden = true
        store.tick(deltaTime: 10)
        XCTAssertTrue(store.farm.plots[0].isGolden, "10 s into a new window, not 26 s")
    }

    func test_goldenBonus_isTheLargerOfFifteenSalesAndFortyFiveSecondsOfIncome() {
        store.progress.earningRate = 0
        XCTAssertEqual(GameStore.goldenBonus(stall: store.stall, progress: store.progress), 15 * 30, accuracy: 1e-9)
        store.progress.earningRate = 100
        XCTAssertEqual(GameStore.goldenBonus(stall: store.stall, progress: store.progress), 4500, accuracy: 1e-9)
        store.progress.earningRate = 1
        XCTAssertEqual(GameStore.goldenBonus(stall: store.stall, progress: store.progress), 450, accuracy: 1e-9)
    }

    // MARK: Missions

    func test_reward_isTheLargestOfFloorSalesAndFiveMinutesOfIncome() {
        XCTAssertEqual(MissionSystem.reward(earningRate: 1.2, bestSalePrice: 30), 360, accuracy: 1e-9)
        XCTAssertEqual(MissionSystem.reward(earningRate: 1.2, bestSalePrice: 0), 360, accuracy: 1e-9)
        XCTAssertEqual(MissionSystem.reward(earningRate: 0, bestSalePrice: 30), 300, accuracy: 1e-9)
        XCTAssertEqual(MissionSystem.reward(earningRate: 40_000, bestSalePrice: 5_000), 12_000_000, accuracy: 1e-6)
    }

    func test_earnTarget_keepsItsFloors_andScalesTo240SecondsOfIncome() {
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 0, earningRate: 0, bestSalePrice: 0), 360)
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 2, earningRate: 40_000, bestSalePrice: 5_000), 9_600_000)
    }

    func test_gourmetMission_explainsItselfBelowTheRatingFloor() {
        XCTAssertEqual(MissionSystem.blockedReason(kind: .serveGourmets, rating: 2.9), .needsRating(3.0))
        XCTAssertNil(MissionSystem.blockedReason(kind: .serveGourmets, rating: 3.0))
        XCTAssertNil(MissionSystem.blockedReason(kind: .harvest, rating: 1.0))
    }

    private func rolledToday() -> [Mission] {
        let key = MissionSystem.dayKey(for: clock.date, calendar: DotWorldTestSupport.calendar())
        let missions = (0..<3).map { Mission(id: "\(key)-\($0)", kind: MissionKind.allCases[$0], target: 5, progress: 5, reward: 150) }
        store.replaceMissionsForTesting(MissionState(dayKey: key, missions: missions))
        return missions
    }

    func test_dailyBonus_isTwoRewards_andNeedsAllThreeComplete() {
        var missions = rolledToday()
        XCTAssertEqual(store.dailyBonusReward, 300)
        XCTAssertTrue(store.isDailyBonusReady)
        XCTAssertEqual(store.unclaimedCompletedMissionCount, 4, "three missions plus the bonus")

        missions[2].progress = 4
        store.replaceMissionsForTesting(MissionState(dayKey: store.missions.isEmpty ? 0 : MissionSystem.dayKey(for: clock.date, calendar: DotWorldTestSupport.calendar()), missions: missions))
        XCTAssertFalse(store.isDailyBonusReady)
        XCTAssertNil(store.claimDailyBonus())
    }

    func test_dailyBonus_paysOnce() {
        _ = rolledToday()
        let coins = store.stall.coins
        XCTAssertEqual(store.claimDailyBonus(), 300)
        XCTAssertEqual(store.stall.coins, coins + 300)
        XCTAssertEqual(store.progress.totalEarned, 300)
        XCTAssertNil(store.claimDailyBonus())
        XCTAssertTrue(store.isDailyBonusClaimed)
        XCTAssertEqual(store.unclaimedCompletedMissionCount, 3, "the bonus no longer counts")
    }

    func test_dailyBonus_survivesARelaunch_andResetsWithTheDay() {
        _ = rolledToday()
        store.claimDailyBonus()
        let reloaded = makeStore()
        XCTAssertTrue(reloaded.isDailyBonusClaimed)
        XCTAssertEqual(reloaded.dailyBonusReward, 300)

        clock.date = DotWorldTestSupport.date(2026, 11, 15)
        reloaded.tick(deltaTime: 1)
        XCTAssertFalse(reloaded.isDailyBonusClaimed)
        XCTAssertFalse(reloaded.isDailyBonusReady)
    }

    func test_missionState_decodesASavedDayFromBeforeTheBonus() throws {
        let json = #"{"dayKey":20261114,"missions":[{"id":"a","kind":"harvest","target":5,"progress":5,"isClaimed":false,"reward":150}]}"#
        let state = try JSONDecoder().decode(MissionState.self, from: Data(json.utf8))
        XCTAssertEqual(state.bonusReward, 300)
        XCTAssertFalse(state.isBonusClaimed)
        XCTAssertTrue(state.isBonusReady)
    }

    func test_emptyMissionDay_hasNoBonus() {
        store.replaceMissionsForTesting(MissionState())
        XCTAssertFalse(store.isDailyBonusReady)
    }

    // MARK: Renovation

    private func maxedStall() {
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
    }

    func test_renovation_costGrowsByTwentyFivePercent_roundedToTwoFigures() {
        XCTAssertEqual(RenovationSystem.cost(forLevel: 0), 30_000)
        XCTAssertEqual(RenovationSystem.cost(forLevel: 1), 38_000)    // 37,500
        XCTAssertEqual(RenovationSystem.cost(forLevel: 2), 47_000)    // 46,875
        XCTAssertEqual(RenovationSystem.cost(forLevel: 3), 59_000)    // 58,594
        XCTAssertEqual(RenovationSystem.cost(forLevel: 4), 73_000)    // 73,242
    }

    func test_renovation_unlocksAtTheFinalStallTier() {
        XCTAssertNil(RenovationSystem.nextCost(for: store.stall))
        store.stall.coins = 1e9
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.stall.renovationLevel, 0, "locked below the final stall tier")
        maxedStall()
        XCTAssertEqual(RenovationSystem.nextCost(for: store.stall), 30_000)
    }

    func test_renovation_purchaseChargesAndRaisesTheLevel_untilCoinsRunOut() {
        maxedStall()
        store.stall.coins = 40_000
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.stall.renovationLevel, 1)
        XCTAssertEqual(store.stall.coins, 10_000, accuracy: 1e-9)
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.stall.renovationLevel, 1, "38,000 is out of reach")
    }

    func test_renovation_isEightPercentPerLevel_composedInThePricePerItem() {
        let base = EarningsSystem.pricePerItem(for: store.stall, menuIndex: 0)
        store.stall.renovationLevel = 4
        XCTAssertEqual(EarningsSystem.pricePerItem(for: store.stall, menuIndex: 0), base * 1.32, accuracy: 1e-9)
        XCTAssertEqual(EarningsSystem.salePrice(for: store.stall, menuIndex: 0, prestigeCount: 0), base * 1.32, accuracy: 1e-9)
        store.stall.menuCooks = [1, 0, 0]
        let perSecond = EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0)
        store.stall.renovationLevel = 0
        XCTAssertEqual(perSecond, EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0) * 1.32, accuracy: 1e-9,
                       "offline earnings read coinsPerSecond, so they inherit it")
    }

    func test_renovation_isTheGoalOnlyAfterEverythingElseIsBought() {
        var s = StallState()
        s.staffTier = UpgradeDefinitions.staff.count
        s.menuTier = UpgradeDefinitions.menu.count - 1
        s.stallTier = UpgradeDefinitions.stall.count - 1
        s.locationTier = UpgradeDefinitions.location.count - 1
        s.recipeLevels = [RecipeSystem.maxLevel, RecipeSystem.maxLevel, RecipeSystem.maxLevel]
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .renovation)
        XCTAssertEqual(EarningsSystem.nextGoalUpgrade(for: s)?.coinCost, 30_000)
        XCTAssertEqual(EarningsSystem.nextGoalLabel(for: s), .renovation)
        XCTAssertTrue(EarningsSystem.isOnlyRenovationLeft(for: s), "the new-spring capsule keeps its priority")
        s.renovationLevel = 2
        XCTAssertEqual(EarningsSystem.nextGoalUpgrade(for: s)?.coinCost, 47_000)

        s.locationTier = 1
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .renovation, "the cheapest purchase drives the goal")
        XCTAssertFalse(EarningsSystem.isOnlyRenovationLeft(for: s))
    }

    func test_renovationLevel_decodesAsZeroFromAnOldSave_andClampsNegative() throws {
        let old = try JSONDecoder().decode(StallState.self, from: Data(#"{"coins":5}"#.utf8))
        XCTAssertEqual(old.renovationLevel, 0)
        let bad = try JSONDecoder().decode(StallState.self, from: Data(#"{"renovationLevel":-3}"#.utf8))
        XCTAssertEqual(bad.renovationLevel, 0)
        var s = StallState()
        s.renovationLevel = 7
        let back = try JSONDecoder().decode(StallState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.renovationLevel, 7)
    }

    func test_newSpring_resetsRenovation_butKeepsTipsCollected() {
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.renovationLevel = 3
        store.collectTip(amount: 10)
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.stall.renovationLevel, 0)
        XCTAssertEqual(store.progress.totalTipsCollected, 1)
    }

    // MARK: Rating tension

    func test_rating_decayScalesWithRating() {
        store.progress.rating = 3.0
        store.tick(deltaTime: 100)
        XCTAssertEqual(store.progress.rating, 2.95, accuracy: 1e-9)
        store.progress.rating = 5.0
        store.tick(deltaTime: 100)
        XCTAssertEqual(store.progress.rating, 4.85, accuracy: 1e-9)
    }

    func test_rating_servedGainIsTwoHundredthsFast_oneHundredthSlow() {
        store.progress.rating = 3.0
        store.recordServed(waitTime: 2.9)
        XCTAssertEqual(store.progress.rating, 3.02, accuracy: 1e-9)
        store.recordServed(waitTime: 3.0)
        XCTAssertEqual(store.progress.rating, 3.0 + 0.02 + 0.01 * (5 - 3.02) / 2, accuracy: 1e-9)
    }

    func test_rating_gainTapersTowardFive() {
        store.progress.rating = 4.0
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 4.01, accuracy: 1e-9)
        store.progress.rating = 4.5
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 4.505, accuracy: 1e-9)
        store.progress.rating = 5.0
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 5.0, accuracy: 1e-9)
    }
}
