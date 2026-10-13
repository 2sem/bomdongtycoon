import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var adManager: SwiftUIAdManager
    @State private var showUpgrades = false
    @State private var showStaff = false
    @State private var showStats = false
    @State private var showPrestige = false
    @State private var staffTab: StaffTab = .assign
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
                // Rating sits in the row, not overlaid on it: a centred overlay covered
                // the goal pill's text once the pill got long (39,530 / 40,000 at 440pt).
                // The pill is the only flexible item, so it is what truncates.
                HStack(alignment: .center, spacing: 8) {
                    CoinBadge().fixedSize()
                    ratingButton
                    Spacer(minLength: 0)
                    GoalProgressBar(showUpgrades: $showUpgrades, showStaff: $showStaff, staffTab: $staffTab,
                                    showPrestige: $showPrestige)
                }
                ShopStatusStrip()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showUpgrades) {
            UpgradeSheet(isPresented: $showUpgrades)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPrestige) {
            PrestigeSheet(isPresented: $showPrestige) { showPrestige = false }
                .environmentObject(store)
        }
        .sheet(isPresented: $showStats) {
            StatsSheet(isPresented: $showStats)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStaff) {
            StaffSheet(isPresented: $showStaff, tab: $staffTab)
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
        .onReceive(NotificationCenter.default.publisher(for: .newSpringDidFinish)) { _ in
            showNewSpringToast()
        }
    }

    private var isIntroOverlayUp: Bool {
        store.progress.isFirstLaunch || !store.progress.isShopNameSet
    }

    /// The rating badge opens the records sheet. The 44pt frame is the tap target only: the row
    /// is already 44pt tall (goal pill), so it adds no height.
    private var ratingButton: some View {
        Button { showStats = true } label: {
            RatingBadge()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(String(format: String(localized: "stats.rating.accessibility"),
                                   String(format: "%.1f", store.progress.rating)))
        .accessibilityHint(String(localized: "stats.rating.hint"))
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
        showToast(
            "\(emoji) \(location.destination) 이전했어요! 판매 수익 x\(multiplier)",
            announcement: "\(location.destination) 이전했습니다. 판매 수익 \(multiplier)배.")
    }

    /// The spring has been committed and the scene has faded back in: the success haptic, the toast
    /// and the VoiceOver line land together, on the new shop rather than under the black.
    private func showNewSpringToast() {
        let multiplier = PrestigeSystem.multiplierNumber(
            PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(
            String(format: String(localized: "prestige.toast"), multiplier),
            announcement: String(format: String(localized: "prestige.toast.accessibility"), multiplier))
    }

    private func showToast(_ text: String, announcement: String) {
        AccessibilityNotification.Announcement(announcement).post()

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
