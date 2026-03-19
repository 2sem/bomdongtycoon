import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var rewardAd: SwiftUIRewardAdManager
    @Environment(\.scenePhase) var scenePhase
    @State private var showUpgrades = false
    @State private var showStaff = false
    @State private var showJob = false
    @State private var isFromBackground = false
    @State private var isLaunched = false

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
                    rewardAd.show(completion: completion)
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
        .onAppear {
            // Cold start (terminated → active): view appears once, scene already active
            if !isLaunched && !isFromBackground {
                store.calculateOfflineEarnings()
                isLaunched = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                isFromBackground = true
                store.recordBackground()
                NotificationManager.scheduleStallFullNotification()
            case .active:
                NotificationManager.cancelAll()
                if isFromBackground {
                    // Background resume: do not recalculate offline earnings
                    isFromBackground = false
                }
            default:
                break
            }
        }
    }
}
