import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var adManager: SwiftUIAdManager
    @State private var showUpgrades = false
    @State private var showStaff = false
    @State private var showJob = false

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
                OfflineEarningsPopup { completion in
                    adManager.showRewarded(completion: completion)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center) {
                CoinBadge()
                    .frame(maxWidth: .infinity, alignment: .leading)
                RatingBadge()
                GoalProgressBar(showUpgrades: $showUpgrades)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if store.stall.isShopOpen { store.closeShop() } else { store.openShop() }
            } label: {
                Text(store.stall.isShopOpen ? "🟢 영업 중" : "🔴 개업하기")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(store.stall.isShopOpen ? Color.green.opacity(0.85) : Color.orange.opacity(0.9))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 8)
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
        .sheet(isPresented: $showJob) {
            JobSheet(isPresented: $showJob)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStaffSheet)) { _ in
            showStaff = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openJobSheet)) { _ in
            showJob = true
        }
    }
}
