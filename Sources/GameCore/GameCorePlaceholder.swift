// GameCore placeholder — remove when real sources are added.
import Foundation

public enum TrackingAuthorizationState {
    case notDetermined
    case restricted
    case denied
    case authorized
    case unsupported
}

public enum TrackingAuthorizationPolicy {
    public static func shouldRequestPrompt(
        currentStatus: TrackingAuthorizationState,
        hasRequestedBefore: Bool
    ) -> Bool {
        currentStatus == .notDetermined && !hasRequestedBefore
    }
}
