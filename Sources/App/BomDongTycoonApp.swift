import SwiftUI
import GameCore

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var rewardAd = SwiftUIRewardAdManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSplashDone = false
    @State private var isLaunched = false
    @State private var isFromBackground = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                GameRootView()
                if !isSplashDone {
                    SplashView(isDone: $isSplashDone)
                }
            }
            .environmentObject(store)
            .environmentObject(rewardAd)
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
                store.calculateOfflineEarnings()
                isLaunched = true
            } else if isFromBackground {
                store.calculateOfflineEarnings()
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
