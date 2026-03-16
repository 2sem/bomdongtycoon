import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.scenePhase) var scenePhase
    @State private var showUpgrades = false

    var body: some View {
        ZStack {
            GameSceneView()
                .ignoresSafeArea()
            if store.progress.isFirstLaunch {
                TutorialOverlay()
            }
            if store.offlineEarnings > 0 {
                OfflineEarningsPopup()
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Spacer()
                SeasonBanner()
                Spacer()
            }
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            GoalProgressBar(showUpgrades: $showUpgrades)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showUpgrades) {
            UpgradeSheet(isPresented: $showUpgrades)
                .environmentObject(store)
        }
        .onAppear {
            store.applyOfflineEarnings()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                store.recordBackground()
                NotificationManager.scheduleStallFullNotification()
            case .active:
                NotificationManager.cancelAll()
            default:
                break
            }
        }
    }
}
