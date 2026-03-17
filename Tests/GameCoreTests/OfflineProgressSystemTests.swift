import XCTest
@testable import GameCore

final class OfflineProgressSystemTests: XCTestCase {

    // Base coinsPerSecond = 30.0 (1.0 items/s × 30.0 coins/item)

    func test_offlineEarnings_twoHours() {
        let stall = StallState()
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twoHoursAgo
        )
        XCTAssertEqual(earnings, 30.0 * 2 * 3600, accuracy: 1)
    }

    func test_offlineEarnings_cappedAt8Hours() {
        let stall = StallState()
        let twentyHoursAgo = Date().addingTimeInterval(-20 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twentyHoursAgo
        )
        XCTAssertEqual(earnings, 30.0 * 8 * 3600, accuracy: 1)
    }

    func test_offlineEarnings_firstLaunch_returnsZero() {
        let stall = StallState()
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: nil
        )
        XCTAssertEqual(earnings, 0)
    }

    func test_offlineEarnings_withMultiplier() {
        let stall = StallState()
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: oneHourAgo,
            multiplier: 2.0
        )
        XCTAssertEqual(earnings, 30.0 * 3600 * 2.0, accuracy: 1)
    }

    func test_offlineEarnings_withSeasonMultiplier() {
        let stall = StallState()
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: oneHourAgo,
            seasonMultiplier: 1.5
        )
        XCTAssertEqual(earnings, 30.0 * 3600 * 1.5, accuracy: 1)
    }
}
