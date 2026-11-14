import XCTest
@testable import GameCore

@MainActor
final class GoldenGourmetTests: DotWorldTestCase {

    /// Plot 1 starts planted at 0.5; ticking 6 s at the base 12 s growth ripens it.
    private func ripenPlot1(deltaTime: Double = 6) {
        store.farm.plots[0].isPlanted = false
        store.farm.plots[1].growth = 0.5
        store.tick(deltaTime: deltaTime)
    }

    // MARK: Golden roll

    func test_ripening_rollsAgainstSixPercent() {
        script.values = [0.99, 0.05]   // first call is the weather gap
        ripenPlot1()
        XCTAssertTrue(store.farm.plots[1].isReady)
        XCTAssertTrue(store.farm.plots[1].isGolden)
    }

    func test_ripening_aboveSixPercent_isNotGolden() {
        script.values = [0.99, 0.06]
        ripenPlot1()
        XCTAssertTrue(store.farm.plots[1].isReady)
        XCTAssertFalse(store.farm.plots[1].isGolden)
    }

    func test_rolledOnlyOncePerRipening() {
        script.values = [0.99, 0.99]
        ripenPlot1()
        let calls = script.calls
        store.tick(deltaTime: 1)
        store.tick(deltaTime: 1)
        XCTAssertEqual(script.calls, calls)
    }

    func test_alreadyRipeOnLoad_isNotRolled() {
        store.farm.plots[1].growth = 1
        store.tick(deltaTime: 1)
        XCTAssertFalse(store.farm.plots[1].isGolden)
    }

    // MARK: Harvest

    func test_manualHarvest_ofGoldenPlot_paysBonusAndYield() {
        store.farm.plots[1].growth = 1
        store.farm.plots[1].isGolden = true
        store.stall.warehouse = 0
        let coins = store.stall.coins
        let earned = store.progress.totalEarned

        let result = store.harvest(plotIndex: 1)

        XCTAssertEqual(result, GameStore.HarvestResult(isGolden: true, bonusCoins: 15 * 30))
        XCTAssertEqual(store.stall.coins, coins + 450, accuracy: 1e-9)
        XCTAssertEqual(store.progress.totalEarned, earned + 450, accuracy: 1e-9)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield)
        XCTAssertFalse(store.farm.plots[1].isGolden)
        XCTAssertEqual(store.progress.totalGoldenHarvested, 1)
    }

    func test_goldenBonus_usesBestUnlockedMenuLocationCashierAndPrestige() {
        store.stall.menuTier = 2
        store.stall.locationTier = 1
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.progress.prestigeCount = 2
        store.farm.plots[1].growth = 1
        store.farm.plots[1].isGolden = true
        store.stall.warehouse = 0

        let expected = 15 * EarningsSystem.salePrice(for: store.stall, menuIndex: 2, prestigeCount: 2)
        XCTAssertEqual(store.harvest(plotIndex: 1)?.bonusCoins ?? 0, expected, accuracy: 1e-9)
    }

    func test_manualHarvest_ofNormalPlot_hasNoBonus() {
        store.farm.plots[1].growth = 1
        store.stall.warehouse = 0
        XCTAssertEqual(store.harvest(plotIndex: 1), GameStore.HarvestResult(isGolden: false, bonusCoins: 0))
        XCTAssertEqual(store.progress.totalGoldenHarvested, 0)
    }

    func test_fullWarehouse_blocksHarvest_andKeepsTheGoldenFlag() {
        store.farm.plots[1].growth = 1
        store.farm.plots[1].isGolden = true
        store.stall.warehouse = store.stall.warehouseCapacity
        XCTAssertNil(store.harvest(plotIndex: 1))
        XCTAssertTrue(store.farm.plots[1].isGolden)
    }

    func test_notRipe_returnsNil() {
        store.farm.plots[1].growth = 0.5
        XCTAssertNil(store.harvest(plotIndex: 1))
    }

    func test_workerHarvest_clearsGolden_andPaysNothingExtra() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 1
        store.farm.plots[0].isGolden = true
        store.stall.warehouse = 0
        store.stall.coins = 0   // blocks the replant so coins stay observable
        store.tick(deltaTime: 0.1)
        XCTAssertTrue(store.farm.plots[0].isGolden, "the player's window: the worker waits")
        store.tick(deltaTime: GameStore.goldenWorkerGraceSeconds)
        XCTAssertFalse(store.farm.plots[0].isGolden)
        XCTAssertEqual(store.stall.coins, 0)
        XCTAssertEqual(store.stall.warehouse, FarmSystem.harvestYield)
        XCTAssertEqual(store.progress.totalGoldenHarvested, 0)
    }

    func test_planting_clearsGolden() {
        store.farm.plots[1].isPlanted = false
        store.farm.plots[1].isGolden = true
        store.stall.coins = 100
        store.plantSeed(plotIndex: 1)
        XCTAssertFalse(store.farm.plots[1].isGolden)
    }

    // MARK: Gourmet

    func test_rollGourmet_eightPercent() {
        script.values = [0.079, 0.08]
        XCTAssertTrue(store.rollGourmet())
        XCTAssertFalse(store.rollGourmet())
    }

    func test_rollGourmet_needsRatingThree_andConsumesNoRoll() {
        store.progress.rating = 2.94
        script.values = [0.0]
        XCTAssertFalse(store.rollGourmet())
        XCTAssertEqual(script.calls, 0)
        store.progress.rating = 3.0
        XCTAssertTrue(store.rollGourmet())
    }

    func test_rollGourmet_usesTheRatingTheHUDShows() {
        store.progress.rating = 2.96   // the HUD prints 3.0
        script.values = [0.0]
        XCTAssertTrue(store.rollGourmet())
    }

    func test_gourmetSale_paysTriple() {
        store.stall.menuStock[0] = 3
        XCTAssertEqual(store.sellItem(menuIndex: 0, isGourmet: true) ?? 0, 90, accuracy: 1e-9)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 1e-9)
    }

    func test_price_composesEveryMultiplier() {
        store.stall.menuTier = 1
        store.stall.locationTier = 1
        store.stall.cashierCount = 1
        store.stall.cashierTier = 1
        store.stall.menuStock[1] = 3
        store.progress.prestigeCount = 3
        chargeFever()
        store.startFever()

        let base = EarningsSystem.salePrice(for: store.stall, menuIndex: 1, prestigeCount: 3)
        XCTAssertEqual(base, 30 * 2.5 * UpgradeDefinitions.location[1].saleMultiplier
                       * 1.25 * PrestigeSystem.legacyMultiplier(prestigeCount: 3), accuracy: 1e-9)
        XCTAssertEqual(store.sellItem(menuIndex: 1, isGourmet: true) ?? 0, base * FeverSystem.priceMultiplier * EarningsSystem.gourmetMultiplier, accuracy: 1e-9)
    }

    func test_salePrice_feverMultiplier_isTrailingAndDefaultsToOne() {
        let plain = EarningsSystem.salePrice(for: store.stall, menuIndex: 0, prestigeCount: 0)
        XCTAssertEqual(EarningsSystem.salePrice(for: store.stall, menuIndex: 0, prestigeCount: 0, feverMultiplier: 2), plain * 2)
    }

    func test_gourmetServed_doublesRatingGain_andCounts() {
        store.progress.rating = 3.0
        store.recordServed(waitTime: 1, isGourmet: true)
        XCTAssertEqual(store.progress.rating, 3.04, accuracy: 1e-9)
        XCTAssertEqual(store.progress.totalGourmetServed, 1)
        store.recordServed(waitTime: 5, isGourmet: true)
        XCTAssertEqual(store.progress.rating, 3.04 + 0.02 * (5 - 3.04) / 2, accuracy: 1e-9)
    }

    func test_gourmetFailed_doublesLoss_afterFirstSaleGrace() {
        store.progress.rating = 3.0
        store.recordFailed(isGourmet: true)
        XCTAssertEqual(store.progress.rating, 3.0, "grace until the first sale")
        store.recordServed(waitTime: 5)
        let before = store.progress.rating
        store.recordFailed(isGourmet: true)
        XCTAssertEqual(store.progress.rating, before - 0.10, accuracy: 1e-9)
        store.recordFailed()
        XCTAssertEqual(store.progress.rating, before - 0.15, accuracy: 1e-9)
    }
}
