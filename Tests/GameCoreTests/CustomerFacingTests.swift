import XCTest
@testable import GameCore

final class CustomerFacingTests: XCTestCase {

    func test_approaching_showsBack() {
        XCTAssertEqual(CustomerFacing(stage: .approaching), .back)
    }

    func test_waitingAtCounter_showsBack() {
        XCTAssertEqual(CustomerFacing(stage: .waiting), .back)
    }

    func test_leaving_showsFront() {
        XCTAssertEqual(CustomerFacing(stage: .leaving), .front)
    }
}
