import AppTrackingTransparency
import GADManager
import GameCore
import GameUI
import UIKit

@MainActor
final class SwiftUIAdManager: NSObject, ObservableObject {

    #if DEBUG
    /// `-dotNoAds` turns ads off entirely, for screenshots and recordings; Debug otherwise runs
    /// Google test units.
    private static let adsDisabledByArgument = ProcessInfo.processInfo.arguments.contains("-dotNoAds")
    /// `-dotAdsGrant`: every rewarded request succeeds at once with no ad, so reward flows can be driven and screenshot.
    private static let grantsWithoutAds = ProcessInfo.processInfo.arguments.contains("-dotAdsGrant")
    private static let isTesting = true
    private static let appOpenInterval: TimeInterval = 60
    #else
    private static let adsDisabledByArgument = false
    private static let grantsWithoutAds = false
    private static let isTesting = false
    private static let appOpenInterval: TimeInterval = 4 * 3600
    #endif

    /// What GameUI reads and calls.
    let rewarded = RewardedAds()
    @Published private(set) var isAppOpenReady = false

    private var manager: GADManager<GADUnitName>?
    private var preparedPlacements: Set<AdPlacement> = []
    private var isSDKStarted = false
    private var isShowingAd = false
    /// In memory on purpose: a cold start may show an app open ad right away.
    private var lastShown: [String: Date] = [:]
    private var lastPrepared: [String: Date] = [:]
    private let attPromptShownKey = "ads.attPromptShownForRewarded"

    override init() {
        super.init()
        rewarded.show = { [weak self] placement, completion in self?.showRewarded(placement, completion: completion) }
        rewarded.prepare = { [weak self] placement in self?.prepareRewarded(placement) }
        if Self.grantsWithoutAds { rewarded.setAvailable(true) }
    }

    /// Called by the splash as it appears, before the SDK starts: from then on the manager exists.
    func setup() {
        guard !Self.adsDisabledByArgument, manager == nil else { return }
        guard let window else {
            assertionFailure("the splash is on screen, so its window must exist")
            return
        }
        let manager = GADManager<GADUnitName>(window)
        manager.delegate = self
        self.manager = manager
    }

    /// Called once the SDK has started: loads the app open ad and the offline popup's ad (it can open
    /// at launch), and makes the rewarded surfaces available; each prepares its own ad as it appears.
    func preload() {
        guard let manager, !isSDKStarted else { return }
        isSDKStarted = true
        rewarded.setAvailable(true)
        manager.prepare(openingUnit: .launch, isTesting: Self.isTesting, interval: Self.appOpenInterval)
        prepareRewarded(.offline)
    }

    // MARK: - Preload

    /// GADManager does not check for a load in flight, so a second call would start a second load.
    private func prepareRewarded(_ placement: AdPlacement) {
        guard !Self.adsDisabledByArgument, !Self.grantsWithoutAds else { return }
        guard let manager, isSDKStarted else { return }
        guard preparedPlacements.insert(placement).inserted else { return }
        print("[RewardAd] preparing \(placement.rawValue)")
        manager.prepare(rewardUnit: placement.unitName, isTesting: Self.isTesting)
    }

    // MARK: - Show App Open

    /// Shows the app open ad if one is ready and due. `completion` always fires: when the ad is dismissed, or at once if none is shown.
    func showAppOpen(completion: @escaping () -> Void) {
        guard let manager, !isShowingAd else { completion(); return }
        manager.show(unit: .launch, isTesting: Self.isTesting, viewController: topmostViewController) { _, _, _ in
            completion()
        }
    }

    // MARK: - Show Rewarded

    /// Calls `completion(true)` once the ad is dismissed with the reward earned, `completion(false)`
    /// if it was skipped or could not load or show.
    func showRewarded(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        if Self.grantsWithoutAds { completion(true); return }
        guard manager != nil, !isShowingAd else { completion(false); return }

        requestTrackingAuthorizationIfNeeded { [weak self] in
            guard let self, let manager = self.manager, !self.isShowingAd else {
                completion(false)
                return
            }
            self.preparedPlacements.insert(placement)
            manager.show(rewardUnit: placement.unitName, needToWait: true, isTesting: Self.isTesting,
                         viewController: self.topmostViewController) { _, _, rewarded in
                completion(rewarded)
            }
        }
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

    // MARK: - Helpers

    /// `keyWindow` is nil until the window has become key, which can be after the SDK has started.
    private var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.compactMap(\.keyWindow).first ?? scenes.flatMap(\.windows).first
    }

    /// SwiftUI sheets and dialogs are presented modally on the root, which cannot present a second
    /// controller, and GADManager presents from the root unless told otherwise.
    private var topmostViewController: UIViewController? {
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }
}

// MARK: - GADManagerDelegate

extension SwiftUIAdManager: GADManagerDelegate {

    nonisolated func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date {
        MainActor.assumeIsolated { lastShown[key(unit)] ?? Date(timeIntervalSince1970: 0) }
    }

    nonisolated func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date) {
        MainActor.assumeIsolated { lastShown[key(unit)] = time }
    }

    nonisolated func GAD<E>(manager: GADManager<E>, lastPreparedTimeForUnit unit: E) -> Date {
        MainActor.assumeIsolated { lastPrepared[key(unit)] ?? Date() }
    }

    nonisolated func GAD<E>(manager: GADManager<E>, updateLastPreparedTimeForUnit unit: E, preparedTime time: Date) {
        MainActor.assumeIsolated {
            lastPrepared[key(unit)] = time
            if (unit as? GADUnitName) == .launch { isAppOpenReady = true }
        }
    }

    nonisolated func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E) {
        MainActor.assumeIsolated { isShowingAd = true }
    }

    nonisolated func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E) {
        MainActor.assumeIsolated {
            isShowingAd = false
            if (unit as? GADUnitName) == .launch { isAppOpenReady = false }
        }
    }

    private func key<E>(_ unit: E) -> String { String(describing: unit) }
}
