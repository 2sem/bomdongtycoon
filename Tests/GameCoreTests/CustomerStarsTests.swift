import XCTest
@testable import GameCore

final class CustomerStarsTests: XCTestCase {

    private let patience: TimeInterval = 12

    private func stars(_ waited: TimeInterval, gourmet: Bool = false, served: Bool = true) -> Double {
        CustomerStars.stars(waited: waited, patience: patience, isGourmet: gourmet, served: served)
    }

    func test_instantAndFastServeIsFive() {
        XCTAssertEqual(stars(0), 5)
        XCTAssertEqual(stars(2.99), 5)
    }

    func test_halfStarSteps() {
        XCTAssertEqual(stars(3.0), 4.5)
        XCTAssertEqual(stars(4.7), 4.5)
        XCTAssertEqual(stars(4.9), 4)
        XCTAssertEqual(stars(7.0), 4)
        XCTAssertEqual(stars(7.3), 3.5)
        XCTAssertEqual(stars(9.4), 3.5)
        XCTAssertEqual(stars(9.7), 3)
    }

    func test_stepsScaleWithPatience() {
        XCTAssertEqual(CustomerStars.stars(waited: 10, patience: 18, isGourmet: false, served: true), 4)
        XCTAssertEqual(CustomerStars.stars(waited: 11, patience: 18, isGourmet: false, served: true), 3.5)
    }

    func test_gourmetBumpsOneAndCapsAtFive() {
        XCTAssertEqual(stars(5, gourmet: true), 5)
        XCTAssertEqual(stars(11, gourmet: true), 4)
        XCTAssertEqual(stars(0, gourmet: true), 5)
    }

    func test_label() {
        XCTAssertEqual(CustomerStars.label(4), "4")
        XCTAssertEqual(CustomerStars.label(4.5), "4.5")
    }

    func test_failedIsOneEvenForGourmet() {
        XCTAssertEqual(stars(12, served: false), 1)
        XCTAssertEqual(stars(12, gourmet: true, served: false), 1)
    }
}
