import XCTest
@testable import GameCore

final class AdLoadPolicyTests: XCTestCase {
    func test_retryDelay_doublesFromTwoSecondsAndCapsAtSixtyFour() {
        let delays = (1...9).map { AdLoadPolicy.retryDelay(afterFailures: $0) }
        XCTAssertEqual(delays, [2, 4, 8, 16, 32, 64, 64, 64, 64])
    }

    func test_retryDelay_hugeFailureCountStaysCapped() {
        XCTAssertEqual(AdLoadPolicy.retryDelay(afterFailures: 10_000), 64)
        XCTAssertEqual(AdLoadPolicy.retryDelay(afterFailures: 0), 2)
    }

    func test_lifetimes_sitInsideAdMobsOwn() {
        XCTAssertEqual(AdLoadPolicy.rewardedLifetime, 55 * 60)
        XCTAssertEqual(AdLoadPolicy.appOpenLifetime, 3 * 3600 + 55 * 60)
    }

    func test_expiry_isInclusiveAtTheLifetime() {
        let loaded = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(AdLoadPolicy.isRewardedExpired(loadedAt: loaded, now: loaded.addingTimeInterval(55 * 60 - 1)))
        XCTAssertTrue(AdLoadPolicy.isRewardedExpired(loadedAt: loaded, now: loaded.addingTimeInterval(55 * 60)))
        XCTAssertFalse(AdLoadPolicy.isAppOpenExpired(loadedAt: loaded, now: loaded.addingTimeInterval(3 * 3600 + 55 * 60 - 1)))
        XCTAssertTrue(AdLoadPolicy.isAppOpenExpired(loadedAt: loaded, now: loaded.addingTimeInterval(3 * 3600 + 55 * 60)))
    }
}
