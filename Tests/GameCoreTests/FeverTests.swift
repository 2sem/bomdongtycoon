import XCTest
@testable import GameCore

@MainActor
final class FeverTests: DotWorldTestCase {

    /// From rating 4.0 the pace-sized charge falls to its floor of a thirty-sixth.
    override func setUp() async throws {
        try await super.setUp()
        store.progress.rating = 4.6
    }

    func test_serve_adds_a_thirtysixth() {
        store.recordServed(waitTime: 5)
        XCTAssertEqual(store.feverCharge, 1.0 / 36, accuracy: 1e-9)
    }

    func test_fastServe_adds_one_and_a_half_times() {
        store.recordServed(waitTime: 1.9)
        XCTAssertEqual(store.feverCharge, 1.5 / 36, accuracy: 1e-9)
        store.recordServed(waitTime: 2.0)   // exactly 2 s is not fast
        XCTAssertEqual(store.feverCharge, 2.5 / 36, accuracy: 1e-9)
    }

    func test_thirtySixServes_isReady_andChargeClampsAtOne() {
        serve(35)
        XCTAssertFalse(store.isFeverReady)
        serve(1)
        XCTAssertTrue(store.isFeverReady)
        serve(5)
        XCTAssertEqual(store.feverCharge, 1, accuracy: 1e-9)
    }

    func test_noDecay_untilSixSeconds() {
        serve(18)
        store.tick(deltaTime: 5.9)
        XCTAssertEqual(store.feverCharge, 0.5, accuracy: 1e-9)
    }

    func test_decay_startsAfterSixSeconds_atOneSixtiethPerSecond() {
        serve(18)
        store.tick(deltaTime: 6)
        XCTAssertEqual(store.feverCharge, 0.5, accuracy: 1e-9)
        store.tick(deltaTime: 6)
        XCTAssertEqual(store.feverCharge, 0.5 - 6.0 / 60, accuracy: 1e-9)
    }

    func test_decay_withinOneTick_onlyCountsTimePastTheDelay() {
        serve(18)
        store.tick(deltaTime: 16)   // 10 s of decay
        XCTAssertEqual(store.feverCharge, 0.5 - 10.0 / 60, accuracy: 1e-9)
    }

    func test_aSale_restartsTheDecayDelay() {
        serve(18)
        store.tick(deltaTime: 5)
        store.recordServed(waitTime: 5)
        store.tick(deltaTime: 5)
        XCTAssertEqual(store.feverCharge, 19.0 / 36, accuracy: 1e-9)
    }

    func test_chargeNeverGoesNegative() {
        serve(1)
        store.tick(deltaTime: 600)
        XCTAssertEqual(store.feverCharge, 0)
    }

    func test_startFever_needsFullCharge() {
        serve(35)
        XCTAssertFalse(store.startFever())
        XCTAssertFalse(store.isFeverActive)
        XCTAssertEqual(store.progress.totalFevers, 0)
    }

    func test_startFever_resetsCharge_runsFifteenSeconds_thenExpires() {
        chargeFever()
        XCTAssertTrue(store.startFever())
        XCTAssertTrue(store.isFeverActive)
        XCTAssertEqual(store.feverCharge, 0)
        XCTAssertEqual(store.feverRemaining, 15, accuracy: 1e-9)
        XCTAssertEqual(store.progress.totalFevers, 1)

        store.tick(deltaTime: 14.9)
        XCTAssertTrue(store.isFeverActive)
        store.tick(deltaTime: 0.2)
        XCTAssertFalse(store.isFeverActive)
        XCTAssertEqual(store.feverRemaining, 0)
    }

    func test_cannotStartWhileActive() {
        chargeFever()
        store.startFever()
        serve(36)
        XCTAssertEqual(store.feverCharge, 0, "no accumulation while active")
        XCTAssertFalse(store.startFever())
        XCTAssertEqual(store.progress.totalFevers, 1)
    }

    func test_accumulationResumesAfterExpiry() {
        chargeFever()
        store.startFever()
        store.tick(deltaTime: 15)
        store.recordServed(waitTime: 5)
        XCTAssertEqual(store.feverCharge, 1.0 / 36, accuracy: 1e-9)
    }

    func test_active_spawnsAtThirtyFivePercentOfTheInterval() {
        let base = store.customerSpawnInterval
        chargeFever()
        store.startFever()
        XCTAssertEqual(store.customerSpawnInterval, base * 0.35, accuracy: 1e-9)
        store.tick(deltaTime: 15)
        XCTAssertEqual(store.customerSpawnInterval, base, accuracy: 1e-9)
    }

    func test_active_doublesSalePrice() {
        store.stall.menuStock[0] = 5
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 1e-9)
        chargeFever()
        store.startFever()
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 60, accuracy: 1e-9)
    }

    func test_fever_isNotCountedInTheEarningWindow() {
        store.stall.menuStock[0] = 5
        chargeFever()
        store.startFever()
        _ = store.sellItem(menuIndex: 0)   // pays 60, base economy is 30
        // The EMA is fed from the window on the 5 s save; one 5 s window with one base sale.
        store.progress.earningRate = 0
        store.tick(deltaTime: 5)
        XCTAssertEqual(store.progress.earningRate, 30.0 / 5.0, accuracy: 1e-6)
    }

    func test_coinsPerSecond_ignoresFever() {
        store.stall.menuCooks[0] = 1
        let before = EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0)
        chargeFever()
        store.startFever()
        XCTAssertEqual(EarningsSystem.coinsPerSecond(for: store.stall, prestigeCount: 0), before)
    }

    func test_newRun_resetsFever() {
        chargeFever()
        store.startFever()
        prepareForPrestige()
        XCTAssertTrue(store.startNewRun())
        XCTAssertFalse(store.isFeverActive)
        XCTAssertEqual(store.feverCharge, 0)
        XCTAssertEqual(store.feverRemaining, 0)
        XCTAssertEqual(store.progress.totalFevers, 1, "lifetime stat is kept")
    }

    func test_feverSystem_isPure() {
        var state = FeverState()
        FeverSystem.recordServed(&state, waitTime: 0)
        XCTAssertEqual(state.charge, 1.5 / 36, accuracy: 1e-9)
        XCTAssertFalse(FeverSystem.start(&state))
    }
}

extension DotWorldTestCase {
    func prepareForPrestige() {
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        XCTAssertTrue(store.canStartNewRun)
    }
}
