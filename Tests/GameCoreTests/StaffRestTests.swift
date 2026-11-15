import XCTest
@testable import GameCore

/// A worker who runs out of energy falls asleep, does no work, and wakes only at full energy.
/// The player's answer is more staff: swap a rested worker in and the post works again at once.
@MainActor
final class StaffRestTests: DotWorldTestCase {

    private func run(_ seconds: Double) {
        var left = seconds
        while left > 1e-9 {
            let step = min(0.25, left)
            store.tick(deltaTime: step)
            left -= step
        }
    }

    /// One alba on plot 0 with the other plots empty, so only that worker acts.
    private func soloFarmer(energy: Double = 1, resting: Bool = false) {
        for i in store.farm.plots.indices { store.farm.plots[i].workerType = .none }
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].workerEnergy = energy
        store.farm.plots[0].workerResting = resting
        store.stall.coins = 10_000
        store.stall.warehouse = 0
        store.stall.warehouseCapacity = 100
    }

    // MARK: Farm

    func test_farmWorker_fallsAsleepAtZero_andStopsHarvestingAndReplanting() {
        soloFarmer(energy: 0.125)
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        store.tick(deltaTime: 0.01)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield, "the last harvest still lands")
        XCTAssertTrue(store.farm.plots[0].workerResting)
        XCTAssertFalse(store.farm.plots[0].isPlanted, "a sleeping worker does not replant")
        let coins = store.stall.coins

        run(10)
        XCTAssertFalse(store.farm.plots[0].isPlanted)
        XCTAssertEqual(store.stall.coins, coins)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield)
    }

    func test_sleepingFarmWorker_doesNotHarvestARipeCrop_andRestoresAnyway() {
        soloFarmer(energy: 0.2, resting: true)
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        run(30)
        XCTAssertTrue(store.farm.plots[0].isReady, "crop waits for someone awake")
        XCTAssertEqual(store.stall.warehouse, 0)
        XCTAssertGreaterThan(store.farm.plots[0].workerEnergy, 0.2 + 30.0 / 90.0 - 0.01,
                             "rest is not paused by a ready crop")
        XCTAssertTrue(store.farm.plots[0].workerResting)
    }

    func test_farmWorker_wakesAtFull_thenWorksAgain() {
        soloFarmer(energy: 0, resting: true)
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        run(89)
        XCTAssertTrue(store.farm.plots[0].workerResting)
        XCTAssertEqual(store.stall.warehouse, 0)
        run(2)
        XCTAssertFalse(store.farm.plots[0].workerResting)
        run(1)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield)
        XCTAssertTrue(store.farm.plots[0].isPlanted, "and replants")
    }

    func test_manualHarvestAndPlant_stillWorkOnASleepingWorkersPlot() {
        soloFarmer(energy: 0, resting: true)
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        XCTAssertNotNil(store.harvest(plotIndex: 0))
        XCTAssertGreaterThan(store.stall.warehouse, 0)
    }

    // MARK: Cook

    private func cook(energy: Double = 1, resting: Bool = false) {
        store.stall.menuTier = 0
        store.stall.menuCooks = [1, 0, 0]
        store.stall.menuCookEnergy = [energy, 1, 1]
        store.stall.menuCookResting = [resting, false, false]
        store.stall.menuStock = [0, 0, 0]
        store.stall.warehouse = 20
        store.stall.warehouseCapacity = 30
        for i in store.farm.plots.indices { store.farm.plots[i].workerType = .none }
    }

    func test_cook_fallsAsleepAtZero_andStopsCooking() {
        cook(energy: 0.003)
        run(60)
        XCTAssertTrue(store.stall.menuCookResting[0])
        let stock = store.stall.menuStock[0]
        XCTAssertGreaterThan(stock, 0)
        XCTAssertFalse(store.isCooking(menuIndex: 0))
        run(20)
        XCTAssertEqual(store.stall.menuStock[0], stock, "no auto-cooking while asleep")
        XCTAssertGreaterThan(store.stall.menuCookEnergy[0], 0, "and she is recovering")
    }

    func test_playerCanCookTheDishByHand_whileTheHiredCookSleeps() {
        cook(energy: 0.3, resting: true)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        XCTAssertTrue(store.isManualCookRunning(menuIndex: 0))
        run(5)
        XCTAssertGreaterThan(store.stall.menuStock[0], 0)
    }

    func test_manualSession_endsWhenTheCookWakes() {
        cook(energy: 0.99, resting: true)
        XCTAssertEqual(store.tapDish(menuIndex: 0), .started)
        run(2)
        XCTAssertFalse(store.stall.menuCookResting[0])
        XCTAssertFalse(store.isManualCookRunning(menuIndex: 0), "the awake cook owns the dish again")
    }

    func test_selfServe_coversASleepingCooksDish() {
        cook(energy: 0.3, resting: true)
        XCTAssertTrue(store.requestSelfServe(menuIndex: 0))
    }

    // MARK: Cashier

    func test_cashier_sleepsAfterTheDrainingSale_andPaysNoBonusAfter() {
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.stall.cashierEnergy = 1.0 / 60.0
        store.stall.cashierResting = false
        store.stall.menuStock = [10, 0, 0]
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.25, accuracy: 0.001)
        XCTAssertTrue(store.stall.cashierResting)
        let energy = store.stall.cashierEnergy
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(store.stall.cashierEnergy, energy, "a sleeping cashier drains nothing")
    }

    func test_sleepingCashier_restoresEveryTick_evenWhileSalesKeepComing() {
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.stall.cashierEnergy = 0
        store.stall.cashierResting = true
        store.stall.menuStock = [50, 0, 0]
        for _ in 0..<20 {
            _ = store.sellItem(menuIndex: 0)
            store.tick(deltaTime: 0.5)
        }
        XCTAssertEqual(store.stall.cashierEnergy, 10.0 / 90.0, accuracy: 1e-6)
    }

    // MARK: Wake tap

    func test_wakeTap_hurriesTheNap_butDoesNotEndItBelowFull() {
        soloFarmer(energy: 0.1, resting: true)
        XCTAssertTrue(store.wakeWorker(.farm(plotIndex: 0)))
        XCTAssertEqual(store.farm.plots[0].workerEnergy, 0.6, accuracy: 1e-9)
        XCTAssertTrue(store.isResting(.farm(plotIndex: 0)))
        XCTAssertFalse(store.wakeWorker(.farm(plotIndex: 0)), "once per thirty seconds")
    }

    func test_wakeTap_endsTheNapWhenItReachesFull() {
        soloFarmer(energy: 0.6, resting: true)
        XCTAssertTrue(store.wakeWorker(.farm(plotIndex: 0)))
        XCTAssertFalse(store.isResting(.farm(plotIndex: 0)))
    }

    func test_wakeTap_ignoresAnAwakeWorker_evenWithLowEnergy() {
        soloFarmer(energy: 0.05, resting: false)
        XCTAssertFalse(store.isResting(.farm(plotIndex: 0)))
        XCTAssertFalse(store.wakeWorker(.farm(plotIndex: 0)))
    }

    // MARK: Assignment and swapping

    func test_assigningADrainedWorker_startsAsleep_andARestedOneWorksAtOnce() {
        store.stall.tier1Count = 2
        store.stall.tier1IdleEnergies = [0.1, 1.0]
        for i in store.farm.plots.indices { store.farm.plots[i].workerType = .none }
        store.stall.cashierCount = 0
        store.stall.menuCooks = [0, 0, 0]

        store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
        XCTAssertTrue(store.farm.plots[0].workerResting, "0.1 energy < threshold")
        store.toggleFarmWorker(plotIndex: 0, workerType: .alba, addToIdle: true)
        XCTAssertFalse(store.farm.plots[0].hasWorker)
        XCTAssertFalse(store.farm.plots[0].workerResting, "removal clears the nap")

        store.stall.tier1IdleEnergies = [1.0]
        store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
        XCTAssertFalse(store.farm.plots[0].workerResting)
    }

    func test_swapInRestedWorker_putsSleepingPostBackToWork() {
        soloFarmer(energy: 0, resting: true)
        store.stall.tier1Count = 2
        store.stall.tier1IdleEnergies = [1.0]
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1

        store.toggleFarmWorker(plotIndex: 0, workerType: .alba, displayedEnergy: 0)
        store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
        XCTAssertEqual(store.stall.tier1IdleEnergies, [0], "the sleeper goes to the bench and keeps resting there")
        store.tick(deltaTime: 0.01)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield, "the fresh worker harvests immediately")
    }

    func test_cashierAndCookAssignment_followTheSameThreshold() {
        store.stall.tier1Count = 2
        store.stall.tier1IdleEnergies = [0.1, 0.9]
        store.stall.menuCooks = [0, 0, 0]
        store.stall.cashierCount = 0
        store.assignToCashier(tier: 1)
        XCTAssertTrue(store.stall.cashierResting)
        store.assignMenuCook(menuIndex: 0, tier: 1)
        XCTAssertFalse(store.stall.menuCookResting[0])
        store.removeFromCashier()
        XCTAssertFalse(store.stall.cashierResting)
        store.assignToCashier(tier: 1, directEnergy: 0.2)
        XCTAssertTrue(store.stall.cashierResting, "a position-to-position move carries the sleep too")
    }

    func test_idlePoolWorkers_keepRestoringAsBefore() {
        store.stall.tier1Count = 1
        store.stall.tier1IdleEnergies = [0]
        run(45)
        XCTAssertEqual(store.stall.tier1IdleEnergies[0], 0.5, accuracy: 1e-6)
    }

    // MARK: Saves

    func test_restFlags_roundTrip() throws {
        store.stall.cashierResting = true
        store.stall.menuCookResting = [false, true, false]
        store.farm.plots[0].workerResting = true
        let stall = try JSONDecoder().decode(StallState.self, from: JSONEncoder().encode(store.stall))
        let farm = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(store.farm))
        XCTAssertTrue(stall.cashierResting)
        XCTAssertEqual(stall.menuCookResting, [false, true, false])
        XCTAssertTrue(farm.plots[0].workerResting)
    }

    func test_oldSaveWithoutRestKeys_decodesAwake() throws {
        let stall = try JSONDecoder().decode(StallState.self, from: Data(#"{"cashierCount":1,"cashierEnergy":0.1,"menuCookEnergy":[0.0,1,1]}"#.utf8))
        XCTAssertFalse(stall.cashierResting)
        XCTAssertEqual(stall.menuCookResting, [false, false, false])
        let farm = try JSONDecoder().decode(FarmState.self, from: Data(#"{"plots":[{"growth":0.4,"isPlanted":true,"workerType":"alba","workerEnergy":0.0}]}"#.utf8))
        XCTAssertFalse(farm.plots[0].workerResting)
    }

    func test_shortRestArray_isPaddedToTheMenuCount() throws {
        let stall = try JSONDecoder().decode(StallState.self, from: Data(#"{"menuCookResting":[true]}"#.utf8))
        XCTAssertEqual(stall.menuCookResting, [true, false, false])
    }
}
