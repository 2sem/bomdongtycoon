import GoogleMobileAds
import AppTrackingTransparency
import UIKit
import GameCore

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
    @Published private(set) var isAppOpenReady = false
    @Published private(set) var isRewardedReady = false
    private var pendingRewardCompletion: ((Bool) -> Void)?
    private var pendingAppOpenCompletion: (() -> Void)?
    private var lastAppOpenShownDate: Date?
    private let attPromptShownKey = "ads.attPromptShownForRewarded"

    /// Minimum seconds between App Open ad impressions
    #if DEBUG
    private static let appOpenInterval: TimeInterval = 60       // 1 min for debugging
    #else
    private static let appOpenInterval: TimeInterval = 4 * 3600 // 4 hours in production
    #endif

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
            self?.isRewardedReady = true
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
            self?.isAppOpenReady = true
        }
    }

    // MARK: - Show App Open

    /// Show the app open ad. `completion` is called when the ad is dismissed (or immediately if none is ready).
    func showAppOpen(completion: @escaping () -> Void) {
        guard !isShowingAd else { completion(); return }
        if let last = lastAppOpenShownDate,
           Date().timeIntervalSince(last) < Self.appOpenInterval {
            print("[AppOpenAd] skipping — shown \(Int(Date().timeIntervalSince(last) / 60))m ago")
            completion()
            return
        }
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
        isAppOpenReady = false
        lastAppOpenShownDate = Date()
        pendingAppOpenCompletion = completion
        ad.present(fromRootViewController: rootVC)
    }

    // MARK: - Show Rewarded

    /// Show the rewarded ad. Calls `completion(true)` if reward earned, `completion(false)` if skipped/failed.
    /// If the ad is still loading, waits up to 5s before giving up.
    func showRewarded(completion: @escaping (Bool) -> Void) {
        guard !isShowingAd else { completion(false); return }

        requestTrackingAuthorizationIfNeeded { [weak self] in
            guard let self else {
                completion(false)
                return
            }
            self.showRewardedAfterTrackingPrompt(completion: completion)
        }
    }

    private func showRewardedAfterTrackingPrompt(completion: @escaping (Bool) -> Void) {
        if rewardedAd == nil {
            if !isLoadingRewarded {
                print("[RewardAd] not ready and not loading — triggering fresh load")
                preloadRewarded()
            } else {
                print("[RewardAd] loading in progress — waiting up to 5s")
            }
            Task { @MainActor [weak self] in
                let deadline = Date().addingTimeInterval(5)
                while let self, self.rewardedAd == nil && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let self else { completion(false); return }
                self.presentRewarded(completion: completion)
            }
            return
        }
        presentRewarded(completion: completion)
    }

    private func requestTrackingAuthorizationIfNeeded(completion: @escaping () -> Void) {
        let hasRequestedBefore = UserDefaults.standard.bool(forKey: attPromptShownKey)
        guard TrackingAuthorizationPolicy.shouldRequestPrompt(
            currentStatus: currentTrackingAuthorizationState(),
            hasRequestedBefore: hasRequestedBefore
        ) else {
            completion()
            return
        }

        UserDefaults.standard.set(true, forKey: attPromptShownKey)
        print("[ATT] requesting authorization before first rewarded-ad flow")

        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in
                completion()
            }
        }
    }

    private func currentTrackingAuthorizationState() -> TrackingAuthorizationState {
        guard #available(iOS 14, *) else {
            return .unsupported
        }

        switch ATTrackingManager.trackingAuthorizationStatus {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        @unknown default: return .unsupported
        }
    }

    private func presentRewarded(completion: @escaping (Bool) -> Void) {
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
        isRewardedReady = false
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
