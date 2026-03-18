import GoogleMobileAds
import UIKit

@MainActor
final class SwiftUIRewardAdManager: NSObject, ObservableObject {

    #if DEBUG
    private let unitID = "ca-app-pub-3940256099942544/1712485313"  // Google official test unit
    #else
    private let unitID = "ca-app-pub-9684378399371172/3844454464"
    #endif

    private var rewardedAd: GADRewardedAd?
    private var pendingCompletion: ((Bool) -> Void)?

    // MARK: - Preload

    func preload() {
        print("[RewardAd] preloading — unit: \(unitID)")
        GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest()) { [weak self] ad, error in
            if let error {
                print("[RewardAd] preload failed: \(error.localizedDescription)")
                return
            }
            print("[RewardAd] preloaded ✓")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    // MARK: - Show

    /// Show the rewarded ad. Calls `completion(true)` if reward earned, `completion(false)` if skipped.
    func show(completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            print("[RewardAd] no ad ready — rewarding anyway and preloading next")
            completion(true)
            preload()
            return
        }
        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            print("[RewardAd] no rootViewController — rewarding anyway")
            completion(true)
            return
        }
        print("[RewardAd] presenting...")
        rewardedAd = nil          // clear to prevent double-show
        pendingCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            print("[RewardAd] reward earned ✓")
            self?.pendingCompletion?(true)
            self?.pendingCompletion = nil
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension SwiftUIRewardAdManager: GADFullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            if self?.pendingCompletion != nil {
                print("[RewardAd] dismissed without earning reward")
                self?.pendingCompletion?(false)
                self?.pendingCompletion = nil
            }
            self?.preload()   // preload next ad immediately
        }
    }

    nonisolated func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("[RewardAd] presentation failed: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.pendingCompletion?(true)   // fail gracefully → reward anyway
            self?.pendingCompletion = nil
            self?.preload()
        }
    }
}
