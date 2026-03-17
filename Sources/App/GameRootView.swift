import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.scenePhase) var scenePhase
    @State private var showUpgrades = false
    @State private var showStaff = false

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
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                CoinBadge()
                Spacer()
                RatingBadge()
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
        .sheet(isPresented: $showStaff) {
            StaffSheet(isPresented: $showStaff)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStaffSheet)) { _ in
            showStaff = true
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
