import SwiftUI
import GameCore

/// The top HUD: coins, rating, goal, then the shop status strip and the rain chip.
public struct HUDView: View {
    @Binding var showUpgrades: Bool
    @Binding var showStaff: Bool
    @Binding var staffTab: StaffTab
    @Binding var showPrestige: Bool
    @Binding var showStats: Bool
    let onCoinCenterChange: (CGPoint) -> Void
    let showsBoostChip: Bool
    let boostIsPulsing: Bool
    let onBoostTap: () -> Void
    let showsRenewalChip: Bool
    let onRenewalTap: () -> Void
    @EnvironmentObject private var store: GameStore

    public init(showUpgrades: Binding<Bool>, showStaff: Binding<Bool>, staffTab: Binding<StaffTab>,
                showPrestige: Binding<Bool>, showStats: Binding<Bool>,
                showsBoostChip: Bool = false, boostIsPulsing: Bool = false, onBoostTap: @escaping () -> Void = {},
                showsRenewalChip: Bool = false, onRenewalTap: @escaping () -> Void = {},
                onCoinCenterChange: @escaping (CGPoint) -> Void) {
        self.showsBoostChip = showsBoostChip
        self.boostIsPulsing = boostIsPulsing
        self.onBoostTap = onBoostTap
        self.showsRenewalChip = showsRenewalChip
        self.onRenewalTap = onRenewalTap
        self._showUpgrades = showUpgrades
        self._showStaff = showStaff
        self._staffTab = staffTab
        self._showPrestige = showPrestige
        self._showStats = showStats
        self.onCoinCenterChange = onCoinCenterChange
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The goal pill is the only flexible item, so it is what shrinks to its compact text.
            HStack(alignment: .center, spacing: 6) {
                CoinBadge(onCenterChange: onCoinCenterChange).fixedSize()
                ratingButton
                if showsRenewalChip, store.isRenewalAvailable { RenewalChip(onTap: onRenewalTap) }
                LegacyChip()
                Spacer(minLength: 0)
                GoalProgressBar(showUpgrades: $showUpgrades, showStaff: $showStaff, staffTab: $staffTab,
                                showPrestige: $showPrestige)
            }
            HStack(alignment: .top, spacing: 6) {
                ShopStatusStrip()
                WeatherChip().fixedSize()
                RushChip()
                if showsBoostChip {
                    BoostChip(isPulsing: boostIsPulsing, onTap: onBoostTap).fixedSize()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    /// The 44 pt frame is the tap target only: the row is already 44 pt tall (goal pill).
    private var ratingButton: some View {
        Button { showStats = true } label: {
            RatingBadge()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(String(format: String(localized: "stats.rating.accessibility"),
                                   String(format: "%.1f", store.progress.rating)))
        .accessibilityHint(String(localized: "stats.rating.hint"))
    }
}
