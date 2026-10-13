import XCTest
@testable import GameCore

@MainActor
final class LocationTierTests: XCTestCase {

    private var suiteName: String!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "LocationTierTests.\(UUID().uuidString)"
        store = GameStore(defaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        try await super.tearDown()
    }

    // MARK: Save compatibility

    func test_oldSaveWithoutLocationTier_decodesAsZero() throws {
        let json = #"{"coins": 123, "menuTier": 1, "staffTier": 0, "stallTier": 1, "pendingCoins": 0}"#
        let decoded = try JSONDecoder().decode(StallState.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.locationTier, 0)
        XCTAssertEqual(decoded.stallTier, 1)
        XCTAssertEqual(decoded.coins, 123)
    }

    func test_locationTier_roundTrips() throws {
        var state = StallState()
        state.locationTier = 2
        let decoded = try JSONDecoder().decode(StallState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.locationTier, 2)
    }

    func test_invalidLocationTier_isClampedOnLoad() throws {
        let high = try JSONDecoder().decode(StallState.self, from: Data(#"{"locationTier": 9}"#.utf8))
        let low = try JSONDecoder().decode(StallState.self, from: Data(#"{"locationTier": -3}"#.utf8))
        XCTAssertEqual(high.locationTier, 2)
        XCTAssertEqual(low.locationTier, 0)
    }

    // MARK: Multiplier

    func test_multiplier_scalesPricePerItem() {
        var stall = StallState()
        let base = EarningsSystem.pricePerItem(for: stall, menuIndex: 0)
        stall.locationTier = 1
        XCTAssertEqual(EarningsSystem.pricePerItem(for: stall, menuIndex: 0), base * 2, accuracy: 0.001)
        stall.locationTier = 2
        XCTAssertEqual(EarningsSystem.pricePerItem(for: stall, menuIndex: 0), base * 4, accuracy: 0.001)
        XCTAssertEqual(EarningsSystem.pricePerItem(for: stall), base * 4, accuracy: 0.001)
    }

    func test_multiplier_appliesToLiveSale() {
        store.stall.locationTier = 2
        store.stall.menuStock[0] = 1
        let price = store.sellItem(menuIndex: 0)
        XCTAssertEqual(price ?? 0, 30 * 4, accuracy: 0.001)
    }

    // MARK: Purchase guards

    func test_purchase_succeedsWithPrerequisiteAndCoins() {
        store.stall.stallTier = 1
        store.stall.coins = 40_000
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 1)
        XCTAssertEqual(store.stall.coins, 0, accuracy: 0.001)
    }

    func test_purchase_rejectedWithInsufficientCoins() {
        store.stall.stallTier = 1
        store.stall.coins = 39_999
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 0)
        XCTAssertEqual(store.stall.coins, 39_999, accuracy: 0.001)
    }

    func test_purchase_rejectedWithoutStallPrerequisite() {
        store.stall.stallTier = 0
        store.stall.coins = 1_000_000
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 0)
        XCTAssertEqual(store.stall.coins, 1_000_000, accuracy: 0.001)
    }

    func test_purchase_gangnamNeedsStallTierTwo() {
        store.stall.locationTier = 1
        store.stall.stallTier = 1
        store.stall.coins = 200_000
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 1)
        store.stall.stallTier = 2
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 2)
    }

    func test_purchase_rejectedWhenAlreadyAtMax() {
        store.stall.locationTier = 2
        store.stall.stallTier = 2
        store.stall.coins = 1_000_000
        store.purchaseUpgrade(.location)
        XCTAssertEqual(store.stall.locationTier, 2)
        XCTAssertEqual(store.stall.coins, 1_000_000, accuracy: 0.001)
    }

    // MARK: Goal

    func test_location_isNotGoalUntilStallPrerequisiteMet() {
        var stall = StallState()
        stall.stallTier = 0
        XCTAssertFalse(EarningsSystem.nextLocationUnlocked(for: stall))
        stall.stallTier = 1
        XCTAssertTrue(EarningsSystem.nextLocationUnlocked(for: stall))
    }
}
