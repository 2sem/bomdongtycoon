import XCTest
@testable import GameCore

final class ShopStaffPresenceTests: XCTestCase {

    private func stall(_ configure: (inout StallState) -> Void = { _ in }) -> StallState {
        var stall = StallState()
        configure(&stall)
        return stall
    }

    func testNoStaffShowsNobody() {
        let presence = ShopStaffPresence(stall: stall())
        XCTAssertNil(presence.cashier)
        XCTAssertNil(presence.cook)
    }

    func testSeveralCashiersAndCooksStillShowOneFigureEach() {
        let presence = ShopStaffPresence(stall: stall {
            $0.cashierCount = 3
            $0.menuCooks = [1, 2, 3]
        })
        XCTAssertNotNil(presence.cashier)
        XCTAssertNotNil(presence.cook)
    }

    func testCashierWorksOnlyWhileCoinsArePending() {
        XCTAssertEqual(ShopStaffPresence(stall: stall { $0.cashierCount = 1 }).cashier?.isWorking, false)
        let busy = ShopStaffPresence(stall: stall { $0.cashierCount = 1; $0.pendingCoins = 5 })
        XCTAssertEqual(busy.cashier?.isWorking, true)
    }

    func testPendingCoinsWithoutCashierShowNobody() {
        XCTAssertNil(ShopStaffPresence(stall: stall { $0.pendingCoins = 5 }).cashier)
    }

    func testCookWorksWhileAutoCookingHiredMenu() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 0, 0]
            $0.warehouse = 5
        })
        XCTAssertEqual(presence.cook?.isWorking, true)
    }

    func testCookIdlesWhenWarehouseIsEmpty() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 0, 0]
            $0.warehouse = 0
        })
        XCTAssertEqual(presence.cook?.isWorking, false)
    }

    func testCookIdlesWhenStockIsFull() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 0, 0]
            $0.warehouse = 5
            $0.menuStock = [EarningsSystem.maxStock(for: $0), 0, 0]
        })
        XCTAssertEqual(presence.cook?.isWorking, false)
    }

    func testCookOnLockedMenuIdles() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuTier = 0
            $0.menuCooks = [0, 1, 0]
            $0.warehouse = 5
        })
        XCTAssertNotNil(presence.cook)
        XCTAssertEqual(presence.cook?.isWorking, false)
    }

    func testRestingFollowsTheSleepFlagNotTheEnergyLevel() {
        let awake = ShopStaffPresence(stall: stall {
            $0.cashierCount = 1
            $0.cashierEnergy = 0.1
            $0.menuCooks = [1, 0, 0]
            $0.menuCookEnergy = [0.1, 1, 1]
        })
        XCTAssertEqual(awake.cashier?.isResting, false)
        XCTAssertEqual(awake.cook?.isResting, false)

        let asleep = ShopStaffPresence(stall: stall {
            $0.cashierCount = 1
            $0.cashierEnergy = 0.6
            $0.cashierResting = true
            $0.pendingCoins = 5
            $0.menuCooks = [1, 0, 0]
            $0.menuCookEnergy = [0.6, 1, 1]
            $0.menuCookResting = [true, false, false]
            $0.warehouse = 5
            $0.menuStock = [0, 0, 0]
        })
        XCTAssertEqual(asleep.cashier?.isResting, true)
        XCTAssertEqual(asleep.cashier?.isWorking, false, "a sleeping figure never shows the working pose")
        XCTAssertEqual(asleep.cook?.isResting, true)
        XCTAssertEqual(asleep.cook?.isWorking, false)
    }

    func testCookFigureSleepsOnlyWhenEveryHiredCookDoes() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 1, 0]
            $0.menuCookResting = [true, false, false]
            $0.menuTier = 1
            $0.warehouse = 5
            $0.menuStock = [0, 0, 0]
        })
        XCTAssertEqual(presence.cook?.isResting, false)
        XCTAssertEqual(presence.cook?.isWorking, true)
    }

    func testUnhiredCookRestingDoesNotSleepTheFigure() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 0, 0]
            $0.menuCookResting = [false, true, true]
        })
        XCTAssertEqual(presence.cook?.isResting, false)
    }
}
