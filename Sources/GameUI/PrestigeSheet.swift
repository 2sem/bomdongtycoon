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
        NavigationStack {
            List {
                rewardSection
                losesSection
                keepsSection
                runSection
                if PrestigeSystem.hasUnspentPlots(farm: store.farm) { unspentPlotsSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "prestige.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "닫기")) { isPresented = false }
                }
            }
            .safeAreaInset(edge: .bottom) { ctaBar }
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
        }
        .alert(String(localized: "prestige.title"), isPresented: $isRefused) {
            Button(String(localized: "확인"), role: .cancel) {}
        } message: {
            Text(String(localized: "prestige.pending"))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var rewardSection: some View {
        let current = PrestigeSystem.legacyMultiplier(prestigeCount: currentCount)
        let next = PrestigeSystem.legacyMultiplier(prestigeCount: currentCount + 1)
        let line = String(
            format: String(localized: "prestige.multiplier"),
            PrestigeSystem.multiplierNumber(current),
            PrestigeSystem.multiplierNumber(next),
            PrestigeSystem.multiplierNumber(next - current))
        return Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(line)
                    .font(.headline)
                    .monospacedDigit()
                Text(String(localized: "prestige.reward"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var losesSection: some View {
        Section(String(localized: "prestige.loses")) {
            Label(String(format: String(localized: "prestige.loses.coins"), CoinFormat.string(store.stall.coins)),
                  systemImage: "wonsign.circle")
            Label(String(localized: "prestige.loses.shop"), systemImage: "storefront")
            Label(String(localized: "prestige.loses.rest"), systemImage: "person.2")
        }
    }

    private var keepsSection: some View {
        Section(String(localized: "prestige.keeps")) {
            Label(String(localized: "prestige.keeps.items"), systemImage: "checkmark.seal")
        }
    }

    private var runSection: some View {
        Section(String(localized: "stats.section.run")) {
            LabeledContent(String(localized: "stats.run.duration")) {
                Text(StatsSheet.durationText(progress.runPlaySeconds)).monospacedDigit()
            }
            LabeledContent(String(localized: "stats.run.earned")) {
                Text(CoinFormat.string(progress.runEarned)).monospacedDigit()
            }
        }
    }

    private var unspentPlotsSection: some View {
        Section {
            Label(String(localized: "prestige.unspentPlots"), systemImage: "info.circle")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Commit

    private var ctaBar: some View {
        VStack(spacing: 6) {
            Button { isConfirming = true } label: {
                Text(String(localized: "prestige.cta"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(!store.canStartNewRun)
            if store.offlineEarnings > 0 {
                Text(String(localized: "prestige.pending"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func startNewRun() {
        guard store.startNewRun() else {
            isRefused = true
            return
        }
        onStarted()
    }
}
