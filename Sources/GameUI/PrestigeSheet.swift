import SwiftUI
import GameCore

/// "새봄 맞이": what the reset costs, what it pays, and the only way to commit to it. The sheet
/// itself changes nothing; the state is replaced by `GameStore.startNewRun()`, reachable only
/// through the confirmation alert.
public struct PrestigeSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool
    /// Called after the run was replaced, so the owner can close every sheet above the shop.
    private let onStarted: () -> Void
    @State private var isConfirming = false
    /// The confirm was refused because an offline-earnings popup arrived under the open alert.
    @State private var isRefused = false

    public init(isPresented: Binding<Bool>, onStarted: @escaping () -> Void = {}) {
        self._isPresented = isPresented
        self.onStarted = onStarted
    }

    private var progress: PlayerProgress { store.progress }
    private var currentCount: Int { progress.prestigeCount }

    public var body: some View {
        DotSheet(title: String(localized: "prestige.title"), onClose: { isPresented = false }) {
            VStack(spacing: 0) {
                DotScroll {
                    rewardSection
                    losesSection
                    keepsSection
                    runSection
                    if PrestigeSystem.hasUnspentPlots(farm: store.farm) { unspentPlotsSection }
                }
                ctaBar
            }
        }
        .alert(
            String(localized: "prestige.alert.title"),
            isPresented: $isConfirming
        ) {
            Button(String(localized: "prestige.alert.confirm"), role: .destructive) { startNewRun() }
            Button(String(localized: "prestige.alert.cancel"), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "prestige.alert.message"),
                        CoinFormat.string(store.stall.coins)))
        }
        .alert(String(localized: "prestige.title"), isPresented: $isRefused) {
            Button(String(localized: "확인"), role: .cancel) {}
        } message: {
            Text(String(localized: "prestige.pending"))
        }
    }

    // MARK: Sections

    private var rewardSection: some View {
        let current = PrestigeSystem.legacyMultiplier(prestigeCount: currentCount)
        let next = PrestigeSystem.legacyMultiplier(prestigeCount: currentCount + 1)
        let gain = String(
            format: String(localized: "dot.prestige.gain"),
            PrestigeSystem.multiplierNumber(current),
            PrestigeSystem.multiplierNumber(next))
        let lastSpring = String(
            format: String(localized: "dot.prestige.lastSpring"),
            StatsSheet.durationText(progress.runPlaySeconds))
        let startCoins = String(
            format: String(localized: "dot.prestige.startCoins"),
            CoinFormat.string(PrestigeSystem.startingCoins(prestigeCount: currentCount + 1)))
        return HStack(alignment: .top, spacing: 10) {
            DotImage("dot_ui_star", scale: 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(gain).dotText(.title, color: DotPalette.leafDark).monospacedDigit()
                Text(String(localized: "prestige.reward")).dotText(.caption, color: DotPalette.textSecondary)
                Text(lastSpring).dotText(.bold)
                HStack(spacing: 4) {
                    DotImage("dot_ui_coin", scale: 1)
                    Text(startCoins).dotText(.bold, color: DotPalette.goldDark)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .dotPanel()
        .accessibilityElement(children: .combine)
    }

    private var losesSection: some View {
        group(String(localized: "prestige.loses")) {
            line("dot_ui_coin", String(format: String(localized: "prestige.loses.coins"), CoinFormat.string(store.stall.coins)))
            line("dot_ui_upgrade", String(localized: "prestige.loses.shop"))
            line("dot_ui_staff", String(localized: "prestige.loses.rest"))
        }
    }

    private var keepsSection: some View {
        group(String(localized: "prestige.keeps")) {
            line("dot_ui_check", String(localized: "prestige.keeps.items"))
        }
    }

    private var runSection: some View {
        group(String(localized: "stats.section.run")) {
            statLine(String(localized: "stats.run.duration"), StatsSheet.durationText(progress.runPlaySeconds))
            statLine(String(localized: "stats.run.earned"), CoinFormat.string(progress.runEarned))
        }
    }

    private var unspentPlotsSection: some View {
        DotHint(icon: "dot_ui_seed", text: String(localized: "prestige.unspentPlots"), color: DotPalette.soilDark)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DotSectionHeader(title)
            VStack(alignment: .leading, spacing: 6, content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dotPanel()
        }
    }

    private func line(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            DotImage(icon, scale: 1)
            Text(text).dotText(.body).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func statLine(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).dotText(.body)
            Spacer(minLength: 4)
            Text(value).dotText(.bold).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Commit

    private var ctaBar: some View {
        VStack(spacing: 6) {
            Button { isConfirming = true } label: {
                Text(String(localized: "prestige.cta")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.dot)
            .disabled(!store.canStartNewRun)
            if store.offlineEarnings > 0 {
                Text(String(localized: "prestige.pending"))
                    .dotText(.caption, color: DotPalette.soilDark)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DotPalette.sand)
    }

    private func startNewRun() {
        guard store.startNewRun() else {
            isRefused = true
            return
        }
        onStarted()
    }
}
