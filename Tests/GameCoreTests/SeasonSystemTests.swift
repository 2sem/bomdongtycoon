import XCTest
@testable import GameCore

final class SeasonSystemTests: XCTestCase {

    func test_season_springFirst30Days() {
        let state = SeasonSystem.currentState(seasonStart: Date())
        XCTAssertEqual(state.currentSeason, .spring)
        XCTAssertEqual(state.daysRemaining, 30)
    }

    func test_season_transitionsToSummerAfter30Days() {
        let thirtyOneDaysAgo = Date().addingTimeInterval(-31 * 86400)
        let state = SeasonSystem.currentState(seasonStart: thirtyOneDaysAgo)
        XCTAssertEqual(state.currentSeason, .summer)
    }

    func test_springMultiplier_isOne() {
        XCTAssertEqual(SeasonSystem.earningsMultiplier(for: .spring), 1.0)
    }

    func test_summerMultiplier_hasBomDongBonus() {
        XCTAssertGreaterThan(SeasonSystem.earningsMultiplier(for: .summer), 1.0)
    }
}
