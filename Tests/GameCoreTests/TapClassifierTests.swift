import XCTest
import CoreGraphics
@testable import GameCore

final class TapClassifierTests: XCTestCase {

    private func classify(_ path: [CGPoint], endingWith end: CGPoint? = nil) -> Bool {
        var c = TapClassifier(slop: 10)
        c.begin(at: path[0])
        for p in path.dropFirst() { c.move(to: p) }
        return c.end(at: end ?? path.last!)
    }

    func test_stationaryTap() {
        XCTAssertTrue(classify([CGPoint(x: 100, y: 100)]))
    }

    func test_9ptDrift_isTap() {
        XCTAssertTrue(classify([CGPoint(x: 100, y: 100), CGPoint(x: 109, y: 100)]))
    }

    func test_11ptDrift_isPan() {
        XCTAssertFalse(classify([CGPoint(x: 100, y: 100), CGPoint(x: 111, y: 100)]))
    }

    func test_longPress_stationary_isStillTap() {
        // Many identical move events, as a held finger produces.
        let held = Array(repeating: CGPoint(x: 50, y: 50), count: 120)
        XCTAssertTrue(classify(held))
    }

    func test_pathLeavingAndReturningToStart_isPan() {
        let path = [CGPoint(x: 100, y: 100), CGPoint(x: 160, y: 100), CGPoint(x: 100, y: 100)]
        XCTAssertFalse(classify(path))
    }

    func test_cancelledTouch_endsWithoutTap() {
        var c = TapClassifier(slop: 10)
        c.begin(at: .zero)
        c.cancel()
        XCTAssertFalse(c.end(at: .zero))
    }

    func test_endWithoutBegin_isNotTap() {
        var c = TapClassifier(slop: 10)
        XCTAssertFalse(c.end(at: .zero))
    }

    func test_reusableAfterEnd() {
        var c = TapClassifier(slop: 10)
        c.begin(at: .zero)
        c.move(to: CGPoint(x: 50, y: 0))
        XCTAssertFalse(c.end(at: CGPoint(x: 50, y: 0)))
        c.begin(at: CGPoint(x: 5, y: 5))
        XCTAssertTrue(c.end(at: CGPoint(x: 5, y: 5)))
    }
}
