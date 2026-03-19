import SwiftUI
import GameCore
import GoogleMobileAds

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var rewardAd = SwiftUIRewardAdManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSplashDone = false
    @State private var isSetupDone = false
    @State private var isLaunched = false
    @State private var isFromBackground = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                GameRootView()
                    .environmentObject(store)
                    .environmentObject(rewardAd)
                if !isSplashDone {
                    SplashView(isDone: $isSplashDone)
                }
            }
            .onAppear {
                NotificationManager.requestPermission()
                setupAds()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(to: phase)
        }
    }

    private func setupAds() {
        guard !isSetupDone else { return }
        isSetupDone = true

        GADMobileAds.sharedInstance().start { [weak rewardAd] status in
            let adapters = status.adapterStatusesByClassName.count
            print("[AdMob] SDK started — adapters: \(adapters)")
            rewardAd?.preload()
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    isSplashDone = true
                }
            }
        }
    }

    private func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            NotificationManager.cancelAll()
            if !isLaunched {
                store.calculateOfflineEarnings()
                isLaunched = true
            } else if isFromBackground {
                isFromBackground = false
            }
        case .background:
            isFromBackground = true
            store.recordBackground()
            NotificationManager.scheduleStallFullNotification()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
