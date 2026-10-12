import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var adManager: SwiftUIAdManager
    @State private var showUpgrades = false
    @State private var showStaff = false
    @State private var staffTab: StaffTab = .assign
    @State private var showJob = false
    @State private var locationToast: String?
    @State private var toastTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GameSceneView()
                .ignoresSafeArea()
            staffButton
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    CoinBadge()
                    Spacer()
                    GoalProgressBar(showUpgrades: $showUpgrades, showStaff: $showStaff, staffTab: $staffTab)
                }
                .overlay { RatingBadge() }
                ShopStatusStrip()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showUpgrades) {
            UpgradeSheet(isPresented: $showUpgrades)
                .environmentObject(store)
        }
        .sheet(isPresented: $showStaff) {
            StaffSheet(isPresented: $showStaff, tab: $staffTab)
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
        .onAppear {
            store.isSimulationPaused = isIntroOverlayUp
            if store.progress.isShopNameSet { NotificationManager.requestPermissionIfUndetermined() }
        }
        .onChange(of: isIntroOverlayUp) { _, isUp in
            store.isSimulationPaused = isUp
        }
        .onChange(of: store.progress.isShopNameSet) { _, isSet in
            if isSet { NotificationManager.requestPermissionIfUndetermined() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStaffSheet)) { _ in
            staffTab = .assign
            showStaff = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openJobSheet)) { _ in
            showJob = true
        }
        .modifier(AddFarmPlotConfirmation())
        .overlay(alignment: .top) {
            if let toast = locationToast {
                LocationToast(text: toast)
                    .padding(.top, 56)
                    .padding(.horizontal, 16)
                    .transition(reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .locationTransitionDidFinish)) { note in
            guard let tier = note.userInfo?["tier"] as? Int else { return }
            showLocationToast(forTier: tier)
        }
    }

    private var isIntroOverlayUp: Bool {
        store.progress.isFirstLaunch || !store.progress.isShopNameSet
    }

    private var staffButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    staffTab = .assign
                    showStaff = true
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel(String(localized: "직원 관리"))
            }
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }

    /// Shown once the scene has faded back in (see
    /// `.locationTransitionDidFinish`), held 2.5 s, then dismissed. The
    /// spec's VoiceOver line is announced with it.
    private func showLocationToast(forTier tier: Int) {
        guard UpgradeDefinitions.location.indices.contains(tier) else { return }
        let location = UpgradeDefinitions.location[tier]
        let multiplier = Int(location.saleMultiplier)
        let emoji = tier == 1 ? "🏪" : "🌆"
        let text = "\(emoji) \(location.destination) 이전했어요! 판매 수익 x\(multiplier)"

        AccessibilityNotification.Announcement(
            "\(location.destination) 이전했습니다. 판매 수익 \(multiplier)배."
        ).post()

        toastTask?.cancel()
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4)
        withAnimation(animation) { locationToast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { locationToast = nil }
        }
    }
}

private struct LocationToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .accessibilityHidden(true) // announced separately on appearance
    }
}
