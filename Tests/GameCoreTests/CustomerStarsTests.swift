import XCTest
@testable import GameCore

final class CustomerStarsTests: XCTestCase {

    private let patience: TimeInterval = 12

    private func stars(_ waited: TimeInterval, gourmet: Bool = false, served: Bool = true) -> Int {
        CustomerStars.stars(waited: waited, patience: patience, isGourmet: gourmet, served: served)
    }

    func test_instantAndFastServeIsFive() {
        XCTAssertEqual(stars(0), 5)
        XCTAssertEqual(stars(2.99), 5)
    }

    func test_fastBoundaryAtThreeSeconds() {
        XCTAssertEqual(stars(3.0), 4)
    }

    func test_halfPatienceBoundary() {
        XCTAssertEqual(stars(5.99), 4)
        XCTAssertEqual(stars(6.0), 3)
        XCTAssertEqual(stars(11.9), 3)
    }

    func test_halfPatienceScalesWithPatience() {
        XCTAssertEqual(CustomerStars.stars(waited: 8, patience: 18, isGourmet: false, served: true), 4)
        XCTAssertEqual(CustomerStars.stars(waited: 9, patience: 18, isGourmet: false, served: true), 3)
    }

    func test_gourmetBumpsOneAndCapsAtFive() {
        XCTAssertEqual(stars(7, gourmet: true), 4)
        XCTAssertEqual(stars(4, gourmet: true), 5)
        XCTAssertEqual(stars(0, gourmet: true), 5)
    }

    func test_failedIsOneEvenForGourmet() {
        XCTAssertEqual(stars(12, served: false), 1)
        XCTAssertEqual(stars(12, gourmet: true, served: false), 1)
    }
}
