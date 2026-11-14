import SwiftUI
import GameCore

/// What the UI knows about rewarded ads: which placements have an ad loaded, and how to show one.
/// The App wires `show` and `prepare` to its ad manager and keeps `ready` current, so GameUI never
/// touches the ad SDK.
@MainActor
public final class RewardedAds: ObservableObject {
    @Published public private(set) var ready: Set<AdPlacement> = []
    /// Shows the ad; the completion gets `true` only when the reward was earned.
    public var show: (AdPlacement, @escaping (Bool) -> Void) -> Void = { _, done in done(false) }
    /// Asks the manager to load a placement's ad now (lazy: nothing loads before a surface needs it).
    public var prepare: (AdPlacement) -> Void = { _ in }

    public init() {}

    public func isReady(_ placement: AdPlacement) -> Bool { ready.contains(placement) }

    public func setReady(_ placement: AdPlacement, _ isReady: Bool) {
        if isReady { ready.insert(placement) } else { ready.remove(placement) }
    }

    public func watch(_ placement: AdPlacement, onReward: @escaping () -> Void) {
        show(placement) { rewarded in
            if rewarded { onReward() }
        }
    }
}
