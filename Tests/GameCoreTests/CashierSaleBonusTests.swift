import XCTest
@testable import GameCore

@MainActor
final class CashierSaleBonusTests: XCTestCase {

    private var suiteName: String!
    private var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "CashierSaleBonusTests.\(UUID().uuidString)"
        store = GameStore(defaults: UserDefaults(suiteName: suiteName)!)
        store.farm.plots[0].workerType = .none
        store.stall.menuStock[0] = 100
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        try await super.tearDown()
    }

    private func hireCashier(tier: Int = 1, energy: Double = 1.0) {
        store.stall.cashierCount = 1
        store.stall.cashierTier = tier
        store.stall.cashierEnergy = energy
    }

    // MARK: Sale price

    func test_noCashier_paysBasePrice() {
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.001)
    }

    func test_cashier_addsQuarter() {
        hireCashier()
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.25, accuracy: 0.001)
    }

    func test_tiredCashier_paysBasePrice() {
        hireCashier(energy: ShopStaffPresence.lowEnergyThreshold - 0.01)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.001)
    }

    func test_cashierAtThreshold_stillGetsBonus() {
        hireCashier(energy: ShopStaffPresence.lowEnergyThreshold)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.25, accuracy: 0.001)
    }

    func test_veteranCashier_usesLargerBonusNotProduct() {
        hireCashier(tier: 5)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.4, accuracy: 0.001)
    }

    func test_tiredVeteran_paysBasePrice() {
        hireCashier(tier: 5, energy: 0.1)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.001)
    }

    func test_cashier_composesWithLocationAndMenu() {
        store.stall.locationTier = 2
        store.stall.menuTier = 1
        store.stall.menuStock[1] = 1
        hireCashier()
        XCTAssertEqual(store.sellItem(menuIndex: 1) ?? 0, 30 * 2.5 * 4 * 1.25, accuracy: 0.001)
    }

    func test_costsAreNotScaled() {
        store.stall.coins = 1_000
        hireCashier()
        let seedCost = FarmSystem.seedCost
        store.farm.plots[0].isPlanted = false
        store.plantSeed(plotIndex: 0)
        XCTAssertEqual(store.stall.coins, 1_000 - seedCost, accuracy: 0.001)
    }

    func test_bonusPercentForCopy() {
        XCTAssertEqual(EarningsSystem.cashierSaleBonusPercent(tier: 1), 25)
        XCTAssertEqual(EarningsSystem.cashierSaleBonusPercent(tier: 2), 25)
        XCTAssertEqual(EarningsSystem.cashierSaleBonusPercent(tier: 5), 40)
    }

    // MARK: Collection

    func test_cashier_collectsInstantlyLikeNone() {
        hireCashier()
        store.stall.coins = 0
        let price = store.sellItem(menuIndex: 0) ?? 0
        store.tick(deltaTime: 0.1)
        XCTAssertEqual(store.stall.coins, price, accuracy: 0.001)
        XCTAssertEqual(store.stall.pendingCoins, 0, accuracy: 0.001)
    }

    // MARK: Energy

    func test_sale_drainsCashierEnergy() {
        hireCashier()
        _ = store.sellItem(menuIndex: 0)
        XCTAssertEqual(store.stall.cashierEnergy, 1.0 - 1.0 / 60.0, accuracy: 0.0001)
    }

    func test_noCashier_saleLeavesEnergyAlone() {
        store.stall.cashierEnergy = 0.5
        _ = store.sellItem(menuIndex: 0)
        XCTAssertEqual(store.stall.cashierEnergy, 0.5, accuracy: 0.0001)
    }

    func test_nonstopSales_tireTheCashierAndLoseTheBonus() {
        hireCashier()
        var last = 0.0
        for _ in 0..<60 {
            last = store.sellItem(menuIndex: 0) ?? 0
            store.tick(deltaTime: 0.5)
        }
        XCTAssertLessThan(store.stall.cashierEnergy, ShopStaffPresence.lowEnergyThreshold)
        XCTAssertEqual(last, 30, accuracy: 0.001)
    }

    func test_energy_doesNotRestoreWhileSellingButRestoresWhenIdle() {
        hireCashier(energy: 0.5)
        _ = store.sellItem(menuIndex: 0)
        let afterSale = store.stall.cashierEnergy
        store.tick(deltaTime: 1.0)
        XCTAssertEqual(store.stall.cashierEnergy, afterSale, accuracy: 0.0001)   // still busy
        for _ in 0..<10 { store.tick(deltaTime: 1.0) }
        XCTAssertGreaterThan(store.stall.cashierEnergy, afterSale + 0.05)
    }

    func test_tiredCashier_recoversTheBonusAfterRest() {
        hireCashier(energy: 0.1)
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30, accuracy: 0.001)
        for _ in 0..<30 { store.tick(deltaTime: 1.0) }
        XCTAssertEqual(store.sellItem(menuIndex: 0) ?? 0, 30 * 1.25, accuracy: 0.001)
    }

    // MARK: Saves

    func test_oldSaveWithCashier_loadsAndEarnsBonus() throws {
        let json = #"{"cashierCount": 1, "cashierTier": 1, "cashierEnergy": 0.9, "menuStock": [5, 0, 0]}"#
        let decoded = try JSONDecoder().decode(StallState.self, from: Data(json.utf8))
        XCTAssertEqual(EarningsSystem.salePrice(for: decoded, menuIndex: 0), 30 * 1.25, accuracy: 0.001)
    }

    func test_stallStateWithoutCashier_salePriceEqualsPricePerItem() {
        let stall = StallState()
        XCTAssertEqual(EarningsSystem.salePrice(for: stall, menuIndex: 0),
                       EarningsSystem.pricePerItem(for: stall, menuIndex: 0), accuracy: 0.0001)
    }
}
