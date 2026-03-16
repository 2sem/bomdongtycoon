import XCTest
@testable import GameCore

final class OfflineProgressSystemTests: XCTestCase {

    func test_offlineEarnings_twoHours() {
        let stall = StallState()
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twoHoursAgo
        )
        XCTAssertEqual(earnings, 7200, accuracy: 1)
    }

    func test_offlineEarnings_cappedAt8Hours() {
        let stall = StallState()
        let twentyHoursAgo = Date().addingTimeInterval(-20 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twentyHoursAgo
        )
        XCTAssertEqual(earnings, 1.0 * 8 * 3600, accuracy: 1)
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
        XCTAssertEqual(earnings, 7200, accuracy: 1)
    }
}
