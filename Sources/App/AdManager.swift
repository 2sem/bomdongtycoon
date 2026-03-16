import GoogleMobileAds
import UIKit

@MainActor
final class AdManager: NSObject {
    static let shared = AdManager()

    private let rewardedAdUnitID = "ca-app-pub-9684378399371172/3844454464"
    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: (() -> Void)?

    init(startSDK: Bool = true) {
        super.init()
        if startSDK {
            GADMobileAds.sharedInstance().start()
        }
        loadRewardedAd()
    }

    func loadRewardedAd() {
        GADRewardedAd.load(
            withAdUnitID: rewardedAdUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            if error != nil { return }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    func showRewardedAd(completion: @escaping () -> Void) {
        guard let ad = rewardedAd,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            // No ad available — reward anyway (good UX)
            completion()
            return
        }
        rewardCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            self?.finishReward()
        }
    }

    private func finishReward() {
        rewardCompletion?()
        rewardCompletion = nil
        loadRewardedAd()
    }
}

extension AdManager: GADFullScreenContentDelegate {
    nonisolated func ad(
        _ ad: GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.finishReward()
        }
    }
}
