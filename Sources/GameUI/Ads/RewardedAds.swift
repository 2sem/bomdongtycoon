import SwiftUI
import GameCore

/// What the UI knows about rewarded ads. The ad SDK cannot say whether a placement's ad is loaded,
/// so a placement counts as ready once ads are set up and no request for it is in flight; a tap
/// then waits for the ad to load and show. The App wires `show` and `prepare` to its ad manager.
@MainActor
public final class RewardedAds: ObservableObject {
    @Published public private(set) var isAvailable = false
    @Published private var requesting: Set<AdPlacement> = []
    /// Shows the ad; the completion gets `true` only when the reward was earned.
    public var show: (AdPlacement, @escaping (Bool) -> Void) -> Void = { _, done in done(false) }
    /// Asks the manager to start loading a placement's ad (lazy: nothing loads before a surface needs it).
    public var prepare: (AdPlacement) -> Void = { _ in }

    public init() {}

    public func isReady(_ placement: AdPlacement) -> Bool {
        isAvailable && !requesting.contains(placement)
    }

    public func setAvailable(_ isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    /// The one way to show an ad. The placement is not ready until the completion has fired.
    public func request(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        guard isReady(placement) else { completion(false); return }
        requesting.insert(placement)
        show(placement) { [weak self] rewarded in
            self?.requesting.remove(placement)
            completion(rewarded)
        }
    }

    public func watch(_ placement: AdPlacement, onReward: @escaping () -> Void) {
        request(placement) { rewarded in
            if rewarded { onReward() }
        }
    }
}
