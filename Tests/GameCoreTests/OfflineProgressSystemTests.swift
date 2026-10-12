import XCTest
@testable import GameCore

final class OfflineProgressSystemTests: XCTestCase {

    // coinsPerSecond is 0 until a cook is assigned, so every stall here has a tier-1 cook
    // on slot 0: 2.0 items/s x 30.0 coins/item = 60.0 coins/s.
    private static let cookedStallRate = 60.0

    private func cookedStall() -> StallState {
        var stall = StallState()
        stall.menuCooks = [1, 0, 0]
        return stall
    }

    func test_offlineEarnings_twoHours() {
        let stall = cookedStall()
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twoHoursAgo
        )
        XCTAssertEqual(earnings, Self.cookedStallRate * 2 * 3600, accuracy: 1)
    }

    func test_offlineEarnings_cappedAt8Hours() {
        let stall = cookedStall()
        let twentyHoursAgo = Date().addingTimeInterval(-20 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twentyHoursAgo
        )
        XCTAssertEqual(earnings, Self.cookedStallRate * 8 * 3600, accuracy: 1)
    }

    func test_offlineEarnings_firstLaunch_returnsZero() {
        let stall = StallState()
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: nil
        )
        XCTAssertEqual(earnings, 0)
    }

    func test_offlineEarnings_noCook_returnsZero() {
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: StallState(),
            lastActiveDate: Date().addingTimeInterval(-3600)
        )
        XCTAssertEqual(earnings, 0)
    }

    func test_offlineEarnings_withMultiplier() {
        let stall = cookedStall()
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: oneHourAgo,
            multiplier: 2.0
        )
        XCTAssertEqual(earnings, Self.cookedStallRate * 3600 * 2.0, accuracy: 1)
    }

    func test_offlineEarnings_withSeasonMultiplier() {
        let stall = cookedStall()
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: oneHourAgo,
            seasonMultiplier: 1.5
        )
        XCTAssertEqual(earnings, Self.cookedStallRate * 3600 * 1.5, accuracy: 1)
    }
}
