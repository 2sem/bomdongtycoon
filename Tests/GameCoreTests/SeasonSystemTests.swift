import XCTest
@testable import GameCore

final class SeasonSystemTests: XCTestCase {

    func test_season_springFirst30Days() {
        let now = Date()
        let state = SeasonSystem.currentState(seasonStart: now, now: now)
        XCTAssertEqual(state.currentSeason, .spring)
        XCTAssertEqual(state.daysRemaining, 30)
    }

    func test_season_transitionsToSummerAfter30Days() {
        let now = Date()
        let thirtyOneDaysAgo = now.addingTimeInterval(-31 * 86400)
        let state = SeasonSystem.currentState(seasonStart: thirtyOneDaysAgo, now: now)
        XCTAssertEqual(state.currentSeason, .summer)
    }

    func test_springMultiplier_isOne() {
        XCTAssertEqual(SeasonSystem.earningsMultiplier(for: .spring), 1.0)
    }

    func test_summerMultiplier_hasBomDongBonus() {
        XCTAssertGreaterThan(SeasonSystem.earningsMultiplier(for: .summer), 1.0)
    }
}
