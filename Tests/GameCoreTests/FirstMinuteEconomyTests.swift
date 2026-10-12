import XCTest
@testable import GameCore

@MainActor
final class FirstMinuteEconomyTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "FirstMinuteEconomyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = GameStore(defaults: defaults)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        try await super.tearDown()
    }

    // MARK: - Pause

    func test_tick_whilePaused_changesNothing() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = false
        let coins = store.stall.coins
        let rating = store.progress.rating
        let growth = store.farm.plots[0].growth

        store.isSimulationPaused = true
        for _ in 0..<120 { store.tick(deltaTime: 1.0) }

        XCTAssertEqual(store.stall.coins, coins, accuracy: 0.001)
        XCTAssertEqual(store.progress.rating, rating, accuracy: 0.0001)
        XCTAssertEqual(store.farm.plots[0].growth, growth, accuracy: 0.0001)
        XCTAssertFalse(store.farm.plots[0].isPlanted)
    }

    func test_tick_afterResume_runsAgain() {
        store.isSimulationPaused = true
        store.tick(deltaTime: 1.0)
        store.isSimulationPaused = false
        let rating = store.progress.rating
        store.tick(deltaTime: 10.0)
        XCTAssertLessThan(store.progress.rating, rating)
    }

    func test_offlineEarnings_notComputedWhilePausedOrBeforeIntroDone() {
        store.progress.isFirstLaunch = false
        store.progress.isShopNameSet = true
        store.progress.earningRate = 1
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)

        store.isSimulationPaused = true
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 0)

        store.isSimulationPaused = false
        store.progress.isShopNameSet = false
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.calculateOfflineEarnings()
        XCTAssertEqual(store.offlineEarnings, 0)

        store.progress.isShopNameSet = true
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.calculateOfflineEarnings()
        XCTAssertGreaterThan(store.offlineEarnings, 0)
    }

    func test_resume_restartsOfflineClock() throws {
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.isSimulationPaused = true
        store.isSimulationPaused = false
        let last = try XCTUnwrap(store.progress.lastActiveDate)
        XCTAssertLessThan(Date().timeIntervalSince(last), 5)
    }

    // MARK: - Replant floor

    func test_autoReplant_idleNeverDrainsBelowOneSeed() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[1].workerType = .alba
        store.stall.coins = 50
        for _ in 0..<500 { store.tick(deltaTime: 1.0) }
        XCTAssertGreaterThanOrEqual(store.stall.coins, FarmSystem.seedCost)
    }

    func test_autoReplant_plantsWhenOneSeedRemainsAfterwards() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = false
        store.stall.coins = FarmSystem.seedCost * 2
        store.tick(deltaTime: 0.1)
        XCTAssertTrue(store.farm.plots[0].isPlanted)
        XCTAssertEqual(store.stall.coins, FarmSystem.seedCost, accuracy: 0.001)
    }

    func test_autoReplant_belowReserve_doesNotPlant() {
        store.farm.plots[0].workerType = .alba
        store.farm.plots[0].isPlanted = false
        store.stall.coins = FarmSystem.seedCost * 2 - 1
        store.tick(deltaTime: 0.1)
        XCTAssertFalse(store.farm.plots[0].isPlanted)
    }

    func test_manualPlant_unaffectedByReserve() {
        store.farm.plots[0].isPlanted = false
        store.stall.coins = FarmSystem.seedCost
        store.plantSeed(plotIndex: 0)
        XCTAssertTrue(store.farm.plots[0].isPlanted)
        XCTAssertEqual(store.stall.coins, 0, accuracy: 0.001)
    }

    // MARK: - First failures

    func test_recordFailed_beforeFirstSale_keepsRating() {
        let rating = store.progress.rating
        store.recordFailed()
        store.recordFailed()
        XCTAssertEqual(store.progress.rating, rating, accuracy: 0.0001)
        XCTAssertEqual(store.progress.totalFailed, 2)
    }

    func test_recordFailed_afterFirstSale_penalisesRating() {
        store.recordServed(waitTime: 0)
        let rating = store.progress.rating
        store.recordFailed()
        XCTAssertEqual(store.progress.rating, rating - 0.05, accuracy: 0.0001)
    }

    // MARK: - Save compatibility

    func test_oldSave_loadsAndBehavesNormally() {
        let json = """
        {"isFirstLaunch":false,"isShopNameSet":true,"shopName":"x","totalEarned":5,\
        "earningRate":0,"rating":4.0,"totalServed":3,"totalFailed":1}
        """
        defaults.set(Data(json.utf8), forKey: "gameStore.progress")
        let loaded = GameStore(defaults: defaults)
        XCTAssertFalse(loaded.isSimulationPaused)
        XCTAssertEqual(loaded.progress.rating, 4.0, accuracy: 0.0001)
        loaded.recordFailed()
        XCTAssertEqual(loaded.progress.rating, 3.95, accuracy: 0.0001)
    }
}
