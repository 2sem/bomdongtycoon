import SwiftUI
import GameCore
import GoogleMobileAds

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var rewardAd = SwiftUIRewardAdManager()

    init() {
        NotificationManager.requestPermission()
        // Start AdMob SDK as early as possible so the rewarded ad can preload
        GADMobileAds.sharedInstance().start { [weak rewardAd = rewardAd] status in
            let adapters = status.adapterStatusesByClassName.count
            print("[AdMob] SDK started — adapters: \(adapters)")
            // @StateObject not yet available in init — preload happens in onAppear
        }
    }

    var body: some Scene {
        WindowGroup {
            GameRootView()
                .environmentObject(store)
                .environmentObject(rewardAd)
                .onAppear {
                    rewardAd.preload()
                }
        }
    }
}
