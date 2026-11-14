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
    @State private var showMissions = false
    @State private var staffTab: StaffTab = .assign
    @State private var coinTarget: CGPoint?
    @State private var locationToast: String?
    @State private var toastTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GameSceneView(bottomReserve: 6, coinTarget: coinTarget)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            HUDView(showUpgrades: $showUpgrades, showStaff: $showStaff, staffTab: $staffTab,
                    showPrestige: $showPrestige, showStats: $showStats) { coinTarget = $0 }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    FeverButton()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                DotTabBar(
                    onUpgrades: { showUpgrades = true },
                    onStaff: { staffTab = .assign; showStaff = true },
                    onMissions: { showMissions = true },
                    onStats: { showStats = true })
            }
        }
        .environment(\.dotPlaySound, { DotSound.shared.play($0.effect) })
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
        }
        .sheet(isPresented: $showMissions) {
            MissionsSheet(isPresented: $showMissions)
                .environmentObject(store)
        }
        .sheet(isPresented: $showStaff) {
            StaffSheet(isPresented: $showStaff, tab: $staffTab)
                .environmentObject(store)
        }
        .onAppear {
            store.isSimulationPaused = isIntroOverlayUp
            if store.progress.isShopNameSet { NotificationManager.requestPermissionIfUndetermined() }
            openDebugSheet()
        }
        .onChange(of: isIntroOverlayUp) { _, isUp in
            store.isSimulationPaused = isUp
        }
        .onChange(of: store.progress.isShopNameSet) { _, isSet in
            if isSet { NotificationManager.requestPermissionIfUndetermined() }
        }
        .modifier(AddFarmPlotConfirmation())
        .modifier(ExpandWarehouseConfirmation())
        .overlay(alignment: .top) {
            if let toast = locationToast {
                DotToast(text: toast)
                    .padding(.top, 96)
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

    /// `-dotSheet` (DEBUG): opens one screen straight away so it can be screenshot.
    private func openDebugSheet() {
        switch DotDebug.sheet {
        case "upgrades": showUpgrades = true
        case "staff": showStaff = true
        case "hire": staffTab = .hire; showStaff = true
        case "missions": showMissions = true
        case "stats": showStats = true
        case "prestige": showPrestige = true
        default: break
        }
    }

    private var isIntroOverlayUp: Bool {
        store.progress.isFirstLaunch || !store.progress.isShopNameSet
    }

    /// Shown once the scene has faded back in (see
    /// `.locationTransitionDidFinish`), held 2.5 s, then dismissed. The
    /// spec's VoiceOver line is announced with it.
    private func showLocationToast(forTier tier: Int) {
        guard UpgradeDefinitions.location.indices.contains(tier) else { return }
        let location = UpgradeDefinitions.location[tier]
        let multiplier = Int(location.saleMultiplier)
        showToast(
            String(format: String(localized: "dot.toast.moved"), location.destination, multiplier),
            announcement: String(format: String(localized: "dot.toast.moved.accessibility"),
                                 location.destination, multiplier))
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

private struct DotToast: View {
    let text: String

    var body: some View {
        Text(text)
            .dotText(.bold, color: DotPalette.paper, shadow: true)
            .multilineTextAlignment(.center)
            .dotPanel(.dark, padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            .accessibilityHidden(true) // announced separately on appearance
    }
}

private extension DotSoundEffect {
    var effect: DotSound.Effect {
        switch self {
        case .tap: .tap
        case .purchase: .purchase
        case .error: .error
        case .missionDone: .missionDone
        case .feverStart: .feverStart
        }
    }
}
