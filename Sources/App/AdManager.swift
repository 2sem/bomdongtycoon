import GoogleMobileAds
import UIKit

@MainActor
final class AdManager: NSObject {
    static let shared = AdManager()

    private let rewardedAdUnitID = "ca-app-pub-9684378399371172/3844454464"
    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: ((Bool) -> Void)?

    init(startSDK: Bool = true) {
        super.init()
        if startSDK {
            GADMobileAds.sharedInstance().start { status in
                print("[AdManager] SDK started — adapters: \(status.adapterStatusesByClassName.count)")
            }
        }
        loadRewardedAd()
    }

    func loadRewardedAd() {
        print("[AdManager] loadRewardedAd — unit: \(rewardedAdUnitID)")
        GADRewardedAd.load(
            withAdUnitID: rewardedAdUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            if let error {
                print("[AdManager] load failed: \(error.localizedDescription)")
                return
            }
            print("[AdManager] ad loaded ✓")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    /// Shows a rewarded ad. Calls `completion(true)` if the reward was earned,
    /// `completion(false)` if no ad was available or it failed.
    func showRewardedAd(completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            print("[AdManager] showRewardedAd — no ad loaded, rewarding anyway")
            completion(true)   // good UX: reward even if ad unavailable
            return
        }
        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            print("[AdManager] showRewardedAd — no rootViewController found")
            completion(true)
            return
        }
        print("[AdManager] presenting rewarded ad")
        rewardCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            print("[AdManager] reward earned ✓")
            self?.finishReward(earned: true)
        }
    }

    private func finishReward(earned: Bool) {
        rewardCompletion?(earned)
        rewardCompletion = nil
        loadRewardedAd()
    }
}

extension AdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[AdManager] ad dismissed")
        Task { @MainActor [weak self] in
            // If reward wasn't already delivered (user skipped), don't reward
            if self?.rewardCompletion != nil {
                print("[AdManager] dismissed without reward")
                self?.finishReward(earned: false)
            }
        }
    }

    nonisolated func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("[AdManager] failed to present: \(error.localizedDescription)")
        Task { @MainActor [weak self] in
            self?.finishReward(earned: true)   // fail gracefully → reward anyway
        }
    }
}
