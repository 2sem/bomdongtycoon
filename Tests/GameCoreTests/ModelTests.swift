import XCTest
@testable import GameCore

final class ModelTests: XCTestCase {

    func test_stallState_defaultValues() {
        let stall = StallState()
        XCTAssertEqual(stall.coins, 50)  // starting purse
        XCTAssertEqual(stall.tier1Count, 1)  // starts with one 알바생
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

    // MARK: - FarmPlot.stage

    private func plot(planted: Bool, growth: Double) -> FarmPlot {
        var plot = FarmPlot()
        plot.isPlanted = planted
        plot.growth = growth
        return plot
    }

    func test_plotStage_unplantedIsEmptyWhateverTheGrowth() {
        XCTAssertEqual(plot(planted: false, growth: 0).stage, .empty)
        XCTAssertEqual(plot(planted: false, growth: 0.5).stage, .empty)
        XCTAssertEqual(plot(planted: false, growth: 1.0).stage, .empty)
    }

    func test_plotStage_sproutUpToButExcludingThreshold() {
        XCTAssertEqual(plot(planted: true, growth: 0).stage, .sprout)
        XCTAssertEqual(plot(planted: true, growth: 0.3499).stage, .sprout)
    }

    func test_plotStage_growingFromThresholdUpToButExcludingFull() {
        XCTAssertEqual(plot(planted: true, growth: 0.35).stage, .growing)
        XCTAssertEqual(plot(planted: true, growth: 0.9999).stage, .growing)
    }

    func test_plotStage_readyAtFullGrowth() {
        XCTAssertEqual(plot(planted: true, growth: 1.0).stage, .ready)
        XCTAssertEqual(plot(planted: true, growth: 1.2).stage, .ready)
    }

    func test_plotStage_readyAgreesWithIsReady() {
        for growth in stride(from: 0.0, through: 1.0, by: 0.05) {
            let sample = plot(planted: true, growth: growth)
            XCTAssertEqual(sample.stage == .ready, sample.isReady, "growth \(growth)")
        }
    }

    func test_upgradeDefinition_staffFirstEntry() {
        let upgrade = UpgradeDefinitions.staff[0]
        XCTAssertEqual(upgrade.name, "알바생")
        XCTAssertEqual(upgrade.coinCost, 500)
        XCTAssertGreaterThan(upgrade.productionMultiplier, 1.0)
    }
}
