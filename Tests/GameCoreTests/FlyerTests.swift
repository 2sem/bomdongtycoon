import XCTest
@testable import GameCore

@MainActor
final class FlyerTests: DotWorldTestCase {

    func test_unavailable_atThreeAndAbove() {
        for rating in [3.0, 3.01, 4.2] {
            store.progress.rating = rating
            XCTAssertFalse(store.isFlyerAvailable)
            XCTAssertFalse(store.requestFlyer())
        }
    }

    func test_availability_followsTheDisplayedRating() {
        store.progress.rating = 2.96   // the HUD prints 3.0
        XCTAssertFalse(store.isFlyerAvailable)
        store.progress.rating = 2.94
        XCTAssertTrue(store.isFlyerAvailable)
    }

    func test_availableBelowThree_andAcceptsATap() {
        store.progress.rating = 2.0
        XCTAssertTrue(store.isFlyerReady)
        XCTAssertTrue(store.requestFlyer())
        XCTAssertTrue(store.hasFlyerRequest)
    }

    func test_cooldown_isTheThreePointZeroSpawnInterval() {
        XCTAssertEqual(GameStore.flyerCooldown, 5)
        store.progress.rating = 3.0
        XCTAssertEqual(store.customerSpawnInterval, GameStore.flyerCooldown)
    }

    func test_cooldown_enforcedAfterASpawn_andRunsOnTheSimulationClock() {
        store.progress.rating = 2.0
        XCTAssertTrue(store.requestFlyer())
        store.completeFlyer()
        XCTAssertFalse(store.hasFlyerRequest)
        XCTAssertFalse(store.requestFlyer())
        XCTAssertEqual(store.flyerCooldownProgress, 0, accuracy: 1e-9)
        store.tick(deltaTime: 4.9)
        XCTAssertFalse(store.requestFlyer())
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(store.flyerCooldownProgress, 1, accuracy: 1e-9)
        XCTAssertTrue(store.requestFlyer())
    }

    func test_refusedTap_doesNotStartTheCooldown() {
        store.progress.rating = 2.0
        XCTAssertTrue(store.requestFlyer())
        store.declineFlyer()
        XCTAssertFalse(store.hasFlyerRequest)
        XCTAssertEqual(store.flyerCooldownRemaining, 0)
        XCTAssertTrue(store.requestFlyer())
    }

    func test_pendingTap_isNotTakenTwice() {
        store.progress.rating = 2.0
        XCTAssertTrue(store.requestFlyer())
        XCTAssertFalse(store.requestFlyer())
    }

    func test_pausedSimulation_refusesTaps_andFreezesTheCooldown() {
        store.progress.rating = 2.0
        store.requestFlyer()
        store.completeFlyer()
        store.isSimulationPaused = true
        store.tick(deltaTime: 60)
        XCTAssertEqual(store.flyerCooldownRemaining, 5, accuracy: 1e-9)
        store.isSimulationPaused = false
        store.declineFlyer()
        store.progress.rating = 2.0
        store.isSimulationPaused = true
        XCTAssertFalse(store.requestFlyer())
    }

    func test_newRun_clearsTheCooldown() {
        store.progress.rating = 2.0
        store.requestFlyer()
        store.completeFlyer()
        XCTAssertGreaterThan(store.flyerCooldownRemaining, 0)
        store.stall.locationTier = 2
        store.stall.stallTier = 2
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.flyerCooldownRemaining, 0)
        XCTAssertFalse(store.hasFlyerRequest)
    }
}
