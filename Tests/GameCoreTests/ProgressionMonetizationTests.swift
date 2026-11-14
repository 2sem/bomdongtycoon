import XCTest
@testable import GameCore

@MainActor
final class RecipeAndPacingTests: DotWorldTestCase {

    private func maxedRecipes(_ s: inout StallState) {
        s.recipeLevels = Array(repeating: RecipeSystem.maxLevel, count: UpgradeDefinitions.menu.count)
    }

    // MARK: Recipe levels

    func test_recipeCost_isBaseTimesGrowth_toTwoSignificantFigures() {
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 0, level: 0), 150)
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 0, level: 1), 230)   // 225
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 0, level: 2), 340)   // 337.5
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 1, level: 0), 600)
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 1, level: 1), 900)
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 2, level: 0), 2_500)
        XCTAssertEqual(RecipeSystem.cost(menuIndex: 2, level: 1), 3_800)  // 3,750
        XCTAssertNil(RecipeSystem.cost(menuIndex: 0, level: RecipeSystem.maxLevel))
        XCTAssertNil(RecipeSystem.cost(menuIndex: 3, level: 0))
    }

    func test_recipeLevel_addsTenPercentToThatDishOnly_andComposesInSalePrice() {
        store.stall.menuTier = 2
        let base = EarningsSystem.pricePerItem(for: store.stall, menuIndex: 1)
        store.stall.recipeLevels = [0, 5, 0]
        XCTAssertEqual(EarningsSystem.pricePerItem(for: store.stall, menuIndex: 1), base * 1.5, accuracy: 1e-9)
        XCTAssertEqual(EarningsSystem.pricePerItem(for: store.stall, menuIndex: 0), 30, accuracy: 1e-9)
        XCTAssertEqual(EarningsSystem.salePrice(for: store.stall, menuIndex: 1, prestigeCount: 0), base * 1.5, accuracy: 1e-9)
        store.stall.menuCooks = [0, 1, 0]
        let perSecond = EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0)
        store.stall.recipeLevels = [0, 0, 0]
        XCTAssertEqual(perSecond, EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0) * 1.5, accuracy: 1e-9,
                       "offline earnings read coinsPerSecond, so they inherit it")
    }

    func test_purchaseRecipe_paysAndLevels_untilMax_andNeverForALockedDish() {
        store.stall.coins = 1_000
        store.purchaseUpgrade(.recipe(menuIndex: 1))
        XCTAssertEqual(store.stall.recipeLevels, [0, 0, 0], "봄동김치 is still locked")
        XCTAssertEqual(store.stall.coins, 1_000)

        store.purchaseUpgrade(.recipe(menuIndex: 0))
        XCTAssertEqual(store.stall.recipeLevels, [1, 0, 0])
        XCTAssertEqual(store.stall.coins, 850, accuracy: 1e-9)
        store.stall.coins = 100
        store.purchaseUpgrade(.recipe(menuIndex: 0))
        XCTAssertEqual(store.stall.recipeLevels[0], 1, "230 is out of reach")

        store.stall.recipeLevels[0] = RecipeSystem.maxLevel
        store.stall.coins = 1e12
        store.purchaseUpgrade(.recipe(menuIndex: 0))
        XCTAssertEqual(store.stall.recipeLevels[0], RecipeSystem.maxLevel)
    }

    func test_recipeLevels_decodeTolerantly_resizeAndClamp() throws {
        let old = try JSONDecoder().decode(StallState.self, from: Data(#"{"coins":5}"#.utf8))
        XCTAssertEqual(old.recipeLevels, [0, 0, 0])
        let odd = try JSONDecoder().decode(StallState.self, from: Data(#"{"recipeLevels":[3,99,-4,7,7]}"#.utf8))
        XCTAssertEqual(odd.recipeLevels, [3, RecipeSystem.maxLevel, 0])
        let short = try JSONDecoder().decode(StallState.self, from: Data(#"{"recipeLevels":[4]}"#.utf8))
        XCTAssertEqual(short.recipeLevels, [4, 0, 0])
        let wrong = try JSONDecoder().decode(StallState.self, from: Data(#"{"recipeLevels":"x"}"#.utf8))
        XCTAssertEqual(wrong.recipeLevels, [0, 0, 0])
    }

    func test_newSpring_resetsRecipeLevels() {
        store.stall.recipeLevels = [4, 2, 1]
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.stall.recipeLevels, [0, 0, 0])
    }

    // MARK: Goal selection

    func test_goal_isNeverEmpty_atAnyStage_andTheCheapestWins() {
        var s = StallState()
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .recipe(menuIndex: 0))
        XCTAssertEqual(EarningsSystem.nextGoalUpgrade(for: s)?.coinCost, 150)
        for stall in 0..<UpgradeDefinitions.stall.count {
            for menu in 0..<UpgradeDefinitions.menu.count {
                for location in 0..<UpgradeDefinitions.location.count {
                    s = StallState()
                    s.stallTier = stall; s.menuTier = menu; s.locationTier = location
                    s.staffTier = UpgradeDefinitions.staff.count
                    XCTAssertNotNil(EarningsSystem.nextGoalUpgrade(for: s), "stall \(stall) menu \(menu) location \(location)")
                }
            }
        }
    }

    func test_goal_recipeCostsClimbPastTheStructuralPurchases() {
        var s = StallState()
        s.recipeLevels = [8, 0, 0]   // 150 x 1.5^8 = 3,844
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .staff, "the 300 hire is now cheaper than another 겉절이 level")
    }

    func test_onlyRenovationLeft_ignoresRecipeLevels() {
        var s = StallState()
        s.staffTier = UpgradeDefinitions.staff.count
        s.menuTier = UpgradeDefinitions.menu.count - 1
        s.stallTier = UpgradeDefinitions.stall.count - 1
        s.locationTier = UpgradeDefinitions.location.count - 1
        XCTAssertTrue(EarningsSystem.isOnlyRenovationLeft(for: s))
        XCTAssertEqual(EarningsSystem.nextGoalType(for: s), .recipe(menuIndex: 0))
        XCTAssertEqual(EarningsSystem.nextGoalLabel(for: s), .recipe)
    }

    // MARK: New dish, orders

    func test_buyingAMenuTier_stocksThreePortions_cappedAtMaxStock() {
        store.stall.coins = 10_000
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.menuTier, 1)
        XCTAssertEqual(store.stall.menuStock, [5, 3, 0], "a new game opens with 5 겉절이")

        store.stall.menuStock[2] = 14
        store.stall.coins = 10_000
        store.purchaseUpgrade(.menu)
        XCTAssertEqual(store.stall.menuStock[2], 15, "포장마차 holds 15")
    }

    func test_orders_onlyDishesTheShopCanMake() {
        store.stall.menuTier = 2
        store.stall.menuStock = [0, 0, 0]
        XCTAssertEqual(EarningsSystem.orderableMenus(for: store.stall), [0, 1, 2], "nothing stocked: any unlocked dish")
        store.stall.menuStock = [0, 4, 0]
        XCTAssertEqual(EarningsSystem.orderableMenus(for: store.stall), [1])
        store.stall.menuCooks = [0, 0, 2]
        XCTAssertEqual(EarningsSystem.orderableMenus(for: store.stall), [1, 2], "a cook counts like stock")
        store.stall.menuTier = 1
        XCTAssertEqual(EarningsSystem.orderableMenus(for: store.stall), [1], "locked dishes are never asked for")
    }

    func test_rollOrderedMenu_usesTheInjectedRandom() {
        store.stall.menuTier = 2
        store.stall.menuStock = [5, 0, 5]
        script.values = [0.0, 0.99]
        XCTAssertEqual(store.rollOrderedMenu(), 0)
        XCTAssertEqual(store.rollOrderedMenu(), 2)
    }

    // MARK: Fever pace

    func test_feverCharge_isSizedToPace() {
        XCTAssertEqual(FeverSystem.charge(perServeAtInterval: 20), 20.0 / 90, accuracy: 1e-9)
        XCTAssertEqual(FeverSystem.charge(perServeAtInterval: 5), 5.0 / 90, accuracy: 1e-9)
        XCTAssertEqual(FeverSystem.charge(perServeAtInterval: 1.2), 1.0 / 36, accuracy: 1e-9, "floor")
    }

    func test_feverCharge_usesTheNonFeverSpawnInterval() {
        store.progress.rating = 3.2   // 5 s
        store.recordServed(waitTime: 5)
        XCTAssertEqual(store.feverCharge, 5.0 / 90, accuracy: 1e-9)
        store.progress.rating = 2.2   // 12 s
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.feverCharge, 5.0 / 90 + 12.0 / 90 * 1.5, accuracy: 1e-9, "fast serve keeps its x1.5")
    }

    func test_aSteadyPlayerAtThreeStars_fillsTheGaugeInAboutNinetySeconds() {
        store.progress.rating = 3.2
        var served = 0
        while !store.isFeverReady { store.recordServed(waitTime: 5); served += 1 }
        XCTAssertEqual(served, 18)
        XCTAssertEqual(Double(served) * 5, 90, "18 customers at the 5 s interval")
    }

    // MARK: Offline popup

    private func away(seconds: Double, rate: Double) {
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = rate
        store.progress.lastActiveDate = Date().addingTimeInterval(-seconds)
        store.stall.coins = 0
    }

    func test_offline_underAMinute_isCreditedSilently() {
        away(seconds: 50, rate: 1_000)
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 0)
        XCTAssertEqual(store.stall.coins, 50 * 1_000 * 0.25, accuracy: 100)
    }

    func test_offline_smallAmount_isCreditedSilently() {
        away(seconds: 600, rate: 0.5)   // 75 coins, best sale 30 x 10 = 300
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 0)
        XCTAssertEqual(store.stall.coins, 75, accuracy: 1)
    }

    func test_offline_worthShowing_opensThePopup() {
        away(seconds: 3_600, rate: 2)   // 1,800 coins
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 1_800, accuracy: 5)
        XCTAssertEqual(store.stall.coins, 0)
    }

    // MARK: Missions x2

    private func oneDoneMission() {
        let key = MissionSystem.dayKey(for: clock.date, calendar: DotWorldTestSupport.calendar())
        let m = Mission(id: "\(key)-harvest", kind: .harvest, target: 1, progress: 1, reward: 200)
        store.replaceMissionsForTesting(MissionState(dayKey: key, missions: [m]))
        store.stall.coins = 0
    }

    func test_claimMission_multiplierDoublesTheReward() {
        oneDoneMission()
        let id = store.missions[0].id
        XCTAssertEqual(store.claimMission(id: id, multiplier: 2), 400)
        XCTAssertEqual(store.stall.coins, 400)
        XCTAssertNil(store.claimMission(id: id, multiplier: 2), "paid once")
    }

    func test_claimMission_defaultMultiplierIsOne() {
        oneDoneMission()
        XCTAssertEqual(store.claimMission(id: store.missions[0].id), 200)
    }

    func test_claimDailyBonus_multiplier() {
        oneDoneMission()
        let bonus = store.dailyBonusReward
        XCTAssertEqual(store.claimDailyBonus(multiplier: 2), bonus * 2)
        XCTAssertNil(store.claimDailyBonus(multiplier: 2))
    }
}

@MainActor
final class AdPlacementTests: DotWorldTestCase {

    // MARK: Fever recharge

    func test_feverAd_notOfferedInTheFirstThreeMinutes() {
        store.progress.totalPlaySeconds = 179
        XCTAssertFalse(store.isFeverAdAvailable)
        XCTAssertFalse(store.claimFeverAdCharge())
        store.progress.totalPlaySeconds = 180
        XCTAssertTrue(store.isFeverAdAvailable)
    }

    func test_feverAd_fillsTheGauge_thenCoolsDownForFiveMinutes() {
        store.progress.totalPlaySeconds = 400
        XCTAssertTrue(store.claimFeverAdCharge())
        XCTAssertTrue(store.isFeverReady)
        XCTAssertEqual(store.adFeverCooldownRemaining, 300)
        XCTAssertFalse(store.isFeverAdAvailable, "a full gauge needs no recharge")
        XCTAssertTrue(store.startFever())
        store.tick(deltaTime: 15)
        XCTAssertFalse(store.isFeverAdAvailable, "cooling down")
        XCTAssertFalse(store.claimFeverAdCharge())
        store.tick(deltaTime: 285)
        XCTAssertEqual(store.adFeverCooldownRemaining, 0, accuracy: 1e-9)
        XCTAssertTrue(store.isFeverAdAvailable)
    }

    func test_feverAd_onlyBelowSeventyPercent() {
        store.progress.totalPlaySeconds = 400
        store.progress.rating = 4.6
        store.recordServed(waitTime: 5, isGourmet: false)
        XCTAssertTrue(store.isFeverAdAvailable)
        serve(24)   // 25/36 = 69%
        XCTAssertLessThan(store.feverCharge, 0.7)
        XCTAssertTrue(store.isFeverAdAvailable)
        serve(1)    // 26/36 = 72%
        XCTAssertGreaterThanOrEqual(store.feverCharge, 0.7)
        XCTAssertFalse(store.isFeverAdAvailable)
        XCTAssertFalse(store.claimFeverAdCharge())
    }

    func test_feverAd_closingTheOffer_hidesTheButtonForThreeMinutes() {
        store.progress.totalPlaySeconds = 400
        XCTAssertTrue(store.isFeverAdAvailable)
        store.declineFeverAd()
        XCTAssertFalse(store.isFeverAdAvailable)
        XCTAssertEqual(store.adFeverCooldownRemaining, 180)
        store.tick(deltaTime: 179)
        XCTAssertFalse(store.isFeverAdAvailable)
        store.tick(deltaTime: 1.5)
        XCTAssertTrue(store.isFeverAdAvailable)
    }

    func test_feverAd_declineNeverShortensALongerCooldown() {
        store.progress.totalPlaySeconds = 400
        XCTAssertTrue(store.claimFeverAdCharge())
        store.declineFeverAd()
        XCTAssertEqual(store.adFeverCooldownRemaining, 300)
    }

    func test_feverAd_notOfferedWhileFeverRuns() {
        store.progress.totalPlaySeconds = 400
        chargeFever()
        store.startFever()
        XCTAssertFalse(store.isFeverAdAvailable)
    }

    // MARK: Boost

    private func makeSellable() {
        store.stall.menuStock = [10, 0, 0]
        store.stall.cashierCount = 0
    }

    func test_boost_notOfferedInTheFirstThreeMinutes() {
        XCTAssertFalse(store.isBoostAvailable)
        XCTAssertFalse(store.claimBoost())
    }

    func test_boost_doublesSales_forThreeMinutes_thenCoolsDownFiveMinutes() throws {
        store.progress.totalPlaySeconds = 600
        makeSellable()
        let base = try XCTUnwrap(store.sellItem(menuIndex: 0))
        XCTAssertTrue(store.claimBoost())
        XCTAssertEqual(store.boostRemaining, 180, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(store.sellItem(menuIndex: 0)), base * 2, accuracy: 1e-9)
        XCTAssertFalse(store.claimBoost(), "already running")

        clock.date.addTimeInterval(179)
        XCTAssertTrue(store.isBoostActive)
        clock.date.addTimeInterval(2)
        XCTAssertFalse(store.isBoostActive)
        XCTAssertEqual(try XCTUnwrap(store.sellItem(menuIndex: 0)), base, accuracy: 1e-9)
        XCTAssertEqual(store.boostCooldownRemaining, 299, accuracy: 1e-6)
        XCTAssertFalse(store.isBoostAvailable)
        clock.date.addTimeInterval(300)
        XCTAssertTrue(store.isBoostAvailable)
    }

    func test_boost_stacksMultiplicativelyWithFever_andNeverEntersTheOfflineRate() throws {
        store.progress.totalPlaySeconds = 600
        makeSellable()
        chargeFever()
        store.startFever()
        store.claimBoost()
        let price = try XCTUnwrap(store.sellItem(menuIndex: 0))
        XCTAssertEqual(price, 30 * 2 * 2, accuracy: 1e-9)
        store.progress.earningRate = 0
        for _ in 0..<5 { store.tick(deltaTime: 1) }
        XCTAssertEqual(store.progress.earningRate, 30.0 / 5, accuracy: 1e-6,
                       "the 5 s window holds one base-priced sale")
    }

    func test_boost_survivesRelaunch_withoutRefundOrLoss() {
        store.progress.totalPlaySeconds = 600
        store.claimBoost()
        clock.date.addTimeInterval(100)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.boostRemaining, 80, accuracy: 1e-6)
        clock.date.addTimeInterval(100)
        XCTAssertFalse(reloaded.isBoostActive)
        XCTAssertEqual(reloaded.boostCooldownRemaining, 280, accuracy: 1e-6, "the cooldown runs from the boost's end")
    }

    func test_boost_survivesANewSpring() {
        store.progress.totalPlaySeconds = 600
        store.claimBoost()
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        XCTAssertTrue(store.startNewRun())
        XCTAssertTrue(store.isBoostActive)
    }

    func test_adRewardState_decodesTolerantly() throws {
        let empty = try JSONDecoder().decode(AdRewardState.self, from: Data("{}".utf8))
        XCTAssertNil(empty.boostEndsAt)
        let junk = try JSONDecoder().decode(AdRewardState.self, from: Data(#"{"boostEndsAt":"soon"}"#.utf8))
        XCTAssertNil(junk.boostEndsAt)
        var s = AdRewardState()
        s.boostEndsAt = Date(timeIntervalSince1970: 1_000)
        let back = try JSONDecoder().decode(AdRewardState.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back, s)
    }

    // MARK: Gift crate

    private func readyForGift() {
        store.progress.totalPlaySeconds = 300
        store.stall.staffTier = 1
    }

    private func tickSeconds(_ n: Int) { for _ in 0..<n { store.tick(deltaTime: 1) } }

    func test_gift_intervalIsRolledBetween240And360() {
        XCTAssertEqual(GiftSystem.interval(roll: 0), 240)
        XCTAssertEqual(GiftSystem.interval(roll: 0.5), 300)
        XCTAssertEqual(GiftSystem.interval(roll: 1), 360)
    }

    func test_gift_neverBeforeTheFirstHire() {
        store.progress.totalPlaySeconds = 300
        tickSeconds(400)
        XCTAssertFalse(store.isGiftPresent)
        store.stall.staffTier = 1
        store.tick(deltaTime: 1)
        XCTAssertTrue(store.isGiftPresent, "the clock kept running while it waited for the hire")
    }

    func test_gift_neverBeforeFourMinutesOfInstallPlay() {
        store.stall.staffTier = 1
        store.progress.totalPlaySeconds = 0
        tickSeconds(230)
        XCTAssertFalse(store.isGiftPresent, "230 s of play")
        store.progress.totalPlaySeconds = 100
        store.tick(deltaTime: 1)
        XCTAssertFalse(store.isGiftPresent)
    }

    func test_gift_staysThirtySeconds_thenLeaves_andComesBackLater() {
        readyForGift()
        tickSeconds(360)
        XCTAssertTrue(store.isGiftPresent)
        XCTAssertEqual(store.giftRemaining, 30, accuracy: 1.5)
        tickSeconds(31)
        XCTAssertFalse(store.isGiftPresent)
        tickSeconds(200)
        XCTAssertFalse(store.isGiftPresent, "a fresh 240-360 s interval")
        tickSeconds(170)
        XCTAssertTrue(store.isGiftPresent)
    }

    func test_gift_heldWhileTheDialogIsOpen() {
        readyForGift()
        tickSeconds(361)
        XCTAssertTrue(store.isGiftPresent)
        store.isGiftHeld = true
        tickSeconds(60)
        XCTAssertTrue(store.isGiftPresent)
        store.isGiftHeld = false
        tickSeconds(31)
        XCTAssertFalse(store.isGiftPresent)
    }

    func test_gift_amount_isTheLargerOfTwentySalesAndTwoAndAHalfMinutesOfIncome() {
        XCTAssertEqual(GiftSystem.amount(bestSalePrice: 30, earningRate: 0), 600)
        XCTAssertEqual(GiftSystem.amount(bestSalePrice: 30, earningRate: 10), 1_500)
        XCTAssertEqual(GiftSystem.amount(bestSalePrice: 100, earningRate: 1), 2_000)
    }

    func test_claimGift_paysOnce() {
        XCTAssertNil(store.claimGift(), "no crate in the yard")
        readyForGift()
        tickSeconds(361)
        store.stall.coins = 0
        store.progress.earningRate = 10
        let expected = store.giftAmount
        XCTAssertEqual(expected, 1_500)
        XCTAssertEqual(store.claimGift(), expected)
        XCTAssertEqual(store.stall.coins, expected)
        XCTAssertFalse(store.isGiftPresent)
        XCTAssertNil(store.claimGift())
    }

    func test_gift_amountIsFrozenWhileTheDialogIsOpen_andIsWhatThePlayerGets() {
        readyForGift()
        tickSeconds(361)
        store.stall.coins = 0
        store.progress.earningRate = 10
        store.isGiftHeld = true
        let shown = store.giftAmount
        XCTAssertEqual(shown, 1_500)
        store.progress.earningRate = 100
        XCTAssertEqual(store.giftAmount, shown, "the text must keep matching the payout")
        XCTAssertEqual(store.claimGift(), shown)
        XCTAssertEqual(store.stall.coins, shown)
        store.isGiftHeld = false
        store.progress.earningRate = 100
        XCTAssertEqual(store.giftAmount, 15_000, "released: back to the live amount")
    }

    // MARK: Surfaces and gates

    func test_onlyOneRewardedPromptAnimates_mostUrgentFirst() {
        XCTAssertNil(AdPromptSurface.active(giftPresent: false, boostAvailable: false, feverAdAvailable: false))
        XCTAssertEqual(AdPromptSurface.active(giftPresent: true, boostAvailable: true, feverAdAvailable: true), .gift)
        XCTAssertEqual(AdPromptSurface.active(giftPresent: false, boostAvailable: true, feverAdAvailable: true), .boost)
        XCTAssertEqual(AdPromptSurface.active(giftPresent: false, boostAvailable: false, feverAdAvailable: true), .fever)
    }

    func test_cooldownGate_rateLimits() {
        var gate = CooldownGate(interval: 20)
        let t = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.fire(now: t))
        XCTAssertFalse(gate.fire(now: t.addingTimeInterval(19)))
        XCTAssertTrue(gate.fire(now: t.addingTimeInterval(20)))
    }

    func test_everyPlacementHasItsOwnProductionUnit() {
        let pattern = #"^ca-app-pub-9684378399371172/\d+$"#
        let ids = AdPlacement.allCases.map(\.releaseUnitID)
        for id in ids { XCTAssertNotNil(id.range(of: pattern, options: .regularExpression), id) }
        XCTAssertEqual(Set(ids).count, AdPlacement.allCases.count, "one unit per placement")
        XCTAssertEqual(AdPlacement.offline.releaseUnitID, "ca-app-pub-9684378399371172/3844454464")
    }
}
