import SwiftUI
import GameCore
import FirebaseCore
import FirebaseMessaging

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var adManager = SwiftUIAdManager()

    init() {
        FirebaseApp.configure()
    }
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
                print("[App] splash done → calculateOfflineEarnings")
                store.calculateOfflineEarnings()
                if store.offlineEarnings == 0 {
                    print("[App] no offline earnings → show app open ad")
                    adManager.showAppOpen {}
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhaseChange(to: phase)
        }
    }

    private func handleScenePhaseChange(to phase: ScenePhase) {
        store.isAppActive = phase == .active
        switch phase {
        case .active:
            NotificationManager.cancelAll()
            if !isLaunched {
                print("[App] cold start → pending until splash done")
                isLaunched = true
                pendingOfflineCalc = true
            } else if isFromBackground {
                print("[App] bg→fg → calculateOfflineEarnings")
                isFromBackground = false
                store.calculateOfflineEarnings()
                if store.offlineEarnings == 0 {
                    print("[App] no offline earnings → show app open ad")
                    adManager.showAppOpen {}
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
