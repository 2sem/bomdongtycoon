import XCTest
@testable import GameCore

/// Wages are paid once per game day (one `DayCycle` loop of play time), and a worker can be fired.
@MainActor
final class WageTests: DotWorldTestCase {

    private let day = DayCycle.loopSeconds

    private func run(_ seconds: Double) {
        var left = seconds
        while left > 1e-9 {
            let step = min(0.5, left)
            store.tick(deltaTime: step)
            left -= step
        }
    }

    /// No staff anywhere: a clean slate to add exactly the workers a test wants.
    private func emptyStall(coins: Double = 10_000) {
        store.stall.tier1Count = 0; store.stall.tier2Count = 0; store.stall.tier3Count = 0
        store.stall.farmerCount = 0; store.stall.veteranAlbaCount = 0
        store.stall.tier1IdleEnergies = []; store.stall.tier2IdleEnergies = []; store.stall.tier3IdleEnergies = []
        store.stall.farmerIdleEnergies = []; store.stall.veteranAlbaIdleEnergies = []
        store.stall.cashierCount = 0; store.stall.cashierTier = 0
        store.stall.menuCooks = [0, 0, 0]
        for i in store.farm.plots.indices { store.farm.plots[i].workerType = .none }
        store.stall.coins = coins
        store.stall.warehouse = 0
    }

    private func benchAlba(_ n: Int) {
        store.stall.tier1Count += n
        store.stall.tier1IdleEnergies += Array(repeating: 1.0, count: n)
    }

    // MARK: Wage table and payroll

    func test_wageTable_risesWithTier() {
        XCTAssertEqual(WageSystem.wage(forTier: 1), 50)
        XCTAssertEqual(WageSystem.wage(forTier: 2), 250)
        XCTAssertEqual(WageSystem.wage(forTier: 3), 1_000)
        XCTAssertEqual(WageSystem.wage(forTier: 4), 120)
        XCTAssertEqual(WageSystem.wage(forTier: 5), 80)
        XCTAssertEqual(WageSystem.wage(forTier: 9), 0)
        XCTAssertLessThan(WageSystem.wage(forTier: 1), WageSystem.wage(forTier: 2))
        XCTAssertLessThan(WageSystem.wage(forTier: 2), WageSystem.wage(forTier: 3))
        // Every wage is a small fraction of the hire price, and the first hire is never the heavy one.
        for tier in 1...3 {
            XCTAssertLessThan(WageSystem.wage(forTier: tier), UpgradeDefinitions.staff[tier - 1].coinCost * 0.25)
        }
    }

    func test_payroll_countsEveryWorkerPostedOrBenched() {
        emptyStall()
        store.stall.tier1Count = 2; store.stall.tier2Count = 1; store.stall.tier3Count = 1
        store.stall.farmerCount = 1; store.stall.veteranAlbaCount = 1
        let expected: Double = 100 + 250 + 1_000 + 120 + 80
        XCTAssertEqual(store.dailyPayroll, expected)
        XCTAssertEqual(WageSystem.headcount(stall: store.stall), 6)
    }

    // MARK: Payday timing

    func test_payday_notBeforeTheDayBoundary_thenOnce() {
        emptyStall(); benchAlba(2)
        run(day - 1)
        XCTAssertEqual(store.stall.coins, 10_000)
        XCTAssertNil(store.payday)
        run(2)
        XCTAssertEqual(store.stall.coins, 10_000 - 100)
        XCTAssertEqual(store.payday?.paid, 100)
        XCTAssertEqual(store.payday?.paidCount, 2)
        XCTAssertEqual(store.payday?.unpaidCount, 0)
        XCTAssertEqual(store.progress.totalWagesPaid, 100)
        run(day - 10)
        XCTAssertEqual(store.stall.coins, 10_000 - 100, "one payday per day")
        run(20)
        XCTAssertEqual(store.stall.coins, 10_000 - 200)
        XCTAssertEqual(store.payday?.id, 2)
    }

    func test_longTick_settlesEachCrossedDay() {
        emptyStall(); benchAlba(1)
        store.tick(deltaTime: day * 3 + 1)
        XCTAssertEqual(store.stall.coins, 10_000 - 150)
        XCTAssertEqual(store.progress.lastWageDay, 3)
    }

    func test_noStaff_noPaydayEvent() {
        emptyStall()
        run(day + 1)
        XCTAssertNil(store.payday)
        XCTAssertEqual(store.stall.coins, 10_000)
    }

    func test_secondsUntilPayday_countsDownToTheBoundary() {
        run(60)
        XCTAssertEqual(store.secondsUntilPayday, day - 60, accuracy: 0.01)
    }

    func test_notCharged_whileAppInactive() {
        emptyStall(); benchAlba(3)
        store.isAppActive = false
        run(day * 2)
        XCTAssertEqual(store.stall.coins, 10_000, "the day only advances in play time")
        XCTAssertEqual(store.progress.totalPlaySeconds, 0)
    }

    func test_notCharged_whilePaused() {
        emptyStall(); benchAlba(3)
        store.isSimulationPaused = true
        run(day * 2)
        XCTAssertEqual(store.stall.coins, 10_000)
    }

    func test_offlineEarnings_areNotTouchedByWages() {
        emptyStall(); benchAlba(3)
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = 10
        store.progress.lastActiveDate = clock.date.addingTimeInterval(-3_600)
        let coins = store.stall.coins
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.stall.coins, coins)
        XCTAssertEqual(store.progress.lastWageDay, 0)
    }

    // MARK: Migration

    func test_oldSave_startsAtItsCurrentDay_noBackCharge() throws {
        var progress = PlayerProgress()
        progress.totalPlaySeconds = day * 12 + 30
        let data = try JSONEncoder().encode(progress)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "lastWageDay")
        json.removeValue(forKey: "totalWagesPaid")
        let old = try JSONSerialization.data(withJSONObject: json)
        defaults.set(old, forKey: GameStore.SaveBlob.progress.key)

        let loaded = makeStore()
        XCTAssertEqual(loaded.progress.lastWageDay, 12)
        let coins = loaded.stall.coins
        loaded.tick(deltaTime: 1)
        XCTAssertEqual(loaded.stall.coins, coins)
        XCTAssertNil(loaded.payday)
        loaded.tick(deltaTime: day)
        XCTAssertLessThan(loaded.stall.coins, coins + 1, "the next day boundary does pay")
    }

    func test_newSpring_doesNotBackChargeTheKeptPlayClock() {
        store.progress.totalPlaySeconds = day * 5 + 10
        store.progress.lastWageDay = 5
        store.stall.menuTier = 2; store.stall.stallTier = 2; store.stall.locationTier = 2
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.progress.lastWageDay, 5)
        let coins = store.stall.coins
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.stall.coins, coins)
    }

    // MARK: Partial payment and strikes

    func test_cannotAffordAll_paysAsManyAsCover_andNeverGoesNegative() {
        emptyStall(coins: 120); benchAlba(3)
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.paidCount, 2)
        XCTAssertEqual(result.unpaidCount, 1)
        XCTAssertEqual(store.stall.coins, 20)
        XCTAssertGreaterThanOrEqual(store.stall.coins, 0)
    }

    func test_penniless_nobodyPaid_everyoneStrikes_coinsStayZero() {
        emptyStall(coins: 0); benchAlba(2)
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.paidCount, 0)
        XCTAssertEqual(store.stall.coins, 0)
        XCTAssertEqual(store.stall.tier1IdleEnergies, [0, 0])
    }

    func test_payOrder_postsBeforeBench_benchStrikesFirst() {
        emptyStall(coins: 100)
        // Two albas: one cooking, one on the bench; only one wage (+50 left over) is covered.
        store.stall.tier1Count = 2
        store.stall.menuCooks[0] = 1
        store.stall.menuCookEnergy[0] = 0.8
        store.stall.tier1IdleEnergies = [0.9]
        store.stall.coins = 50
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.paidCount, 1)
        XCTAssertEqual(store.stall.menuCookEnergy[0], 0.8, "the cook was paid and keeps working")
        XCTAssertFalse(store.stall.menuCookResting[0])
        XCTAssertEqual(store.stall.tier1IdleEnergies, [0], "the benched one went on strike")
    }

    func test_payOrder_isCooksCashierFarmThenBench_deterministically() {
        emptyStall(coins: 0)
        store.stall.tier1Count = 3
        store.stall.menuCooks[1] = 1
        store.stall.cashierCount = 1; store.stall.cashierTier = 1
        store.farm.plots[0].workerType = .alba
        // Coins for exactly the cook and the cashier.
        store.stall.coins = 100
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.paidCount, 2)
        XCTAssertFalse(store.stall.menuCookResting[1])
        XCTAssertFalse(store.stall.cashierResting)
        XCTAssertTrue(store.farm.plots[0].workerResting, "the farm hand is after the counter in line")
        XCTAssertEqual(store.farm.plots[0].workerEnergy, 0)
        XCTAssertEqual(store.stall.coins, 0)
    }

    func test_strike_usesTheRestMechanic_asleepUntilFullEnergy() {
        emptyStall(coins: 0)
        store.stall.tier1Count = 1
        store.stall.menuCooks[0] = 1
        store.stall.menuCookEnergy[0] = 1
        store.stall.warehouse = 0
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.unpaidCount, 1)
        XCTAssertTrue(store.isResting(.cook(menuIndex: 0)))
        XCTAssertEqual(store.stall.menuCookEnergy[0], 0)
        run(95)
        XCTAssertFalse(store.isResting(.cook(menuIndex: 0)), "back after the full 90 s rest")
    }

    func test_cheaperBenchWorkerStillPaid_whenAnExpensiveOneCannotBe() {
        emptyStall(coins: 60)
        store.stall.tier3Count = 1; store.stall.tier3IdleEnergies = [1]
        store.stall.tier1Count = 1; store.stall.tier1IdleEnergies = [1]
        let result = WageSystem.settle(stall: &store.stall, farm: &store.farm)
        XCTAssertEqual(result.paidCount, 1)
        XCTAssertEqual(store.stall.tier3IdleEnergies, [0])
        XCTAssertEqual(store.stall.tier1IdleEnergies, [1])
        XCTAssertEqual(store.stall.coins, 10)
    }

    func test_paydayEvent_reportsUnpaid() {
        emptyStall(coins: 60); benchAlba(2)
        store.tick(deltaTime: day + 1)
        XCTAssertEqual(store.payday?.paidCount, 1)
        XCTAssertEqual(store.payday?.unpaidCount, 1)
        XCTAssertEqual(store.progress.totalWagesPaid, 50)
    }

    // MARK: Firing

    private func assertConsistent(file: StaticString = #filePath, line: UInt = #line) {
        let s = store.stall
        let posted1 = s.menuCooks.filter { $0 == 1 }.count + (s.cashierTier == 1 ? s.cashierCount : 0)
            + store.farm.plots.filter { $0.workerType == .alba }.count
        let posted2 = s.menuCooks.filter { $0 == 2 }.count + (s.cashierTier == 2 ? s.cashierCount : 0)
        XCTAssertEqual(s.tier1IdleEnergies.count, s.tier1Count - posted1, file: file, line: line)
        XCTAssertEqual(s.tier2IdleEnergies.count, s.tier2Count - posted2, file: file, line: line)
        XCTAssertEqual(s.tier3IdleEnergies.count, s.tier3Count - s.menuCooks.filter { $0 == 3 }.count, file: file, line: line)
        XCTAssertEqual(store.availableWorkers, s.staffCount - store.farm.plots.filter { $0.workerType == .alba }.count
                       - s.cashierCount - s.menuCooks.filter { $0 > 0 }.count, file: file, line: line)
        XCTAssertGreaterThanOrEqual(store.availableWorkers, 0, file: file, line: line)
    }

    func test_fire_cook_freesTheDishAndDropsTheCount() {
        emptyStall()
        store.stall.tier2Count = 1; store.stall.menuCooks[0] = 2; store.stall.menuCookEnergy[0] = 0.3
        XCTAssertTrue(store.fireWorker(.cook(menuIndex: 0)))
        XCTAssertEqual(store.stall.tier2Count, 0)
        XCTAssertEqual(store.stall.menuCooks[0], 0)
        XCTAssertTrue(store.stall.tier2IdleEnergies.isEmpty, "she does not return to the bench")
        XCTAssertEqual(store.stall.menuCookEnergy[0], 1)
        XCTAssertFalse(store.stall.menuCookResting[0])
        assertConsistent()
    }

    func test_fire_cook_whileAsleep() {
        emptyStall()
        store.stall.tier3Count = 1; store.stall.menuCooks[2] = 3
        store.stall.menuCookEnergy[2] = 0; store.stall.menuCookResting[2] = true
        XCTAssertTrue(store.fireWorker(.cook(menuIndex: 2)))
        XCTAssertEqual(store.stall.tier3Count, 0)
        XCTAssertFalse(store.stall.menuCookResting[2], "the next hire at this post does not inherit the nap")
        assertConsistent()
    }

    func test_fire_cashier() {
        emptyStall()
        store.stall.tier1Count = 1; store.stall.cashierCount = 1; store.stall.cashierTier = 1
        store.stall.cashierResting = true; store.stall.cashierEnergy = 0
        XCTAssertTrue(store.fireWorker(.cashier))
        XCTAssertEqual(store.stall.tier1Count, 0)
        XCTAssertEqual(store.stall.cashierCount, 0)
        XCTAssertEqual(store.stall.cashierTier, 0)
        XCTAssertFalse(store.stall.cashierResting)
        assertConsistent()
    }

    func test_fire_farmHand_everyType() {
        emptyStall()
        store.stall.tier1Count = 1; store.stall.farmerCount = 1; store.stall.veteranAlbaCount = 1
        store.farm.plots[0].workerType = .alba
        store.farm.plots[1].workerType = .farmer; store.farm.plots[1].workerResting = true
        store.farm.plots[2].workerType = .veteranAlba
        XCTAssertTrue(store.fireWorker(.farm(plotIndex: 1)))
        XCTAssertEqual(store.farm.plots[1].workerType, .none)
        XCTAssertFalse(store.farm.plots[1].workerResting)
        XCTAssertEqual(store.stall.farmerCount, 0)
        XCTAssertTrue(store.stall.farmerIdleEnergies.isEmpty)
        XCTAssertTrue(store.fireWorker(.farm(plotIndex: 2)))
        XCTAssertEqual(store.stall.veteranAlbaCount, 0)
        XCTAssertTrue(store.fireWorker(.farm(plotIndex: 0)))
        XCTAssertEqual(store.stall.tier1Count, 0)
        XCTAssertTrue(store.farm.plots.allSatisfy { !$0.hasWorker })
        assertConsistent()
    }

    func test_fire_benched_everyTier_removesThatPoolEntry() {
        emptyStall()
        store.stall.tier1Count = 2; store.stall.tier1IdleEnergies = [0.2, 0.9]
        store.stall.tier2Count = 1; store.stall.tier2IdleEnergies = [0.5]
        store.stall.tier3Count = 1; store.stall.tier3IdleEnergies = [0.6]
        store.stall.farmerCount = 1; store.stall.farmerIdleEnergies = [0.7]
        store.stall.veteranAlbaCount = 1; store.stall.veteranAlbaIdleEnergies = [0.8]
        XCTAssertTrue(store.fireWorker(.idle(tier: 1, index: 0)))
        XCTAssertEqual(store.stall.tier1IdleEnergies, [0.9])
        XCTAssertTrue(store.fireWorker(.idle(tier: 2, index: 0)))
        XCTAssertTrue(store.fireWorker(.idle(tier: 3, index: 0)))
        XCTAssertTrue(store.fireWorker(.idle(tier: 4, index: 0)))
        XCTAssertTrue(store.fireWorker(.idle(tier: 5, index: 0)))
        XCTAssertEqual(store.stall.tier1Count, 1)
        XCTAssertEqual(WageSystem.headcount(stall: store.stall), 1)
        assertConsistent()
    }

    func test_fire_nothingThere_changesNothing() {
        emptyStall()
        XCTAssertFalse(store.fireWorker(.cook(menuIndex: 0)))
        XCTAssertFalse(store.fireWorker(.cashier))
        XCTAssertFalse(store.fireWorker(.farm(plotIndex: 0)))
        XCTAssertFalse(store.fireWorker(.farm(plotIndex: 99)))
        XCTAssertFalse(store.fireWorker(.idle(tier: 1, index: 0)))
        XCTAssertFalse(store.fireWorker(.idle(tier: 9, index: 0)))
        // A posted worker is not on the bench.
        store.stall.tier1Count = 1; store.stall.menuCooks[0] = 1
        XCTAssertFalse(store.fireWorker(.idle(tier: 1, index: 0)))
        XCTAssertEqual(store.stall.tier1Count, 1)
    }

    func test_fire_keepsStaffTier_andGoalsDoNotRegress() {
        emptyStall()
        store.stall.staffTier = 2
        store.stall.tier2Count = 1; store.stall.tier2IdleEnergies = [1]
        store.fireWorker(.idle(tier: 2, index: 0))
        XCTAssertEqual(store.stall.staffTier, 2, "staffTier is the highest tier ever hired")
        XCTAssertEqual(store.stall.staffCount, 0)
    }

    func test_fire_stopsThatWorkersWage() {
        emptyStall(); benchAlba(2)
        store.fireWorker(.idle(tier: 1, index: 0))
        XCTAssertEqual(store.dailyPayroll, 50)
        store.tick(deltaTime: day + 1)
        XCTAssertEqual(store.stall.coins, 10_000 - 50)
    }

    func test_fireThenRehire_paysTheFullHirePrice_noRefund() {
        emptyStall(coins: 1_000)
        XCTAssertNotNil(store.hireWorker(tier: 1))
        XCTAssertEqual(store.stall.coins, 700)
        let fired = store.fireWorker(.farm(plotIndex: 0)) || store.fireWorker(.cook(menuIndex: 0))
            || store.fireWorker(.cashier) || store.fireWorker(.idle(tier: 1, index: 0))
        XCTAssertTrue(fired)
        XCTAssertEqual(store.stall.coins, 700, "no refund")
        XCTAssertNotNil(store.hireWorker(tier: 1))
        XCTAssertEqual(store.stall.coins, 400, "rehiring costs the full price again")
    }

    func test_fireBeforePayday_isNotAnExploit() {
        emptyStall(coins: 2_000); benchAlba(1)
        store.tick(deltaTime: day - 5)
        store.fireWorker(.idle(tier: 1, index: 0))
        XCTAssertNotNil(store.hireWorker(tier: 1))
        XCTAssertEqual(store.stall.coins, 1_700, "the rehire cost 300 and nothing came back")
        store.tick(deltaTime: 10)
        XCTAssertEqual(store.payday?.paid, 50, "the rehired worker is paid at the boundary like anyone")
    }

    func test_fire_survivesAReload() {
        emptyStall(); benchAlba(2)
        store.fireWorker(.idle(tier: 1, index: 0))
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.stall.tier1Count, 1)
        XCTAssertEqual(reloaded.stall.tier1IdleEnergies.count, 1)
    }

    // MARK: Worker levels

    /// Every level of every worker the store holds: posts, farm plots and the five benches.
    private func allLevels() -> [Int] {
        let st = store.stall
        var out = st.menuCooks.indices.filter { st.menuCooks[$0] > 0 }.map { st.menuCookLevels[$0] }
        if st.cashierCount > 0 { out.append(st.cashierLevel) }
        out += store.farm.plots.filter(\.hasWorker).map(\.workerLevel)
        out += st.tier1IdleLevels + st.tier2IdleLevels + st.tier3IdleLevels
        out += st.farmerIdleLevels + st.veteranAlbaIdleLevels
        return out
    }

    func test_everyTypeStartsAtLevelOne() {
        XCTAssertEqual(store.farm.plots[0].workerLevel, 1, "the free starting 알바생")
        emptyStall(coins: 1_000_000)
        store.stall.stallTier = 2
        for tier in 1...3 { XCTAssertNotNil(store.hireWorker(tier: tier)) }
        XCTAssertNotNil(store.hireFarmer())
        XCTAssertNotNil(store.hireVeteranAlba())
        XCTAssertEqual(allLevels().count, 5)
        XCTAssertTrue(allLevels().allSatisfy { $0 == 1 })
    }

    func test_oldSaveWithoutLevels_decodesToLevelOne() throws {
        emptyStall(); benchAlba(2)
        store.stall.menuCooks[0] = 1; store.stall.tier1Count += 1
        var stallJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(store.stall)) as! [String: Any]
        for key in ["menuCookLevels", "cashierLevel", "tier1IdleLevels", "tier2IdleLevels", "tier3IdleLevels",
                    "farmerIdleLevels", "veteranAlbaIdleLevels"] { stallJSON[key] = nil }
        let stall = try JSONDecoder().decode(StallState.self, from: JSONSerialization.data(withJSONObject: stallJSON))
        XCTAssertEqual(stall.menuCookLevels, [1, 1, 1])
        XCTAssertEqual(stall.cashierLevel, 1)
        XCTAssertEqual(stall.tier1IdleLevels, [], "read as Lv.1 and padded to the energy pool on use")

        var plotJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(store.farm.plots[0])) as! [String: Any]
        plotJSON["workerLevel"] = nil
        let plot = try JSONDecoder().decode(FarmPlot.self, from: JSONSerialization.data(withJSONObject: plotJSON))
        XCTAssertEqual(plot.workerLevel, 1)
    }

    func test_levelTable_isStrictlyFasterAndBetterPaid_everyStep_everyType() {
        for level in 1..<StaffLevelSystem.maxLevel {
            XCTAssertGreaterThan(StaffLevelSystem.speedMultiplier(level: level + 1),
                                 StaffLevelSystem.speedMultiplier(level: level))
            for tier in 1...5 {
                XCTAssertGreaterThan(WageSystem.wage(forTier: tier, level: level + 1),
                                     WageSystem.wage(forTier: tier, level: level), "tier \(tier) Lv.\(level)")
                let step = StaffLevelSystem.step(tier: tier, fromLevel: level)!
                XCTAssertGreaterThan(step.speedGainPercent, 0)
                XCTAssertGreaterThan(step.wageAfter, step.wageBefore)
                XCTAssertEqual(step.cost, StaffLevelSystem.cost(tier: tier, fromLevel: level))
                if level > 1 {
                    XCTAssertGreaterThan(step.cost, StaffLevelSystem.cost(tier: tier, fromLevel: level - 1)!,
                                         "each step costs more than the last")
                }
            }
            XCTAssertGreaterThan(EarningsSystem.cashierMultiplier(tier: 1, level: level + 1),
                                 EarningsSystem.cashierMultiplier(tier: 1, level: level))
            XCTAssertGreaterThan(EarningsSystem.cashierMultiplier(tier: 5, level: level + 1),
                                 EarningsSystem.cashierMultiplier(tier: 5, level: level))
        }
        XCTAssertNil(StaffLevelSystem.step(tier: 1, fromLevel: StaffLevelSystem.maxLevel))
        XCTAssertEqual(StaffLevelSystem.wageMultiplier(level: 1), 1)
        XCTAssertEqual(WageSystem.wage(forTier: 1, level: 2), 63)
    }

    func test_pay_risesFasterThanSpeed() {
        for level in 2...StaffLevelSystem.maxLevel {
            XCTAssertGreaterThan(StaffLevelSystem.wageMultiplier(level: level) - 1,
                                 StaffLevelSystem.speedMultiplier(level: level) - 1)
        }
    }

    func test_cook_producesMoreAtAHigherLevel() {
        func dishes(level: Int) -> Int {
            emptyStall(); benchAlba(1)
            store.stall.warehouse = 100
            store.stall.menuStock = [0, 0, 0]
            store.assignMenuCook(menuIndex: 0, tier: 1)
            store.stall.menuCookLevels[0] = level
            run(20)
            return store.stall.menuStock[0]
        }
        XCTAssertGreaterThan(dishes(level: StaffLevelSystem.maxLevel), dishes(level: 1))
    }

    func test_farmHand_growsCropsFasterAtAHigherLevel() {
        func growth(level: Int) -> Double {
            emptyStall(); benchAlba(1)
            store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
            store.farm.plots[0].isPlanted = true
            store.farm.plots[0].growth = 0
            store.farm.plots[0].workerLevel = level
            run(2)
            return store.farm.plots[0].growth
        }
        XCTAssertGreaterThan(growth(level: StaffLevelSystem.maxLevel), growth(level: 1))
    }

    func test_cashier_levelRaisesTheSaleBonus() {
        emptyStall(); benchAlba(1)
        store.assignToCashier(tier: 1)
        let base = EarningsSystem.cashierSaleMultiplier(for: store.stall)
        store.stall.cashierLevel = StaffLevelSystem.maxLevel
        XCTAssertGreaterThan(EarningsSystem.cashierSaleMultiplier(for: store.stall), base)
    }

    func test_levelUp_chargesTheCostAndRaisesOnlyThatWorker() {
        emptyStall(coins: 1_000); benchAlba(2)
        let cost = StaffLevelSystem.cost(tier: 1, fromLevel: 1)!
        XCTAssertTrue(store.levelUp(.idle(tier: 1, index: 1)))
        XCTAssertEqual(store.stall.coins, 1_000 - cost)
        XCTAssertEqual(store.stall.tier1IdleLevels, [1, 2])
        XCTAssertEqual(store.level(of: .idle(tier: 1, index: 1)), 2)
    }

    func test_levelUp_isBlockedWhenShortAndAtMax() {
        emptyStall(coins: 10); benchAlba(1)
        XCTAssertFalse(store.levelUp(.idle(tier: 1, index: 0)))
        XCTAssertEqual(store.stall.coins, 10)
        XCTAssertEqual(store.stall.tier1IdleLevels, [1])

        store.stall.coins = 1_000_000
        for _ in 1..<StaffLevelSystem.maxLevel { XCTAssertTrue(store.levelUp(.idle(tier: 1, index: 0))) }
        let coins = store.stall.coins
        XCTAssertFalse(store.levelUp(.idle(tier: 1, index: 0)))
        XCTAssertEqual(store.stall.coins, coins)
        XCTAssertEqual(store.level(of: .idle(tier: 1, index: 0)), StaffLevelSystem.maxLevel)
        XCTAssertFalse(store.levelUp(.cashier), "nobody at the counter")
    }

    func test_levelUp_worksOnEveryPost() {
        emptyStall(coins: 1_000_000); benchAlba(3)
        store.assignMenuCook(menuIndex: 0, tier: 1)
        store.assignToCashier(tier: 1)
        store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
        XCTAssertTrue(store.levelUp(.cook(menuIndex: 0)))
        XCTAssertTrue(store.levelUp(.cashier))
        XCTAssertTrue(store.levelUp(.farm(plotIndex: 0)))
        XCTAssertEqual(store.stall.menuCookLevels[0], 2)
        XCTAssertEqual(store.stall.cashierLevel, 2)
        XCTAssertEqual(store.farm.plots[0].workerLevel, 2)
    }

    func test_level_followsTheWorkerThroughPostsAndTheBench() {
        emptyStall(coins: 1_000_000); benchAlba(2)
        XCTAssertTrue(store.levelUp(.idle(tier: 1, index: 1)))
        XCTAssertTrue(store.levelUp(.idle(tier: 1, index: 1)))   // second alba is Lv.3, the first Lv.1

        store.assignMenuCook(menuIndex: 0, tier: 1, idleIndex: 1)
        XCTAssertEqual(store.stall.menuCookLevels[0], 3, "taken by her own row, not the oldest")
        XCTAssertEqual(store.stall.tier1IdleLevels, [1])

        store.removeMenuCook(menuIndex: 0)
        XCTAssertEqual(store.stall.tier1IdleLevels, [1, 3], "back on the bench with her level")
        XCTAssertEqual(store.stall.menuCookLevels[0], 1, "the empty post resets")

        store.assignToCashier(tier: 1, idleIndex: 1)
        XCTAssertEqual(store.stall.cashierLevel, 3)
        // Post to post, skipping the bench.
        store.stall.menuTier = 1
        store.removeFromCashier(displayedEnergy: 0.7, addToIdle: false)
        store.assignMenuCook(menuIndex: 1, tier: 1, directEnergy: 0.7, directLevel: 3)
        XCTAssertEqual(store.stall.menuCookLevels[1], 3)
        XCTAssertEqual(store.stall.tier1IdleLevels, [1], "the bench is untouched")

        store.toggleFarmWorker(plotIndex: 0, workerType: .alba)
        XCTAssertEqual(store.farm.plots[0].workerLevel, 1)
        store.toggleFarmWorker(plotIndex: 0, workerType: .alba, addToIdle: true)
        XCTAssertEqual(store.stall.tier1IdleLevels, [1], "a worker keeps one entry per bench place")
        XCTAssertEqual(store.stall.tier1IdleLevels.count, store.stall.tier1IdleEnergies.count)
    }

    func test_farmerAndVeteran_keepTheirLevelOnAndOffTheFarm() {
        emptyStall(coins: 1_000_000)
        store.hireFarmer(); store.hireVeteranAlba()
        for (type, tier) in [(FarmWorkerType.farmer, 4), (.veteranAlba, 5)] {
            if type == .veteranAlba { store.removeFromCashier() }   // she took the till on hire
            if !store.farm.plots.contains(where: { $0.workerType == type }) {
                store.toggleFarmWorker(plotIndex: 1, workerType: type)
            }
            guard let plot = store.farm.plots.firstIndex(where: { $0.workerType == type }) else { return XCTFail() }
            XCTAssertTrue(store.levelUp(.farm(plotIndex: plot)))
            store.toggleFarmWorker(plotIndex: plot, workerType: type, addToIdle: true)
            XCTAssertEqual(store.level(of: .idle(tier: tier, index: 0)), 2)
            store.toggleFarmWorker(plotIndex: plot, workerType: type)
            XCTAssertEqual(store.farm.plots[plot].workerLevel, 2)
        }
    }

    func test_payroll_usesLevels() {
        emptyStall(coins: 100_000); benchAlba(2)
        XCTAssertEqual(store.dailyPayroll, 100)
        store.levelUp(.idle(tier: 1, index: 0))
        XCTAssertEqual(store.dailyPayroll, 50 + WageSystem.wage(forTier: 1, level: 2))
        store.assignMenuCook(menuIndex: 0, tier: 1)
        XCTAssertEqual(store.dailyPayroll, 50 + 63, "posted or benched, the same wage")
        store.tick(deltaTime: day + 1)
        XCTAssertEqual(store.payday?.paid, 113)
    }

    func test_fire_dropsTheLevel() {
        emptyStall(coins: 1_000_000); benchAlba(2)
        store.levelUp(.idle(tier: 1, index: 0))
        XCTAssertTrue(store.fireWorker(.idle(tier: 1, index: 0)))
        XCTAssertEqual(store.stall.tier1IdleLevels, [1])

        store.assignMenuCook(menuIndex: 0, tier: 1)
        store.levelUp(.cook(menuIndex: 0))
        XCTAssertTrue(store.fireWorker(.cook(menuIndex: 0)))
        XCTAssertEqual(store.stall.menuCookLevels[0], 1)
        XCTAssertNotNil(store.hireWorker(tier: 1))
        XCTAssertTrue(allLevels().allSatisfy { $0 == 1 }, "a new hire starts again at Lv.1")
    }

    func test_level_survivesAReload() {
        emptyStall(coins: 1_000_000); benchAlba(3)
        store.assignMenuCook(menuIndex: 0, tier: 1)                 // bench [1, 1]
        store.levelUp(.cook(menuIndex: 0))                          // cook Lv.2
        store.levelUp(.idle(tier: 1, index: 0)); store.levelUp(.idle(tier: 1, index: 0))   // bench [3, 1]
        store.toggleFarmWorker(plotIndex: 1, workerType: .alba)     // takes the oldest, Lv.3; bench [1]
        store.levelUp(.farm(plotIndex: 1))                          // Lv.4
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.stall.menuCookLevels[0], 2)
        XCTAssertEqual(reloaded.stall.tier1IdleLevels, [1])
        XCTAssertEqual(reloaded.farm.plots[1].workerLevel, 4)
    }
}
