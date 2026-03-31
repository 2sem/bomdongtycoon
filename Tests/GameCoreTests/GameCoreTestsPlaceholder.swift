import XCTest
@testable import GameCore

final class TrackingAuthorizationPolicyTests: XCTestCase {

    func test_shouldRequestPrompt_whenNotDeterminedAndNeverAsked_returnsTrue() {
        let shouldRequest = TrackingAuthorizationPolicy.shouldRequestPrompt(
            currentStatus: .notDetermined,
            hasRequestedBefore: false
        )

        XCTAssertTrue(shouldRequest)
    }

    func test_shouldRequestPrompt_whenNotDeterminedAndAlreadyAsked_returnsFalse() {
        let shouldRequest = TrackingAuthorizationPolicy.shouldRequestPrompt(
            currentStatus: .notDetermined,
            hasRequestedBefore: true
        )

        XCTAssertFalse(shouldRequest)
    }

    func test_shouldRequestPrompt_whenStatusDetermined_returnsFalse() {
        let statuses: [TrackingAuthorizationState] = [.restricted, .denied, .authorized, .unsupported]

        for status in statuses {
            let shouldRequest = TrackingAuthorizationPolicy.shouldRequestPrompt(
                currentStatus: status,
                hasRequestedBefore: false
            )
            XCTAssertFalse(shouldRequest, "status=\(status) should not request")
        }
    }
}
