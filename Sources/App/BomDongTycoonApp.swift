import SwiftUI
import GameCore

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var adManager = SwiftUIAdManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isSplashDone = false
    @State private var isLaunched = false
    @State private var isFromBackground = false
    @State private var pendingOfflineCalc = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                GameRootView()
                if !isSplashDone {
                    SplashView(isDone: $isSplashDone)
                }
            }
            .environmentObject(store)
            .environmentObject(adManager)
            .onChange(of: isSplashDone) { _, done in
                guard done, pendingOfflineCalc else { return }
                pendingOfflineCalc = false
                let bgTime = store.progress.lastActiveDate
                print("[App] splash done → app open ad → calculateOfflineEarnings")
                adManager.showAppOpen {
                    store.calculateOfflineEarnings(since: bgTime)
                }
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
                print("[App] cold start → pending until splash done")
                isLaunched = true
                pendingOfflineCalc = true
            } else if isFromBackground {
                print("[App] bg→fg → app open ad → calculateOfflineEarnings")
                isFromBackground = false
                pendingOfflineCalc = false
                let bgTime = store.progress.lastActiveDate
                adManager.showAppOpen {
                    store.calculateOfflineEarnings(since: bgTime)
                }
            } else {
                print("[App] .active but skipped (isLaunched=\(isLaunched), isFromBackground=\(isFromBackground))")
            }
        case .background:
            print("[App] → background, recordBackground")
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
