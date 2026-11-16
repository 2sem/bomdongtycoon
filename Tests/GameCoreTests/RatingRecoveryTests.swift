import XCTest
@testable import GameCore

@MainActor
final class RatingRecoveryTests: DotWorldTestCase {

    func test_decay_doesNotAct_atOrBelowThree() {
        for rating in [1.0, 2.4, 3.0] {
            store.progress.rating = rating
            store.tick(deltaTime: 1_000)
            XCTAssertEqual(store.progress.rating, rating, accuracy: 1e-9)
        }
    }

    func test_decay_fromAboveThree_stopsAtThree() {
        store.progress.rating = 3.02
        store.tick(deltaTime: 1_000)
        XCTAssertEqual(store.progress.rating, 3.0, accuracy: 1e-9)
    }

    func test_decay_aboveThree_unchanged() {
        store.progress.rating = 5.0
        store.tick(deltaTime: 100)
        XCTAssertEqual(store.progress.rating, 4.85, accuracy: 1e-9)
    }

    func test_comebackGain_isTripleAtOne() {
        store.progress.rating = 1.0
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 1.0 + 0.02 * 3, accuracy: 1e-9)
    }

    func test_comebackGain_unchangedAtThreeAndAbove() {
        store.progress.rating = 3.0
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 3.02, accuracy: 1e-9)
        store.progress.rating = 4.0
        store.recordServed(waitTime: 1)
        XCTAssertEqual(store.progress.rating, 4.01, accuracy: 1e-9)
    }

    func test_slowServeAtOne_nowRaisesRating_afterDecayGap() {
        store.progress.rating = 1.0
        store.tick(deltaTime: 20)   // one customer gap at 1.0
        store.recordServed(waitTime: 5)
        XCTAssertGreaterThan(store.progress.rating, 1.0)
    }
}
