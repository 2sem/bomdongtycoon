import XCTest
@testable import GameCore

/// The "core loop v2" rules: self-serve prep, tap to hurry, watering, waking, auto-placed hires,
/// the warehouse-full signal and the new money numbers. Time is the store's own `tick` clock and
/// randomness is the scripted source, so every case is deterministic.
@MainActor
final class CoreLoopV2Tests: DotWorldTestCase {

    private func emptyShelves(warehouse: Int = 10) {
        store.stall.menuStock = [0, 0, 0]
        store.stall.warehouse = warehouse
        store.stall.warehouseCapacity = 30
    }

    /// Whole seconds in 0.25 s steps, the cadence a real frame loop is far finer than.
    private func run(_ seconds: Double) {
        var left = seconds
        while left > 1e-9 {
            let step = min(0.25, left)
            store.tick(deltaTime: step)
            left -= step
        }
    }

    // MARK: Self-serve prep

    func test_selfServe_keepsCookingPortionAfterPortion_untilStockReachesFive() {
        emptyShelves()
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        for portion in 1...5 {
            run(4)
            XCTAssertEqual(store.stall.menuStock[0], portion, "one portion every 4 s with no further taps")
        }
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0), "stopped at five")
        XCTAssertFalse(store.isCooking(menuIndex: 0))
        run(12)
        XCTAssertEqual(store.stall.menuStock[0], GameStore.selfServeStock)
        XCTAssertEqual(store.stall.warehouse, 5)
    }

    func test_selfServe_resumesOnceStockDropsBelowFiveAndItIsNeededAgain() {
        emptyShelves()
        store.stall.menuStock[0] = 4
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        run(4)
        XCTAssertEqual(store.stall.menuStock[0], 5)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
        _ = store.sellItem(menuIndex: 0)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0), "selling does not restart it by itself")
        XCTAssertTrue(store.requestSelfServe(menuIndex: 0), "a waiting customer does")
        run(4)
        XCTAssertEqual(store.stall.menuStock[0], 5)
    }

    func test_selfServe_endsWhenTheWarehouseRunsDry() {
        emptyShelves(warehouse: 2)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        run(8)
        XCTAssertEqual(store.stall.menuStock[0], 2)
        XCTAssertEqual(store.stall.warehouse, 0)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    func test_tapAtOrAboveTheCap_stillMakesOnePortionThenStops() {
        emptyShelves()
        store.stall.menuStock[0] = 7
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started, "a tap always yields a portion")
        run(4)
        XCTAssertEqual(store.stall.menuStock[0], 8)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0), "the cap only decides whether it carries on")
    }

    func test_requestSelfServe_startsOnlyWhereNobodyCooksAndStockIsLow() {
        emptyShelves()
        store.stall.menuTier = 1
        XCTAssertTrue(store.requestSelfServe(menuIndex: 0))
        XCTAssertTrue(store.isCooking(menuIndex: 0))
        XCTAssertFalse(store.requestSelfServe(menuIndex: 0), "already running")
        XCTAssertFalse(store.requestSelfServe(menuIndex: 2), "locked dish")
        store.stall.menuCooks = [0, 1, 0]
        XCTAssertFalse(store.requestSelfServe(menuIndex: 1), "a hired cook owns it")
        store.stall.menuCooks = [0, 0, 0]
        store.stall.menuStock[1] = GameStore.selfServeStock
        XCTAssertFalse(store.requestSelfServe(menuIndex: 1), "already stocked")
        store.stall.menuStock[1] = 0
        store.stall.warehouse = 0
        XCTAssertFalse(store.requestSelfServe(menuIndex: 1), "nothing to cook with")
    }

    func test_hiredCook_behavesAsBefore_fillsToMaxStock_andTapsDoNotStartASession() {
        emptyShelves(warehouse: 30)
        store.stall.menuCooks = [1, 0, 0]
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
        run(200)
        XCTAssertEqual(store.stall.menuStock[0], EarningsSystem.maxStock(for: store.stall),
                       "a cook is not held to the self-serve cap")
    }

    func test_hiringACook_endsARunningSession() {
        emptyShelves()
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        store.stall.menuCooks = [1, 0, 0]
        store.tick(deltaTime: 0.1)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    // MARK: Tap to hurry

    func test_hurry_addsAThirdOfAPortionPerTap_andThreeTapsLandOne() {
        emptyShelves()
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        store.tick(deltaTime: 0.1)
        let base = store.cookProgress(menuIndex: 0)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        XCTAssertEqual(store.cookProgress(menuIndex: 0), base + GameStore.hurryPerTap, accuracy: 1e-9)
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        XCTAssertEqual(store.stall.menuStock[0], 1, "three taps and a little cooking make a portion at once")
        XCTAssertEqual(GameStore.hurryPerTap, 0.34)
    }

    func test_hurry_isDebouncedPerDish() {
        emptyShelves()
        store.stall.menuTier = 1
        store.tapDish(menuIndex: 0)
        store.tapDish(menuIndex: 1)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .ignored, "inside 0.08 s")
        XCTAssertEqual(store.tapDish(menuIndex: 1), .hurried, "another dish has its own window")
        store.tick(deltaTime: 0.05)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .ignored)
        store.tick(deltaTime: 0.05)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
    }

    func test_hurry_worksOnAHiredCooksPortion() {
        emptyShelves(warehouse: 30)
        store.stall.menuCooks = [1, 0, 0]
        XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        XCTAssertEqual(store.cookProgress(menuIndex: 0), GameStore.hurryPerTap, accuracy: 1e-9)
        for _ in 0..<2 {
            store.tick(deltaTime: 0.1)
            XCTAssertEqual(store.tapDish(menuIndex: 0), .hurried)
        }
        store.tick(deltaTime: 0.1)
        XCTAssertGreaterThanOrEqual(store.stall.menuStock[0], 1)
    }

    func test_tap_isBlockedWhenThereIsNothingToCookOrNoRoom() {
        emptyShelves(warehouse: 0)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .blocked, "no cabbage")
        store.stall.warehouse = 5
        store.stall.menuStock[0] = EarningsSystem.maxStock(for: store.stall)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .blocked, "no room")
        XCTAssertEqual(store.tapDish(menuIndex: 1), .locked)
        XCTAssertEqual(store.tapDish(menuIndex: 9), .locked)
        store.stall.menuStock[0] = 0
        store.stall.menuCooks = [1, 0, 0]
        store.stall.warehouse = 0
        XCTAssertEqual(store.tapDish(menuIndex: 0), .blocked, "a cook with no cabbage has nothing to hurry")
    }

    func test_fever_tapIsStillAnInstantPortion() {
        emptyShelves()
        chargeFever()
        store.startFever()
        let before = store.stall.menuStock[0]
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        XCTAssertEqual(store.stall.menuStock[0], before + 1)
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0))
    }

    // MARK: Watering

    private func growingPlot(_ i: Int = 1, growth: Double = 0.2) {
        while store.farm.plots.count <= i { store.farm.plots.append(FarmPlot()) }
        store.farm.plots[i].isPlanted = true
        store.farm.plots[i].growth = growth
    }

    func test_water_addsFifteenPercent_oncePerQuarterSecondPerPlot() {
        growingPlot(1)
        growingPlot(2)
        XCTAssertTrue(store.waterPlot(plotIndex: 1))
        XCTAssertEqual(store.farm.plots[1].growth, 0.35, accuracy: 1e-9)
        XCTAssertFalse(store.waterPlot(plotIndex: 1), "same instant")
        store.tick(deltaTime: 0.1)
        let afterTick = store.farm.plots[1].growth
        XCTAssertFalse(store.waterPlot(plotIndex: 1), "0.1 s later is still inside 0.25 s")
        XCTAssertEqual(store.farm.plots[1].growth, afterTick, accuracy: 1e-9)
        XCTAssertTrue(store.waterPlot(plotIndex: 2), "each plot has its own window")
        store.tick(deltaTime: 0.2)
        XCTAssertTrue(store.waterPlot(plotIndex: 1))
        XCTAssertEqual(GameStore.waterGrowth, 0.15)
        XCTAssertEqual(GameStore.waterInterval, 0.25)
    }

    func test_water_ignoresEmptyAndRipePlots_andClampsAtRipe() {
        store.farm.plots[1].isPlanted = false
        XCTAssertFalse(store.waterPlot(plotIndex: 1))
        growingPlot(2, growth: 1)
        XCTAssertFalse(store.waterPlot(plotIndex: 2))
        XCTAssertFalse(store.waterPlot(plotIndex: 99))
        growingPlot(3, growth: 0.95)
        XCTAssertTrue(store.waterPlot(plotIndex: 3))
        XCTAssertEqual(store.farm.plots[3].growth, 1)
        XCTAssertTrue(store.farm.plots[3].isReady)
    }

    func test_water_thatRipensRollsGoldenLikeAnyRipening() {
        growingPlot(1, growth: 0.9)
        script.values = [0.0]
        XCTAssertTrue(store.waterPlot(plotIndex: 1))
        XCTAssertTrue(store.farm.plots[1].isGolden)
        growingPlot(2, growth: 0.9)
        script.values = [0.99]
        XCTAssertTrue(store.waterPlot(plotIndex: 2))
        XCTAssertFalse(store.farm.plots[2].isGolden)
        growingPlot(3, growth: 0.3)
        script.values = [0.0]
        XCTAssertTrue(store.waterPlot(plotIndex: 3))
        XCTAssertFalse(store.farm.plots[3].isGolden, "no roll before it ripens")
    }

    // MARK: Waking

    private func tiredCook() {
        store.stall.menuCooks = [1, 0, 0]
        store.stall.menuCookEnergy = [0.1, 1, 1]
        store.stall.menuCookResting = [true, false, false]
    }

    func test_wake_addsHalfAnEnergyBar_toASleepingCook_whoKeepsSleeping() {
        tiredCook()
        XCTAssertTrue(store.isResting(.cook(menuIndex: 0)))
        XCTAssertTrue(store.wakeWorker(.cook(menuIndex: 0)))
        XCTAssertEqual(store.stall.menuCookEnergy[0], 0.6, accuracy: 1e-9)
        XCTAssertTrue(store.isResting(.cook(menuIndex: 0)), "only full energy ends the nap")
    }

    func test_wake_coversCashierAndFarmWorkers() {
        store.stall.cashierCount = 1
        store.stall.cashierEnergy = 0.0
        store.stall.cashierResting = true
        XCTAssertTrue(store.wakeWorker(.cashier))
        XCTAssertEqual(store.stall.cashierEnergy, 0.5, accuracy: 1e-9)
        store.farm.plots[1].workerType = .alba
        store.farm.plots[1].workerEnergy = 0.2
        store.farm.plots[1].workerResting = true
        XCTAssertTrue(store.wakeWorker(.farm(plotIndex: 1)))
        XCTAssertEqual(store.farm.plots[1].workerEnergy, 0.7, accuracy: 1e-9)
    }

    func test_wake_capsAtFull_endsTheNap_andRefusesAwake_andEmptyPosts() {
        store.stall.cashierCount = 1
        store.stall.cashierEnergy = 0.74
        store.stall.cashierResting = true
        XCTAssertTrue(store.wakeWorker(.cashier))
        XCTAssertEqual(store.stall.cashierEnergy, 1, accuracy: 1e-9)
        XCTAssertFalse(store.stall.cashierResting, "reaching full energy wakes her")
        XCTAssertFalse(store.wakeWorker(.cashier), "not asleep any more")
        XCTAssertFalse(store.wakeWorker(.cook(menuIndex: 0)), "nobody cooks there")
        XCTAssertFalse(store.wakeWorker(.farm(plotIndex: 0)), "nobody farms there")
        XCTAssertFalse(store.wakeWorker(.farm(plotIndex: 99)))
        store.stall.cashierEnergy = 0.0
        store.stall.cashierResting = true
        XCTAssertFalse(store.wakeWorker(.cashier), "thirty seconds have not passed")
    }

    func test_wake_isOncePerWorkerPerThirtySeconds() {
        tiredCook()
        XCTAssertTrue(store.wakeWorker(.cook(menuIndex: 0)))
        store.stall.menuCookEnergy[0] = 0.0
        XCTAssertFalse(store.wakeWorker(.cook(menuIndex: 0)))
        store.stall.menuCooks = [1, 1, 0]
        store.stall.menuCookEnergy = [0.0, 0.0, 1]
        store.stall.menuCookResting = [true, true, false]
        XCTAssertTrue(store.wakeWorker(.cook(menuIndex: 1)), "a different worker is not held")
        store.tick(deltaTime: 29)
        store.stall.menuCookEnergy[0] = 0.0
        XCTAssertFalse(store.wakeWorker(.cook(menuIndex: 0)))
        store.tick(deltaTime: 1.5)
        store.stall.menuCookEnergy[0] = 0.0
        XCTAssertTrue(store.wakeWorker(.cook(menuIndex: 0)))
        XCTAssertEqual(GameStore.wakeInterval, 30)
        XCTAssertEqual(GameStore.wakeEnergy, 0.5)
    }

    // MARK: Warehouse full

    func test_fullWarehouse_blocksAManualHarvest_andSaysSo() {
        store.stall.warehouse = store.stall.warehouseCapacity
        XCTAssertTrue(store.isWarehouseFull)
        store.farm.plots[1].isPlanted = true
        store.farm.plots[1].growth = 1
        XCTAssertNil(store.harvest(plotIndex: 1))
        XCTAssertTrue(store.farm.plots[1].isReady, "the crop stays on the plot")
        store.stall.warehouse -= 1
        XCTAssertFalse(store.isWarehouseFull)
        XCTAssertNotNil(store.harvest(plotIndex: 1))
    }

    // MARK: Auto-placed hires

    /// Every plot worked by its own alba, with the headcount to match.
    private func occupyPlotsWithAlbas() {
        for i in store.farm.plots.indices {
            store.farm.plots[i].workerType = .alba
            store.stall.tier1Count += 1
        }
    }

    private func openEverything() {
        store.stall.stallTier = 2
        store.stall.menuTier = 2
        store.stall.coins = 1_000_000
    }

    func test_alba_fillsEmptyPlotsFirst_thenTheLowestDishWithoutACook_thenCashier() {
        openEverything()
        XCTAssertEqual(store.hireWorker(tier: 1), .init(tier: 1, placement: .farm(plotIndex: 0)))
        XCTAssertEqual(store.farm.plots[0].workerType, .alba)
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .farm(plotIndex: 1))
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .farm(plotIndex: 2))
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cook(menuIndex: 0))
        XCTAssertEqual(store.stall.menuCooks, [1, 0, 0])
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cook(menuIndex: 1))
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cook(menuIndex: 2))
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cashier)
        XCTAssertEqual(store.stall.cashierTier, 1)
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .unassigned, "nothing is left to do")
        XCTAssertEqual(store.availableWorkers, 2, "the spare and the unplaced starting alba")
    }

    func test_alba_onlyTakesDishesTheShopHasUnlocked() {
        store.stall.coins = 10_000
        occupyPlotsWithAlbas()
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cook(menuIndex: 0))
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .cashier, "dish 1 is still locked")
    }

    func test_imo_cooksThenCashiers_butNeverFarms() {
        openEverything()
        store.stall.menuCooks = [0, 0, 0]
        for expected in [StaffPlacementCase.cook(0), .cook(1), .cook(2), .cashier, .none] {
            let result = store.hireWorker(tier: 2)
            XCTAssertEqual(result?.placement, expected.value)
        }
        XCTAssertEqual(store.farm.plots.filter { $0.workerType != .none }.count, 0)
        XCTAssertEqual(store.availableWorkers, 2, "the spare 이모님 and the unplaced starting alba")
    }

    func test_chef_onlyCooks() {
        openEverything()
        XCTAssertEqual(store.hireWorker(tier: 3)?.placement, .cook(menuIndex: 0))
        XCTAssertEqual(store.hireWorker(tier: 3)?.placement, .cook(menuIndex: 1))
        XCTAssertEqual(store.hireWorker(tier: 3)?.placement, .cook(menuIndex: 2))
        XCTAssertEqual(store.hireWorker(tier: 3)?.placement, .unassigned, "the kitchen specialist never works the till")
        XCTAssertEqual(store.stall.cashierCount, 0)
    }

    func test_farmerAndVeteran_takeFreePlots_theVeteranMayTakeTheTillFirst() {
        openEverything()
        XCTAssertEqual(store.hireFarmer()?.placement, .farm(plotIndex: 0))
        XCTAssertEqual(store.farm.plots[0].workerType, .farmer)
        XCTAssertEqual(store.hireVeteranAlba()?.placement, .cashier)
        XCTAssertEqual(store.stall.cashierTier, 5)
        XCTAssertEqual(store.hireVeteranAlba()?.placement, .farm(plotIndex: 1))
        XCTAssertEqual(store.farm.plots[1].workerType, .veteranAlba)
        XCTAssertEqual(store.availableFarmers, 0)
    }

    func test_hire_staysUnassignedWhenNothingIsFree() {
        store.stall.coins = 100_000
        for i in store.farm.plots.indices { store.farm.plots[i].workerType = .alba }
        store.stall.menuCooks = [1, 0, 0]
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.stall.tier1Count = 5
        store.stall.tier1IdleEnergies = []
        XCTAssertEqual(store.hireWorker(tier: 1)?.placement, .unassigned)
        XCTAssertEqual(store.availableWorkers, 1)
        XCTAssertEqual(store.hireFarmer()?.placement, .unassigned)
    }

    func test_hire_unaffordableOrLocked_returnsNilAndChangesNothing() {
        store.stall.coins = 10
        XCTAssertNil(store.hireWorker(tier: 1))
        XCTAssertNil(store.hireFarmer())
        XCTAssertNil(store.hireVeteranAlba())
        store.stall.coins = 1_000_000
        XCTAssertNil(store.hireWorker(tier: 2), "이모님 needs the restaurant")
        XCTAssertEqual(store.stall.coins, 1_000_000)
        XCTAssertEqual(store.stall.staffCount, 1)
    }

    func test_placedHire_arrivesRested_andPoolsStayConsistent() {
        store.stall.coins = 1_000
        store.stall.tier1IdleEnergies = []
        occupyPlotsWithAlbas()
        store.hireWorker(tier: 1)
        XCTAssertEqual(store.stall.menuCookEnergy[0], 1, accuracy: 1e-9)
        XCTAssertTrue(store.stall.tier1IdleEnergies.isEmpty, "the worker left the idle pool")
        store.hireWorker(tier: 1)
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.stall.menuCooks[0], 1, "placement is saved")
        XCTAssertEqual(reloaded.stall.cashierCount, 1)
    }

    // MARK: New numbers

    func test_feverTriplesSales_keepsItsLengthAndGift() {
        XCTAssertEqual(FeverSystem.priceMultiplier, 3)
        XCTAssertEqual(FeverSystem.duration, 15)
        XCTAssertEqual(FeverSystem.startingPortions, 4)
        store.stall.menuStock[0] = 3
        let base = store.sellItem(menuIndex: 0) ?? 0
        chargeFever()
        store.startFever()
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, base * 3, accuracy: 1e-9)
    }

    func test_economyTables() {
        XCTAssertEqual(UpgradeDefinitions.menu.map(\.coinCost), [0, 800, 6_000])
        XCTAssertEqual(UpgradeDefinitions.location.map(\.coinCost), [0, 40_000, 150_000])
        XCTAssertEqual(RenovationSystem.priceBonusPerLevel, 0.08)
        XCTAssertEqual(RenovationSystem.baseCost, 30_000)
        XCTAssertEqual(RenovationSystem.costGrowth, 1.25)
        XCTAssertEqual(RenovationSystem.percentPerLevel, 8)
        XCTAssertEqual(RenovationSystem.priceMultiplier(level: 5), 1.4, accuracy: 1e-9)
    }

    func test_prestigeMultiplier_isOnePlusPointSixTimesPowerThreeQuarters() {
        for n in 0...12 {
            XCTAssertEqual(PrestigeSystem.legacyMultiplier(prestigeCount: n),
                           1 + 0.6 * pow(Double(n), 0.75), accuracy: 1e-12)
        }
        XCTAssertEqual(PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: 1)), "1.6")
        XCTAssertEqual(PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: 2)), "2.01")
    }

    func test_startingCoins_fiftyPlusThreeHundredPerSpring_cappedAtThreeThousand() {
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 0), 50)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 1), 350)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 2), 650)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 9), 2_750)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 10), 3_000)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: 40), 3_000)
        XCTAssertEqual(PrestigeSystem.startingCoins(prestigeCount: -2), 50)
    }

    func test_newSpring_opensWithTheScaledCoins_threePlots_andFifteenSlots() {
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.progress.prestigeCount = 2
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.progress.prestigeCount, 3)
        XCTAssertEqual(store.stall.coins, 950)
        XCTAssertEqual(store.farm.plots.count, 3)
        XCTAssertEqual(store.stall.warehouseCapacity, 15)
    }

    func test_newSpring_coinsSurviveARelaunch() {
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(GameStore(defaults: defaults).stall.coins, 350)
    }
}

/// `.none` stands for "no placement": a plain optional would read as a missing value in the table.
private enum StaffPlacementCase {
    case cook(Int), cashier, none
    var value: GameStore.StaffPlacement {
        switch self {
        case .cook(let i): .cook(menuIndex: i)
        case .cashier: .cashier
        case .none: .unassigned
        }
    }
}
