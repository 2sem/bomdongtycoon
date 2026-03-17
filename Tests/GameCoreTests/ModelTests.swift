import XCTest
@testable import GameCore

final class ModelTests: XCTestCase {

    func test_stallState_defaultValues() {
        let stall = StallState()
        XCTAssertEqual(stall.coins, 0)
        XCTAssertEqual(stall.menuTier, 0)
        XCTAssertEqual(stall.staffTier, 0)
        XCTAssertEqual(stall.stallTier, 0)

        XCTAssertFalse(stall.autoCollectEnabled)
    }

    func test_stallState_codableRoundTrip() throws {
        var stall = StallState()
        stall.coins = 999
        stall.menuTier = 2
        let data = try JSONEncoder().encode(stall)
        let decoded = try JSONDecoder().decode(StallState.self, from: data)
        XCTAssertEqual(decoded.coins, 999)
        XCTAssertEqual(decoded.menuTier, 2)
    }

    func test_playerProgress_firstLaunch() {
        let progress = PlayerProgress()
        XCTAssertTrue(progress.isFirstLaunch)
        XCTAssertNil(progress.lastActiveDate)
    }

    func test_upgradeDefinition_staffFirstEntry() {
        let upgrade = UpgradeDefinitions.staff[0]
        XCTAssertEqual(upgrade.name, "알바생")
        XCTAssertEqual(upgrade.coinCost, 500)
        XCTAssertGreaterThan(upgrade.productionMultiplier, 1.0)
    }
}
