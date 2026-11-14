import XCTest
@testable import GameCore

@MainActor
final class MissionTests: DotWorldTestCase {

    private func mission(_ kind: MissionKind) -> Mission? {
        store.missions.first { $0.kind == kind }
    }

    /// Replaces today's missions with a known set so progress tests do not depend on the date roll.
    private func forceMissions(_ kinds: [MissionKind], target: Int = 2, reward: Double = 150) {
        let key = MissionSystem.dayKey(for: clock.date, calendar: DotWorldTestSupport.calendar())
        let list = kinds.map { Mission(id: "\(key)-\($0.rawValue)", kind: $0, target: target, reward: reward) }
        store.testReplaceMissions(MissionState(dayKey: key, missions: list))
    }

    // MARK: Roll

    func test_threeMissions_distinctKinds_onInit() {
        XCTAssertEqual(store.missions.count, 3)
        XCTAssertEqual(Set(store.missions.map(\.kind)).count, 3)
        XCTAssertEqual(store.missionState.dayKey, 20261114)
    }

    func test_roll_isDeterministicPerDate() {
        let a = MissionSystem.roll(dayKey: 20261114, stallTier: 1, earningRate: 5, rating: 4)
        let b = MissionSystem.roll(dayKey: 20261114, stallTier: 1, earningRate: 5, rating: 4)
        XCTAssertEqual(a, b)
        let kinds = (20261101...20261130).map {
            MissionSystem.roll(dayKey: $0, stallTier: 0, earningRate: 0, rating: 4).map(\.kind)
        }
        XCTAssertGreaterThan(Set(kinds).count, 5, "different days draw different sets")
    }

    func test_roll_everyDayHasNoDuplicates() {
        for day in 1...28 {
            let kinds = MissionSystem.roll(dayKey: 20261100 + day, stallTier: 0, earningRate: 0, rating: 5).map(\.kind)
            XCTAssertEqual(Set(kinds).count, 3)
        }
    }

    func test_gourmetMission_onlyWhenRatingAtLeastThree() {
        for day in 1...60 {
            let key = 20260100 + day
            let low = MissionSystem.roll(dayKey: key, stallTier: 0, earningRate: 0, rating: 2.99)
            XCTAssertFalse(low.contains { $0.kind == .serveGourmets })
            XCTAssertEqual(low.count, 3)
        }
        let offered = (1...60).contains {
            MissionSystem.roll(dayKey: 20260100 + $0, stallTier: 0, earningRate: 0, rating: 3.0)
                .contains { $0.kind == .serveGourmets }
        }
        XCTAssertTrue(offered)
    }

    func test_targets_scaleWithStallTier() {
        for (tier, expected) in [(0, 20), (1, 40), (2, 80)] {
            XCTAssertEqual(MissionSystem.target(for: .serveCustomers, stallTier: tier, earningRate: 0), expected)
        }
        XCTAssertEqual(MissionSystem.target(for: .harvest, stallTier: 1, earningRate: 0), 30)
        XCTAssertEqual(MissionSystem.target(for: .cookDishes, stallTier: 2, earningRate: 0), 60)
        XCTAssertEqual(MissionSystem.target(for: .triggerFever, stallTier: 2, earningRate: 0), 3)
        XCTAssertEqual(MissionSystem.target(for: .serveGourmets, stallTier: 0, earningRate: 0), 1)
        XCTAssertEqual(MissionSystem.target(for: .serveCustomers, stallTier: 9, earningRate: 0), 80)
    }

    func test_earnTarget_is120Seconds_withBaseFloor_andCleanNumber() {
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 0, earningRate: 0), 360)
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 0, earningRate: 10.1), 1200)   // 1212 -> 1200
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 0, earningRate: 40.27), 4800)  // 4832 -> 4800
    }

    func test_reward_isNinetySecondsOfIncome_min100_andFixedAtRoll() {
        XCTAssertEqual(MissionSystem.reward(earningRate: 0), 100)
        XCTAssertEqual(MissionSystem.reward(earningRate: 2), 180 )
        XCTAssertEqual(MissionSystem.reward(earningRate: 0.5), 100)

        store.progress.earningRate = 10
        clock.date = DotWorldTestSupport.date(2026, 11, 15)
        store.tick(deltaTime: 1)
        XCTAssertTrue(store.missions.allSatisfy { $0.reward == 900 })
        store.progress.earningRate = 1000
        XCTAssertTrue(store.missions.allSatisfy { $0.reward == 900 }, "does not float with the rate")
    }

    func test_rewardAndEarnTarget_floorOnBestSalePrice() {
        // A mid/late save whose measured rate lags (just moved or prestiged) must not roll 100 coins.
        XCTAssertEqual(MissionSystem.reward(earningRate: 0, bestSalePrice: 540), 5400)
        XCTAssertEqual(MissionSystem.reward(earningRate: 100, bestSalePrice: 540), 9000, "rate still wins when higher")
        XCTAssertEqual(MissionSystem.reward(earningRate: 0, bestSalePrice: 3), 100, "minimum still applies")
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 1, earningRate: 0, bestSalePrice: 540), 6500) // 6480
        XCTAssertEqual(MissionSystem.target(for: .earnCoins, stallTier: 1, earningRate: 100, bestSalePrice: 5), 12000)
        let rolled = MissionSystem.roll(dayKey: 20261114, stallTier: 2, earningRate: 0, rating: 4, bestSalePrice: 540)
        XCTAssertTrue(rolled.allSatisfy { $0.reward == 5400 })
    }

    func test_roll_usesBestUnlockedMenuPrice_atRollTime() {
        store.stall.menuTier = 2
        store.stall.locationTier = 1
        store.progress.earningRate = 0
        let price = EarningsSystem.salePrice(for: store.stall, menuIndex: 2, prestigeCount: store.progress.prestigeCount)
        clock.date = DotWorldTestSupport.date(2026, 11, 15)
        store.tick(deltaTime: 1)
        XCTAssertTrue(store.missions.allSatisfy { $0.reward == max(100, 10 * price) })
        XCTAssertGreaterThan(store.missions[0].reward, 100)
    }

    // MARK: Rollover

    func test_sameDay_keepsMissionsAndProgress() {
        forceMissions([.harvest, .cookDishes, .earnCoins])
        store.farm.plots[1].growth = 1
        store.stall.warehouse = 0
        store.harvest(plotIndex: 1)
        clock.date = DotWorldTestSupport.date(2026, 11, 14, 23, 59)
        store.tick(deltaTime: 1)
        XCTAssertEqual(mission(.harvest)?.progress, 1)
    }

    func test_rollover_atLocalMidnight() {
        let first = store.missions
        clock.date = DotWorldTestSupport.date(2026, 11, 14, 23, 59)
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.missions, first)
        clock.date = DotWorldTestSupport.date(2026, 11, 15, 0, 0)
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.missionState.dayKey, 20261115)
        XCTAssertTrue(store.missions.allSatisfy { $0.id.hasPrefix("20261115-") })
        XCTAssertTrue(store.missions.allSatisfy { $0.progress == 0 && !$0.isClaimed })
    }

    func test_rolloverCheck_isThrottledToOncePerSecond() {
        clock.date = DotWorldTestSupport.date(2026, 11, 15)
        store.tick(deltaTime: 0.5)
        XCTAssertEqual(store.missionState.dayKey, 20261114)
        store.tick(deltaTime: 0.5)
        XCTAssertEqual(store.missionState.dayKey, 20261115)
    }

    func test_rollover_onInit_whenSavedDayIsStale() {
        forceMissions([.harvest, .cookDishes, .earnCoins])
        store.collectCoins()   // save
        clock.date = DotWorldTestSupport.date(2026, 12, 1)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.missionState.dayKey, 20261201)
    }

    func test_sameDay_survivesRelaunch() {
        forceMissions([.harvest, .cookDishes, .earnCoins])
        store.farm.plots[1].growth = 1
        store.stall.warehouse = 0
        store.harvest(plotIndex: 1)
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.missions.first { $0.kind == .harvest }?.progress, 1)
    }

    // MARK: Progress

    func test_serve_feedsServeAndGourmetMissions() {
        forceMissions([.serveCustomers, .serveGourmets, .earnCoins], target: 5)
        store.recordServed(waitTime: 1)
        store.recordServed(waitTime: 1, isGourmet: true)
        XCTAssertEqual(mission(.serveCustomers)?.progress, 2)
        XCTAssertEqual(mission(.serveGourmets)?.progress, 1)
    }

    func test_sell_feedsEarnCoins() {
        forceMissions([.earnCoins, .harvest, .cookDishes], target: 100)
        store.stall.menuStock[0] = 5
        _ = store.sellItem(menuIndex: 0)
        _ = store.sellItem(menuIndex: 0, isGourmet: true)
        XCTAssertEqual(mission(.earnCoins)?.progress, 100, "30 + 90 clamps at the target")
    }

    func test_manualAndWorkerHarvest_feedHarvest() {
        forceMissions([.harvest, .cookDishes, .earnCoins], target: 5)
        store.farm.plots[1].growth = 1
        store.stall.warehouse = 0
        store.harvest(plotIndex: 1)
        XCTAssertEqual(mission(.harvest)?.progress, 1)

        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(mission(.harvest)?.progress, 2)
    }

    func test_goldenBonus_countsTowardEarnCoins() {
        forceMissions([.earnCoins, .harvest, .cookDishes], target: 1000)
        store.farm.plots[1].growth = 1
        store.farm.plots[1].isGolden = true
        store.stall.warehouse = 0
        store.harvest(plotIndex: 1)
        XCTAssertEqual(mission(.earnCoins)?.progress, 450)
    }

    func test_manualAndAutoCook_feedCook() {
        forceMissions([.cookDishes, .harvest, .earnCoins], target: 20)
        store.stall.warehouse = 5
        store.startManualCook(menuIndex: 0)
        store.tick(deltaTime: 10)
        XCTAssertEqual(mission(.cookDishes)?.progress, 1)

        store.stall.menuCooks[0] = 1
        store.tick(deltaTime: 8)   // 0.14/s: at least one portion
        XCTAssertGreaterThanOrEqual(mission(.cookDishes)?.progress ?? 0, 2)
    }

    func test_fever_feedsFeverMission() {
        forceMissions([.triggerFever, .harvest, .cookDishes], target: 2)
        chargeFever()
        store.startFever()
        XCTAssertEqual(mission(.triggerFever)?.progress, 1)
    }

    func test_progress_clampsAtTarget() {
        forceMissions([.serveCustomers, .harvest, .cookDishes], target: 2)
        serve(5)
        XCTAssertEqual(mission(.serveCustomers)?.progress, 2)
    }

    // MARK: Claim

    func test_claim_paysOnce_andCountsInTotalEarned() {
        forceMissions([.serveCustomers, .harvest, .cookDishes], target: 2, reward: 250)
        let id = mission(.serveCustomers)!.id
        XCTAssertNil(store.claimMission(id: id), "incomplete")
        XCTAssertEqual(store.unclaimedCompletedMissionCount, 0)

        serve(2)
        XCTAssertEqual(store.unclaimedCompletedMissionCount, 1)
        let coins = store.stall.coins, earned = store.progress.totalEarned
        XCTAssertEqual(store.claimMission(id: id), 250)
        XCTAssertEqual(store.stall.coins, coins + 250)
        XCTAssertEqual(store.progress.totalEarned, earned + 250)
        XCTAssertNil(store.claimMission(id: id), "second claim pays nothing")
        XCTAssertEqual(store.stall.coins, coins + 250)
        XCTAssertEqual(store.unclaimedCompletedMissionCount, 0)
        XCTAssertNil(store.claimMission(id: "nope"))
    }

    func test_claim_persists() {
        forceMissions([.serveCustomers, .harvest, .cookDishes], target: 1)
        serve(1)
        let id = mission(.serveCustomers)!.id
        store.claimMission(id: id)
        XCTAssertEqual(makeStore().missions.first { $0.id == id }?.isClaimed, true)
    }

    func test_missionsSurviveNewRun() {
        forceMissions([.serveCustomers, .harvest, .cookDishes], target: 1, reward: 321)
        serve(1)
        let before = store.missions
        prepareForPrestige()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.missions, before)
        XCTAssertEqual(store.claimMission(id: before[0].id), 321)
    }
}

@MainActor
extension GameStore {
    func testReplaceMissions(_ state: MissionState) { replaceMissionsForTesting(state) }
}
