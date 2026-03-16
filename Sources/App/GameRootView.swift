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
            } else if !store.progress.isShopNameSet {
                ShopNameOverlay()
            }
            if store.offlineEarnings > 0 {
                OfflineEarningsPopup()
            }
            // Farm upgrade button — floats just above the farm soil strip
            VStack {
                Spacer()
                FarmUpgradeButton()
                    .environmentObject(store)
                    .padding(.bottom, 78)  // clears the ~70pt soil strip
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                SeasonBanner()
                Spacer()
                GoalProgressBar(showUpgrades: $showUpgrades)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
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
