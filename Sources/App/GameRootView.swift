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
                SeasonBanner()
                Spacer()
                GoalProgressBar(showUpgrades: $showUpgrades)
                staffButton
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

    private var staffButton: some View {
        Button { showStaff = true } label: {
            Label("직원 관리", systemImage: "person.2.fill")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule())
        .disabled(store.stall.staffCount == 0)
        .opacity(store.stall.staffCount == 0 ? 0.45 : 1)
    }
}
