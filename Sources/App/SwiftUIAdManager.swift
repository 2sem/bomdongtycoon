import GoogleMobileAds
import UIKit

@MainActor
final class SwiftUIAdManager: NSObject, ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    private let rewardedUnitID  = "ca-app-pub-3940256099942544/1712485313"  // test rewarded
    private let appOpenUnitID   = "ca-app-pub-3940256099942544/9257395921"  // test app open
    #else
    private let rewardedUnitID  = "ca-app-pub-9684378399371172/3844454464"
    private let appOpenUnitID   = "ca-app-pub-9684378399371172/7904835004"
    #endif

    // MARK: - State

    private var rewardedAd: GADRewardedAd?
    private var appOpenAd: GADAppOpenAd?
    private var isShowingAd = false
    private var isLoadingRewarded = false
    private var isLoadingAppOpen = false
    private var pendingRewardCompletion: ((Bool) -> Void)?
    private var pendingAppOpenCompletion: (() -> Void)?

    // MARK: - Preload

    func preload() {
        preloadRewarded()
        preloadAppOpen()
    }

    private func preloadRewarded() {
        guard !isLoadingRewarded, rewardedAd == nil else { return }
        isLoadingRewarded = true
        print("[RewardAd] preloading — unit: \(rewardedUnitID)")
        GADRewardedAd.load(withAdUnitID: rewardedUnitID, request: GADRequest()) { [weak self] ad, error in
            self?.isLoadingRewarded = false
            if let error { print("[RewardAd] preload failed: \(error.localizedDescription)"); return }
            print("[RewardAd] preloaded ✓")
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    private func preloadAppOpen() {
        guard !isLoadingAppOpen, appOpenAd == nil else { return }
        isLoadingAppOpen = true
        print("[AppOpenAd] preloading — unit: \(appOpenUnitID)")
        GADAppOpenAd.load(withAdUnitID: appOpenUnitID, request: GADRequest()) { [weak self] ad, error in
            self?.isLoadingAppOpen = false
            if let error { print("[AppOpenAd] preload failed: \(error.localizedDescription)"); return }
            print("[AppOpenAd] preloaded ✓")
            self?.appOpenAd = ad
            self?.appOpenAd?.fullScreenContentDelegate = self
        }
    }

    // MARK: - Show App Open

    /// Show the app open ad. `completion` is called when the ad is dismissed (or immediately if none is ready).
    func showAppOpen(completion: @escaping () -> Void) {
        guard !isShowingAd else { completion(); return }
        guard let ad = appOpenAd else {
            print("[AppOpenAd] no ad ready — skipping")
            completion()
            preloadAppOpen()
            return
        }
        guard let rootVC = rootViewController else {
            print("[AppOpenAd] no rootViewController")
            completion()
            return
        }
        print("[AppOpenAd] presenting...")
        isShowingAd = true
        appOpenAd = nil
        pendingAppOpenCompletion = completion
        ad.present(fromRootViewController: rootVC)
    }

    // MARK: - Show Rewarded

    /// Show the rewarded ad. Calls `completion(true)` if reward earned, `completion(false)` if skipped/failed.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        guard !isShowingAd else { completion(false); return }
        guard let ad = rewardedAd else {
            print("[RewardAd] no ad ready — skipping bonus")
            completion(false)
            preloadRewarded()
            return
        }
        guard let rootVC = rootViewController else {
            print("[RewardAd] no rootViewController — rewarding anyway")
            completion(true)
            return
        }
        print("[RewardAd] presenting...")
        isShowingAd = true
        rewardedAd = nil
        pendingRewardCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            print("[RewardAd] reward earned ✓")
            self?.pendingRewardCompletion?(true)
            self?.pendingRewardCompletion = nil
        }
    }

    // MARK: - Helpers

    private var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
    }
}

// MARK: - GADFullScreenContentDelegate

extension SwiftUIAdManager: GADFullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor [weak self] in
            self?.isShowingAd = false
            if ad is GADAppOpenAd {
                print("[AppOpenAd] dismissed")
                self?.pendingAppOpenCompletion?()
                self?.pendingAppOpenCompletion = nil
                self?.preloadAppOpen()
            } else {
                if self?.pendingRewardCompletion != nil {
                    print("[RewardAd] dismissed without earning reward")
                    self?.pendingRewardCompletion?(false)
                    self?.pendingRewardCompletion = nil
                }
                self?.preloadRewarded()
            }
        }
    }

    nonisolated func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isShowingAd = false
            if ad is GADAppOpenAd {
                print("[AppOpenAd] failed: \(error.localizedDescription)")
                self?.pendingAppOpenCompletion?()
                self?.pendingAppOpenCompletion = nil
                self?.preloadAppOpen()
            } else {
                print("[RewardAd] failed: \(error.localizedDescription)")
                self?.pendingRewardCompletion?(false)  // no ad shown → no bonus
                self?.pendingRewardCompletion = nil
                self?.preloadRewarded()
            }
        }
    }
}
