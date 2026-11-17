import XCTest
@testable import GameCore

@MainActor
final class RushPartTimerTests: DotWorldTestCase {

    private func maxedStall() {
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.coins = 1_000_000
    }

    private func quietShop(rating: Double = 1.5) {
        store.progress.rating = rating
        store.stall.menuTier = 1
        store.stall.coins = 1_000_000
    }

    private func run(_ seconds: Double, step: Double = 0.5) {
        for _ in 0..<Int(seconds / step) { store.tick(deltaTime: step) }
    }

    // MARK: Rush

    func test_renovation_liftsRatingToTheFloor_andStartsTheRush() {
        maxedStall()
        store.progress.rating = 1.4
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.stall.renovationLevel, 1)
        XCTAssertEqual(store.progress.rating, 3.0)
        XCTAssertTrue(store.isRushActive)
        XCTAssertEqual(store.rushRemaining, RushSystem.duration, accuracy: 1e-9)
        XCTAssertEqual(store.rushStarts, 1)
    }

    func test_renovation_neverLowersAHigherRating() {
        maxedStall()
        store.progress.rating = 4.2
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.progress.rating, 4.2)
    }

    func test_rush_runsOnPlayTime_andEnds() {
        maxedStall()
        store.purchaseUpgrade(.renovation)
        run(60)
        XCTAssertEqual(store.rushRemaining, 60, accuracy: 1e-6)
        run(60)
        XCTAssertFalse(store.isRushActive)
        XCTAssertEqual(store.rushRemaining, 0)
    }

    func test_rush_doesNotRunWhileTheAppIsInactive() {
        maxedStall()
        store.purchaseUpgrade(.renovation)
        store.isAppActive = false
        run(30)
        XCTAssertEqual(store.rushRemaining, RushSystem.duration, accuracy: 1e-9)
    }

    func test_rush_shortensTheSpawnInterval_andBuyingAgainRestartsItWithoutStacking() {
        maxedStall()
        store.progress.rating = 3.0
        let calm = store.customerSpawnInterval
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.customerSpawnInterval, calm * RushSystem.spawnIntervalMultiplier, accuracy: 1e-9)
        run(50)
        store.purchaseUpgrade(.renovation)
        XCTAssertEqual(store.rushRemaining, RushSystem.duration, accuracy: 1e-9)
        XCTAssertEqual(store.customerSpawnInterval, calm * RushSystem.spawnIntervalMultiplier, accuracy: 1e-9)
    }

    func test_rush_savesAndRestoresRemainingTime() {
        maxedStall()
        store.purchaseUpgrade(.renovation)
        run(45)
        store.recordServed(waitTime: 5)   // saves
        let loaded = makeStore()
        XCTAssertEqual(loaded.rushRemaining, 75, accuracy: 1e-6)
        XCTAssertTrue(loaded.isRushActive)
    }

    func test_rush_isClearedByANewSpring() {
        maxedStall()
        store.purchaseUpgrade(.renovation)
        store.hirePartTimer(payment: .ad)
        XCTAssertTrue(store.isRushActive)
        XCTAssertTrue(store.startNewRun())
        XCTAssertFalse(store.isRushActive)
        XCTAssertFalse(store.isPartTimerActive)
    }

    func test_oldSaveWithoutTheFields_loadsNoRushNoShift() {
        defaults.set(Data(#"{"totalServed":3}"#.utf8), forKey: GameStore.SaveBlob.progress.key)
        let loaded = makeStore()
        XCTAssertFalse(loaded.isRushActive)
        XCTAssertFalse(loaded.isPartTimerActive)
    }

    // MARK: Part-timer: eligibility, cost, one at a time, expiry

    func test_partTimer_offeredOnlyUnderThreeByTheDisplayedRating() {
        store.progress.rating = 2.9
        XCTAssertTrue(store.isPartTimerAvailable)
        store.progress.rating = 2.96   // the HUD prints 3.0
        XCTAssertFalse(store.isPartTimerAvailable)
        store.progress.rating = 4.0
        XCTAssertFalse(store.isPartTimerAvailable)
    }

    func test_partTimer_refusedWhenAShopIsDoingFine() {
        store.progress.rating = 3.5
        store.stall.coins = 1_000_000
        XCTAssertFalse(store.hirePartTimer(payment: .coins))
        XCTAssertFalse(store.hirePartTimer(payment: .ad))
        XCTAssertEqual(store.stall.coins, 1_000_000)
        XCTAssertFalse(store.isPartTimerActive)
    }

    func test_partTimer_costIsTenSalesOfTheBestDish_cleaned() {
        store.stall.menuTier = 2
        let best = EarningsSystem.salePrice(for: store.stall, menuIndex: 2, prestigeCount: 0)
        XCTAssertEqual(store.partTimerFee, Double(MissionSystem.cleanNumber(10 * best)))
        store.stall.menuTier = 0
        XCTAssertLessThan(store.partTimerFee, Double(MissionSystem.cleanNumber(10 * best)))
    }

    func test_partTimer_coinsPayTheFee_adPaysNothing() {
        quietShop()
        let fee = store.partTimerFee
        XCTAssertTrue(store.hirePartTimer(payment: .coins))
        XCTAssertEqual(store.stall.coins, 1_000_000 - fee, accuracy: 1e-6)
        XCTAssertEqual(store.partTimerRemaining, PartTimerSystem.shiftDuration, accuracy: 1e-9)
        XCTAssertEqual(store.partTimerHires, 1)

        store.progress.partTimerEndsAtPlaySeconds = nil
        let before = store.stall.coins
        XCTAssertTrue(store.hirePartTimer(payment: .ad))
        XCTAssertEqual(store.stall.coins, before)
    }

    func test_partTimer_unaffordableChangesNothing() {
        quietShop()
        store.stall.coins = store.partTimerFee - 1
        let coins = store.stall.coins
        XCTAssertFalse(store.hirePartTimer(payment: .coins))
        XCTAssertEqual(store.stall.coins, coins)
        XCTAssertFalse(store.isPartTimerActive)
    }

    func test_partTimer_oneAtATime() {
        quietShop()
        XCTAssertTrue(store.hirePartTimer(payment: .coins))
        let coins = store.stall.coins
        XCTAssertFalse(store.isPartTimerAvailable)
        XCTAssertFalse(store.hirePartTimer(payment: .coins))
        XCTAssertFalse(store.hirePartTimer(payment: .ad))
        XCTAssertEqual(store.stall.coins, coins)
        XCTAssertEqual(store.partTimerHires, 1)
    }

    func test_partTimer_shiftExpiresAfterThreeMinutes_thenCanBeHiredAgain() {
        quietShop()
        store.hirePartTimer(payment: .ad)
        run(179)
        XCTAssertTrue(store.isPartTimerActive)
        run(2)
        XCTAssertFalse(store.isPartTimerActive)
        XCTAssertTrue(store.isPartTimerAvailable)
    }

    func test_partTimer_keepsWorkingWhenTheRatingPassesThree() {
        quietShop(rating: 2.9)
        store.hirePartTimer(payment: .ad)
        store.progress.rating = 3.2
        XCTAssertTrue(store.isPartTimerActive)
        XCTAssertFalse(store.isPartTimerAvailable)
    }

    func test_partTimer_savesAndRestoresTheShift() {
        quietShop()
        store.hirePartTimer(payment: .ad)
        run(20)
        store.recordServed(waitTime: 5)   // saves
        let loaded = makeStore()
        XCTAssertEqual(loaded.partTimerRemaining, store.partTimerRemaining, accuracy: 1e-6)
        XCTAssertTrue(loaded.isPartTimerActive)
    }

    func test_partTimer_speedsUpASparseShop_butNotPastTheThreePointZeroPace() {
        quietShop(rating: 1.2)   // 20 s
        XCTAssertEqual(store.customerSpawnInterval, 20)
        store.hirePartTimer(payment: .ad)
        XCTAssertEqual(store.customerSpawnInterval, 10, accuracy: 1e-9)
        store.progress.partTimerEndsAtPlaySeconds = nil
        store.progress.rating = 2.7   // 8 s: x0.5 = 4 s, held at the 5 s three-star pace
        store.hirePartTimer(payment: .ad)
        XCTAssertEqual(store.customerSpawnInterval, 5, accuracy: 1e-9)
    }

    // MARK: Stacking

    private func pace(base: Double = 16, fever: Bool = false, rush: Bool = false, partTimer: Bool = false) -> Double {
        SpawnPaceSystem.interval(base: base, floor: 5, feverActive: fever, rushActive: rush, partTimerActive: partTimer)
    }

    func test_stacking_noBoostLeavesTheBase() {
        XCTAssertEqual(pace(), 16)
    }

    func test_stacking_eachAloneUsesItsOwnMultiplier() {
        XCTAssertEqual(pace(fever: true), 16 * 0.35, accuracy: 1e-9)
        XCTAssertEqual(pace(rush: true), 16 * 0.6, accuracy: 1e-9)
        XCTAssertEqual(pace(partTimer: true), 16 * 0.5, accuracy: 1e-9)
    }

    func test_stacking_strongestWins_neverMultiplied() {
        XCTAssertEqual(pace(fever: true, rush: true, partTimer: true), 16 * 0.35, accuracy: 1e-9)
        XCTAssertEqual(pace(rush: true, partTimer: true), 16 * 0.5, accuracy: 1e-9)
        XCTAssertEqual(pace(fever: true, partTimer: true), 16 * 0.35, accuracy: 1e-9)
        XCTAssertGreaterThan(pace(fever: true, rush: true), 16 * 0.35 * 0.6)
    }

    func test_stacking_partTimerFloorsAtTheThreePointZeroPace_andNeverSlowsAFastShop() {
        XCTAssertEqual(pace(base: 6, partTimer: true), 5, accuracy: 1e-9)   // 3 -> 5
        XCTAssertEqual(pace(base: 3.5, partTimer: true), 3.5, accuracy: 1e-9)   // already faster
    }

    func test_stacking_inTheStore_feverBeatsARunningRushAndShift() {
        chargeFever()
        quietShop(rating: 2.0)
        store.hirePartTimer(payment: .ad)
        store.progress.rushEndsAtPlaySeconds = store.progress.totalPlaySeconds + 100
        XCTAssertEqual(store.customerSpawnInterval, 12 * 0.5, accuracy: 1e-9)
        store.startFever()
        XCTAssertEqual(store.customerSpawnInterval, 12 * 0.35, accuracy: 1e-9)
    }
}
