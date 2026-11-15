import GoogleMobileAds
import AppTrackingTransparency
import UIKit
import GameCore
import GameUI

extension AdPlacement {
    /// The one place a placement meets its ad unit. Release reads `AdPlacement.releaseUnitID`
    /// (GameCore, where a test checks the table); debug builds use Google's test rewarded unit.
    var unitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/1712485313"
        #else
        releaseUnitID
        #endif
    }
}

@MainActor
final class SwiftUIAdManager: NSObject, ObservableObject {

    // MARK: - Ad Unit IDs

    #if DEBUG
    private let appOpenUnitID   = "ca-app-pub-3940256099942544/9257395921"  // test app open
    /// Debug builds run without ads so they don't interrupt feature work; `-dotAdsLive` turns real
    /// ads (Google test units) back on.
    private static let adsDisabledForDevelopment = !ProcessInfo.processInfo.arguments.contains("-dotAdsLive")
    /// `-dotAdsGrant`: every rewarded request succeeds at once with no ad, so reward flows can be driven and screenshot.
    private static let grantsWithoutAds = ProcessInfo.processInfo.arguments.contains("-dotAdsGrant")
    #else
    private let appOpenUnitID   = "ca-app-pub-9684378399371172/7904835004"
    private static let adsDisabledForDevelopment = false
    private static let grantsWithoutAds = false
    #endif

    // MARK: - State

    /// What GameUI reads and calls; mirrors `readyPlacements`.
    let rewarded = RewardedAds()
    private var rewardedAds: [AdPlacement: GADRewardedAd] = [:]
    private var rewardedLoadedAt: [AdPlacement: Date] = [:]
    private var rewardedFailures: [AdPlacement: Int] = [:]
    private var rewardedRetryTasks: [AdPlacement: Task<Void, Never>] = [:]
    private var rewardedExpiryTasks: [AdPlacement: Task<Void, Never>] = [:]
    private var loadingPlacements: Set<AdPlacement> = []
    private var presentingPlacement: AdPlacement?
    @Published private(set) var readyPlacements: Set<AdPlacement> = []
    private var appOpenAd: GADAppOpenAd?
    private var appOpenLoadedAt: Date?
    private var appOpenFailures = 0
    private var appOpenRetryTask: Task<Void, Never>?
    private var appOpenExpiryTask: Task<Void, Never>?
    private var isShowingAd = false
    private var isLoadingAppOpen = false
    @Published private(set) var isAppOpenReady = false
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

    override init() {
        super.init()
        rewarded.show = { [weak self] placement, completion in self?.showRewarded(placement, completion: completion) }
        rewarded.prepare = { [weak self] placement in self?.preloadRewarded(placement) }
        if Self.grantsWithoutAds { for placement in AdPlacement.allCases { setReady(placement, true) } }
    }

    func isRewardedReady(_ placement: AdPlacement) -> Bool { readyPlacements.contains(placement) }

    private func setReady(_ placement: AdPlacement, _ isReady: Bool) {
        if isReady { readyPlacements.insert(placement) } else { readyPlacements.remove(placement) }
        rewarded.setReady(placement, isReady)
    }

    // MARK: - Preload

    /// The offline popup can open at launch, so its ad loads at once; every other placement loads
    /// the first time a surface for it appears (`RewardedAds.prepare`).
    func preload() {
        guard !Self.adsDisabledForDevelopment else { return }
        preloadRewarded(.offline)
        preloadAppOpen()
    }

    /// `userInitiated` (a player waiting on a tap) skips a pending backoff; the lazy `prepare` does not.
    private func preloadRewarded(_ placement: AdPlacement, userInitiated: Bool = false) {
        guard !Self.adsDisabledForDevelopment, !Self.grantsWithoutAds,
              !loadingPlacements.contains(placement), rewardedAds[placement] == nil else { return }
        if rewardedRetryTasks[placement] != nil {
            guard userInitiated else { return }
            rewardedRetryTasks[placement]?.cancel()
            rewardedRetryTasks[placement] = nil
        }
        loadingPlacements.insert(placement)
        print("[RewardAd] preloading \(placement.rawValue) — unit: \(placement.unitID)")
        GADRewardedAd.load(withAdUnitID: placement.unitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.loadingPlacements.remove(placement)
            guard let ad, error == nil else {
                print("[RewardAd] \(placement.rawValue) preload failed: \(error?.localizedDescription ?? "no ad")")
                self.scheduleRewardedRetry(placement)
                return
            }
            print("[RewardAd] \(placement.rawValue) preloaded ✓")
            self.rewardedFailures[placement] = nil
            ad.fullScreenContentDelegate = self
            self.rewardedAds[placement] = ad
            self.rewardedLoadedAt[placement] = Date()
            self.setReady(placement, true)
            self.scheduleRewardedExpiry(placement)
        }
    }

    private func scheduleRewardedRetry(_ placement: AdPlacement) {
        guard rewardedRetryTasks[placement] == nil else { return }
        let failures = (rewardedFailures[placement] ?? 0) + 1
        rewardedFailures[placement] = failures
        let delay = AdLoadPolicy.retryDelay(afterFailures: failures)
        print("[RewardAd] \(placement.rawValue) retry in \(Int(delay))s")
        rewardedRetryTasks[placement] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay), clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.rewardedRetryTasks[placement] = nil
            self.preloadRewarded(placement)
        }
    }

    private func scheduleRewardedExpiry(_ placement: AdPlacement) {
        rewardedExpiryTasks[placement]?.cancel()
        rewardedExpiryTasks[placement] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(AdLoadPolicy.rewardedLifetime), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.dropRewardedIfExpired(placement)
        }
    }

    /// Drops a stale ad, marks the placement not ready and loads a fresh one. True when it dropped one.
    @discardableResult
    private func dropRewardedIfExpired(_ placement: AdPlacement) -> Bool {
        guard rewardedAds[placement] != nil,
              let loadedAt = rewardedLoadedAt[placement],
              AdLoadPolicy.isRewardedExpired(loadedAt: loadedAt, now: Date()) else { return false }
        print("[RewardAd] \(placement.rawValue) expired — reloading")
        rewardedAds[placement] = nil
        rewardedLoadedAt[placement] = nil
        rewardedExpiryTasks[placement]?.cancel()
        rewardedExpiryTasks[placement] = nil
        setReady(placement, false)
        preloadRewarded(placement)
        return true
    }

    private func preloadAppOpen() {
        guard !Self.adsDisabledForDevelopment, !isLoadingAppOpen, appOpenAd == nil, appOpenRetryTask == nil else { return }
        isLoadingAppOpen = true
        print("[AppOpenAd] preloading — unit: \(appOpenUnitID)")
        GADAppOpenAd.load(withAdUnitID: appOpenUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoadingAppOpen = false
            guard let ad, error == nil else {
                print("[AppOpenAd] preload failed: \(error?.localizedDescription ?? "no ad")")
                self.scheduleAppOpenRetry()
                return
            }
            print("[AppOpenAd] preloaded ✓")
            self.appOpenFailures = 0
            ad.fullScreenContentDelegate = self
            self.appOpenAd = ad
            self.appOpenLoadedAt = Date()
            self.isAppOpenReady = true
            self.scheduleAppOpenExpiry()
        }
    }

    private func scheduleAppOpenRetry() {
        guard appOpenRetryTask == nil else { return }
        appOpenFailures += 1
        let delay = AdLoadPolicy.retryDelay(afterFailures: appOpenFailures)
        print("[AppOpenAd] retry in \(Int(delay))s")
        appOpenRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay), clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.appOpenRetryTask = nil
            self.preloadAppOpen()
        }
    }

    private func scheduleAppOpenExpiry() {
        appOpenExpiryTask?.cancel()
        appOpenExpiryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(AdLoadPolicy.appOpenLifetime), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.dropAppOpenIfExpired()
        }
    }

    @discardableResult
    private func dropAppOpenIfExpired() -> Bool {
        guard appOpenAd != nil, let loadedAt = appOpenLoadedAt,
              AdLoadPolicy.isAppOpenExpired(loadedAt: loadedAt, now: Date()) else { return false }
        print("[AppOpenAd] expired — reloading")
        appOpenAd = nil
        appOpenLoadedAt = nil
        appOpenExpiryTask?.cancel()
        appOpenExpiryTask = nil
        isAppOpenReady = false
        preloadAppOpen()
        return true
    }

    // MARK: - Show App Open

    /// Show the app open ad. `completion` is called when the ad is dismissed (or immediately if none is ready).
    func showAppOpen(completion: @escaping () -> Void) {
        guard !Self.adsDisabledForDevelopment else { completion(); return }
        guard !isShowingAd else { completion(); return }
        if let last = lastAppOpenShownDate,
           Date().timeIntervalSince(last) < Self.appOpenInterval {
            print("[AppOpenAd] skipping — shown \(Int(Date().timeIntervalSince(last) / 60))m ago")
            completion()
            return
        }
        dropAppOpenIfExpired()
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
        appOpenLoadedAt = nil
        appOpenExpiryTask?.cancel()
        isAppOpenReady = false
        lastAppOpenShownDate = Date()
        pendingAppOpenCompletion = completion
        ad.present(fromRootViewController: rootVC.topmostPresented)
    }

    // MARK: - Show Rewarded

    /// Show the rewarded ad of `placement`. Calls `completion(true)` if the reward was earned,
    /// `completion(false)` if skipped or failed. If the ad is still loading, waits up to 5 s.
    func showRewarded(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        if Self.grantsWithoutAds { completion(true); return }
        guard !Self.adsDisabledForDevelopment else { completion(false); return }
        guard !isShowingAd else { completion(false); return }

        requestTrackingAuthorizationIfNeeded { [weak self] in
            guard let self else {
                completion(false)
                return
            }
            self.showRewardedAfterTrackingPrompt(placement, completion: completion)
        }
    }

    private func showRewardedAfterTrackingPrompt(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        dropRewardedIfExpired(placement)
        if rewardedAds[placement] == nil {
            if !loadingPlacements.contains(placement) {
                print("[RewardAd] \(placement.rawValue) not ready and not loading — triggering fresh load")
                preloadRewarded(placement, userInitiated: true)
            } else {
                print("[RewardAd] \(placement.rawValue) loading in progress — waiting up to 5s")
            }
            Task { @MainActor [weak self] in
                let deadline = Date().addingTimeInterval(5)
                while let self, self.rewardedAds[placement] == nil && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard let self else { completion(false); return }
                self.presentRewarded(placement, completion: completion)
            }
            return
        }
        presentRewarded(placement, completion: completion)
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

    private func presentRewarded(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAds[placement] else {
            print("[RewardAd] \(placement.rawValue) no ad ready — skipping bonus")
            completion(false)
            preloadRewarded(placement)
            return
        }
        guard !isShowingAd, let rootVC = rootViewController else {
            print("[RewardAd] cannot present now — no bonus")
            completion(false)
            return
        }
        print("[RewardAd] presenting \(placement.rawValue)...")
        isShowingAd = true
        rewardedAds[placement] = nil
        rewardedLoadedAt[placement] = nil
        rewardedExpiryTasks[placement]?.cancel()
        rewardedExpiryTasks[placement] = nil
        setReady(placement, false)
        presentingPlacement = placement
        pendingRewardCompletion = completion
        ad.present(fromRootViewController: rootVC.topmostPresented) { [weak self] in
            print("[RewardAd] \(placement.rawValue) reward earned ✓")
            self?.pendingRewardCompletion?(true)
            self?.pendingRewardCompletion = nil
        }
    }

    // MARK: - Helpers

    private func reloadPresentedPlacement() {
        guard let placement = presentingPlacement else { return }
        presentingPlacement = nil
        preloadRewarded(placement)
    }

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
                self?.reloadPresentedPlacement()
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
                self?.reloadPresentedPlacement()
            }
        }
    }
}

private extension UIViewController {
    /// SwiftUI sheets and dialogs are presented modally on the root, which cannot present a second controller.
    var topmostPresented: UIViewController {
        var top = self
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}
