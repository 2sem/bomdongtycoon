import SwiftUI
import GameCore
import GoogleMobileAds

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var rewardAd = SwiftUIRewardAdManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLaunched = false
    @State private var isFromBackground = false

    init() {
        NotificationManager.requestPermission()
        GADMobileAds.sharedInstance().start { status in
            let adapters = status.adapterStatusesByClassName.count
            print("[AdMob] SDK started — adapters: \(adapters)")
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
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(to: phase)
        }
    }

    private func handleScenePhaseChange(to phase: ScenePhase) {
        switch phase {
        case .active:
            NotificationManager.cancelAll()
            if !isLaunched {
                // Cold start (terminated → active): calculate offline earnings once
                store.calculateOfflineEarnings()
                isLaunched = true
            } else if isFromBackground {
                // Background resume: do not recalculate
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
