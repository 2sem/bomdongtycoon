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

    func testTiredBelowThresholdOnly() {
        let rested = ShopStaffPresence(stall: stall {
            $0.cashierCount = 1
            $0.cashierEnergy = 0.25
            $0.menuCooks = [1, 0, 0]
            $0.menuCookEnergy = [0.25, 1, 1]
        })
        XCTAssertEqual(rested.cashier?.isTired, false)
        XCTAssertEqual(rested.cook?.isTired, false)

        let tired = ShopStaffPresence(stall: stall {
            $0.cashierCount = 1
            $0.cashierEnergy = 0.24
            $0.menuCooks = [1, 0, 0]
            $0.menuCookEnergy = [0.24, 1, 1]
        })
        XCTAssertEqual(tired.cashier?.isTired, true)
        XCTAssertEqual(tired.cook?.isTired, true)
    }

    func testUnhiredCookEnergyDoesNotTireTheFigure() {
        let presence = ShopStaffPresence(stall: stall {
            $0.menuCooks = [1, 0, 0]
            $0.menuCookEnergy = [1, 0, 0]
        })
        XCTAssertEqual(presence.cook?.isTired, false)
    }
}
