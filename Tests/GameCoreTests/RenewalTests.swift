import XCTest
@testable import GameCore

@MainActor
final class RenewalTests: DotWorldTestCase {

    private func failingShop(rating: Double = 1.4) {
        store.progress.rating = rating
        store.stall.menuTier = 1
        store.stall.coins = 1_000_000
    }

    /// Key order in encoded JSON is not stable, so compare the parsed form.
    private func json<T: Encodable>(_ value: T) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSDictionary)
    }

    // MARK: Eligibility

    func test_eligible_onlyBelowTwoPointFive_byTheDisplayedRating() {
        store.progress.rating = 2.44
        XCTAssertTrue(store.isRenewalAvailable)
        store.progress.rating = 2.46   // the HUD prints 2.5
        XCTAssertFalse(store.isRenewalAvailable)
        store.progress.rating = 3.4
        XCTAssertFalse(store.isRenewalAvailable)
    }

    func test_refusedWhenNotEligible() {
        store.progress.rating = 2.5
        store.stall.coins = 1_000_000
        XCTAssertFalse(store.renewShop(payment: .coins))
        XCTAssertFalse(store.renewShop(payment: .ad))
        XCTAssertEqual(store.stall.coins, 1_000_000)
        XCTAssertEqual(store.progress.rating, 2.5)
    }

    // MARK: Fee

    func test_fee_isThirtySalesOfTheBestDish_cleaned() {
        store.stall.menuTier = 1
        let price = EarningsSystem.salePrice(for: store.stall, menuIndex: 1, prestigeCount: 0)
        XCTAssertEqual(store.renewalFee, Double(MissionSystem.cleanNumber(30 * price)))
        store.stall.menuTier = 2
        let best = EarningsSystem.salePrice(for: store.stall, menuIndex: 2, prestigeCount: 0)
        XCTAssertEqual(store.renewalFee, Double(MissionSystem.cleanNumber(30 * best)))
        XCTAssertGreaterThan(store.renewalFee, Double(MissionSystem.cleanNumber(30 * price)))
    }

    // MARK: Paying

    func test_coins_deductTheFee_andSetRatingToThree() {
        failingShop()
        let fee = store.renewalFee
        XCTAssertTrue(store.renewShop(payment: .coins))
        XCTAssertEqual(store.stall.coins, 1_000_000 - fee, accuracy: 1e-6)
        XCTAssertEqual(store.progress.rating, 3.0)
    }

    func test_unaffordable_changesNothing() {
        failingShop()
        store.stall.coins = store.renewalFee - 1
        XCTAssertFalse(store.canAffordRenewal)
        XCTAssertFalse(store.renewShop(payment: .coins))
        XCTAssertEqual(store.progress.rating, 1.4)
        XCTAssertNil(store.progress.lastRenewalPlaySeconds)
    }

    func test_ad_costsNothing() {
        failingShop()
        store.stall.coins = 0
        XCTAssertTrue(store.renewShop(payment: .ad))
        XCTAssertEqual(store.stall.coins, 0)
        XCTAssertEqual(store.progress.rating, 3.0)
    }

    func test_nothingElseChanges() throws {
        failingShop()
        store.stall.menuTier = 2
        store.stall.staffTier = 2
        store.stall.cashierCount = 1
        store.stall.menuStock = [4, 5, 6]
        store.farm.plots[0].isPlanted = true
        store.farm.plots[0].growth = 0.4
        let stallBefore = store.stall
        let farmBefore = try json(store.farm)
        var progressBefore = store.progress

        XCTAssertTrue(store.renewShop(payment: .ad))

        XCTAssertEqual(try json(store.stall), try json(stallBefore))
        XCTAssertEqual(try json(store.farm), farmBefore)
        progressBefore.rating = 3.0
        progressBefore.lastRenewalPlaySeconds = store.progress.totalPlaySeconds
        XCTAssertEqual(try json(store.progress), try json(progressBefore))
    }

    func test_coinPayment_changesOnlyCoinsInTheStall() throws {
        failingShop()
        var expected = store.stall
        expected.coins -= store.renewalFee
        XCTAssertTrue(store.renewShop(payment: .coins))
        XCTAssertEqual(try json(store.stall), try json(expected))
    }

    // MARK: Cooldown

    func test_cooldown_tenMinutesOfPlayTime() {
        failingShop()
        XCTAssertTrue(store.renewShop(payment: .ad))
        store.progress.rating = 1.2
        XCTAssertFalse(store.isRenewalAvailable)
        XCTAssertEqual(store.renewalCooldownRemaining, 600, accuracy: 1e-9)
        store.tick(deltaTime: 599)
        store.progress.rating = 1.2
        XCTAssertFalse(store.isRenewalAvailable)
        XCTAssertFalse(store.renewShop(payment: .coins))
        store.tick(deltaTime: 1)
        store.progress.rating = 1.2
        XCTAssertTrue(store.isRenewalAvailable)
    }

    func test_cooldown_survivesASaveLoadRoundTrip() {
        failingShop()
        XCTAssertTrue(store.renewShop(payment: .ad))
        store.tick(deltaTime: 100)
        store.recordBackground()

        let reloaded = makeStore()
        reloaded.progress.rating = 1.2
        XCTAssertEqual(reloaded.renewalCooldownRemaining, 500, accuracy: 1e-6)
        XCTAssertFalse(reloaded.isRenewalAvailable)
    }

    func test_cooldown_resetsOnANewRun() {
        failingShop()
        XCTAssertTrue(store.renewShop(payment: .ad))
        store.stall.locationTier = 2
        store.stall.stallTier = 2
        XCTAssertTrue(store.startNewRun())
        XCTAssertNil(store.progress.lastRenewalPlaySeconds)
        XCTAssertEqual(store.renewalCooldownRemaining, 0)
    }

    func test_oldSaveWithoutTheField_decodesWithNoCooldown() throws {
        let progress = try JSONDecoder().decode(PlayerProgress.self, from: Data(#"{"rating":1.5}"#.utf8))
        XCTAssertNil(progress.lastRenewalPlaySeconds)
    }

    func test_garbageField_decodesAsNoCooldown() throws {
        let progress = try JSONDecoder().decode(PlayerProgress.self,
                                                from: Data(#"{"rating":1.5,"lastRenewalPlaySeconds":"soon"}"#.utf8))
        XCTAssertNil(progress.lastRenewalPlaySeconds)
    }
}
