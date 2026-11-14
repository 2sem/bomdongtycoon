import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var adManager: SwiftUIAdManager
    @EnvironmentObject var ads: RewardedAds
    @State private var showUpgrades = false
    @State private var showStaff = false
    @State private var showStats = false
    @State private var showPrestige = false
    @State private var showMissions = false
    @State private var staffTab: StaffTab = .assign
    @State private var coinTarget: CGPoint?
    @State private var locationToast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var showFeverPointer = false
    @State private var lastGoldenToast: Date?
    @State private var isAlertUp = false
    @State private var showBoostOffer = false
    @State private var showGiftOffer = false
    @State private var showFeverOffer = false
    @State private var showMissionPointer = false
    @State private var missionToastGate = CooldownGate(interval: 30)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            GameSceneView(bottomReserve: 0, coinTarget: coinTarget, isStorefrontHeld: isStorefrontHeld)
            if store.progress.isFirstLaunch {
                TutorialOverlay()
            } else if !store.progress.isShopNameSet {
                ShopNameOverlay()
            }
            if store.offlineEarnings > 0 {
                OfflineEarningsPopup { completion in
                    adManager.showRewarded(.offline, completion: completion)
                }
            }
            adOffers
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HUDView(showUpgrades: $showUpgrades, showStaff: $showStaff, staffTab: $staffTab,
                    showPrestige: $showPrestige, showStats: $showStats,
                    showsBoostChip: !isIntroOverlayUp,
                    boostIsPulsing: pulsingSurface == .boost,
                    onBoostTap: { showBoostOffer = true }) { coinTarget = $0 }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Spacer()
                    if !isIntroOverlayUp { FeverAdButton(isPulsing: pulsingSurface == .fever) { showFeverOffer = true } }
                    FeverButton()
                        .overlay(alignment: .top) {
                            if showFeverPointer { HintArrowView().offset(y: -32) }
                        }
                }
                // Fixed height: the charging, ready and active forms differ by a point, and the scene
                // rebuilds the whole world (customers, tips, pops) whenever the bottom inset moves.
                .frame(height: FeverButton.slotHeight, alignment: .bottom)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                DotTabBar(
                    onUpgrades: { showUpgrades = true },
                    onStaff: { staffTab = .assign; showStaff = true },
                    onMissions: { showMissionPointer = false; showMissions = true },
                    onStats: { showStats = true })
                    .overlay(alignment: .topLeading) {
                        if showMissionPointer {
                            // The mission tab is the third of four equal columns (0.5-0.75); the arrow leans right of its
                            // centre so it stays off the AD recharge button.
                            GeometryReader { proxy in
                                HintArrowView(pixel: 3).position(x: proxy.size.width * 0.68, y: -12)
                            }
                        }
                    }
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
            openDebugSheet()
        }
        .onChange(of: isIntroOverlayUp) { _, isUp in
            store.isSimulationPaused = isUp
        }
        .onChange(of: store.unclaimedCompletedMissionCount) { old, new in
            guard new > old, !isIntroOverlayUp else { return }
            announceMissionDone()
        }
        .onChange(of: store.isFeverReady) { _, isReady in
            guard isReady, !isIntroOverlayUp, !FirstRunHint.fever.isDone else { return }
            FirstRunHint.fever.markDone()
            showFeverPointer = true
            showToast(String(format: String(localized: "dot.fever.firstReady"), Int(FeverSystem.duration)),
                      announcement: String(format: String(localized: "dot.fever.firstReady"), Int(FeverSystem.duration)))
        }
        // The pointer only makes sense while the button says FEVER!: the gauge decays if it is ignored.
        .onChange(of: store.isFeverReady) { _, isReady in
            if !isReady { showFeverPointer = false }
        }
        .onChange(of: store.isFeverAdAvailable) { _, isAvailable in
            if !isAvailable { showFeverOffer = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .goldenPlotRipened)) { _ in
            showGoldenToast()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestHUDToast)) { note in
            guard !isIntroOverlayUp, let text = note.userInfo?["text"] as? String else { return }
            showToast(text, announcement: (note.userInfo?["announce"] as? String) ?? text)
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestGiftOffer)) { _ in
            guard store.isGiftPresent, !isIntroOverlayUp else { return }
            store.isGiftHeld = true
            showGiftOffer = true
        }
        .modifier(AddFarmPlotConfirmation())
        .modifier(ExpandWarehouseConfirmation())
        .onPreferenceChange(AlertUpKey.self) { isAlertUp = $0 }
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

    private static let goldenToastCooldown: TimeInterval = 45

    private func showGoldenToast() {
        guard !isIntroOverlayUp else { return }
        if let last = lastGoldenToast, Date().timeIntervalSince(last) < Self.goldenToastCooldown { return }
        lastGoldenToast = Date()
        let text = String(localized: "dot.toast.golden")
        showToast(text, announcement: text)
    }

    private var isStorefrontHeld: Bool {
        showUpgrades || showStaff || showStats || showPrestige || showMissions || isAlertUp
            || showBoostOffer || showGiftOffer || showFeverOffer
    }

    // MARK: Rewarded offers

    /// The one rewarded prompt allowed to animate: the crate first (it animates in the scene), then the
    /// boost chip, then the fever recharge.
    private var pulsingSurface: AdPromptSurface? {
        guard !isIntroOverlayUp, !showBoostOffer, !showGiftOffer, !showFeverOffer else { return nil }
        return AdPromptSurface.active(
            giftPresent: store.isGiftPresent,
            boostAvailable: store.isBoostAvailable && ads.isReady(.boost),
            feverAdAvailable: store.isFeverAdAvailable && ads.isReady(.fever))
    }

    @ViewBuilder
    private var adOffers: some View {
        if showBoostOffer, store.isBoostAvailable {
            AdOfferDialog(
                title: String(localized: "dot.boost.title"),
                message: String(format: String(localized: "dot.boost.message"), Int(AdBoostSystem.boostDuration / 60)),
                actionTitle: String(localized: "dot.boost.action"),
                isReady: ads.isReady(.boost),
                onWatch: {
                    ads.watch(.boost) {
                        if store.claimBoost() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                        showBoostOffer = false
                    }
                },
                onClose: { showBoostOffer = false })
                .onAppear { ads.prepare(.boost) }
        }
        if showFeverOffer, store.isFeverAdAvailable {
            AdOfferDialog(
                title: String(localized: "dot.fever.offer.title"),
                message: String(localized: "dot.fever.offer.message"),
                actionTitle: String(localized: "dot.fever.offer.action"),
                isReady: ads.isReady(.fever),
                onWatch: {
                    ads.watch(.fever) {
                        if store.claimFeverAdCharge() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                        showFeverOffer = false
                    }
                },
                onClose: {
                    store.declineFeverAd()
                    showFeverOffer = false
                })
                .onAppear { ads.prepare(.fever) }
        }
        if showGiftOffer {
            AdOfferDialog(
                title: String(localized: "dot.gift.title"),
                message: String(format: String(localized: "dot.gift.message"), CoinFormat.string(store.giftAmount)),
                actionTitle: String(localized: "dot.gift.action"),
                isReady: ads.isReady(.gift),
                onWatch: {
                    ads.watch(.gift) {
                        if store.claimGift() != nil { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                        closeGiftOffer()
                    }
                },
                onClose: closeGiftOffer)
                .onAppear { ads.prepare(.gift) }
        }
    }

    private func closeGiftOffer() {
        showGiftOffer = false
        store.isGiftHeld = false
    }

    // MARK: Mission announcement

    private static let missionPointerKey = "dot.hint.missionPointerCount"
    private static let missionPointerLimit = 3

    private func announceMissionDone() {
        if missionToastGate.fire(now: Date()) {
            let text = String(localized: "dot.mission.announce")
            showToast(text, announcement: text)
            DotSound.shared.play(.missionDone)
        }
        let shown = UserDefaults.standard.integer(forKey: Self.missionPointerKey)
        guard !showMissions, shown < Self.missionPointerLimit else { return }
        UserDefaults.standard.set(shown + 1, forKey: Self.missionPointerKey)
        showMissionPointer = true
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

/// Set by the confirmation alerts so the storefront holds while one is open.
struct AlertUpKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
