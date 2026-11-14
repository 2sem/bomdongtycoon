import SwiftUI
import GameCore

public struct GoalProgressBar: View {
    @EnvironmentObject var store: GameStore
    @Binding public var showUpgrades: Bool
    @Binding public var showStaff: Bool
    @Binding public var staffTab: StaffTab
    @Binding public var showPrestige: Bool

    public init(showUpgrades: Binding<Bool>, showStaff: Binding<Bool>, staffTab: Binding<StaffTab>,
                showPrestige: Binding<Bool>) {
        self._showUpgrades = showUpgrades
        self._showStaff = showStaff
        self._staffTab = staffTab
        self._showPrestige = showPrestige
    }

    public var body: some View {
        if store.isPrestigeAvailable, EarningsSystem.nextGoalUpgrade(for: store.stall) == nil {
            // Nothing left to buy toward: the goal becomes the new spring. Leftover plots are not
            // goals, so the sheet mentions them instead of this pill waiting on them.
            let text = String(
                format: String(localized: "prestige.goal"),
                PrestigeSystem.multiplierNumber(
                    PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount + 1)))
            Button { showPrestige = true } label: {
                // The full text does not fit beside the coin and rating badges on a phone; the
                // compact form is just the name, so the pill never collapses to its icon.
                pill(icon: "dot_ui_check", ready: true, text: text,
                     compactText: String(localized: "prestige.title"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text)
            .accessibilityHint(String(localized: "prestige.goal.hint"))
        } else if EarningsSystem.locationGoalText(for: store.stall) != nil,
                  let next = EarningsSystem.nextLocation(for: store.stall) {
            let ready = EarningsSystem.nextLocationUnlocked(for: store.stall) && store.stall.coins >= next.coinCost
            let copy = locationCopy(next)
            Button { showUpgrades = true } label: {
                pill(icon: ready ? "dot_ui_check" : "dot_ui_upgrade", ready: ready, text: copy.full,
                     compactText: copy.compact)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.full)
        } else if let next = EarningsSystem.nextGoalUpgrade(for: store.stall) {
            let label = EarningsSystem.nextGoalLabel(for: store.stall)
            let isStaff = label == .hire
            let ready = store.stall.coins >= next.coinCost
            // Staff is bought in StaffSheet's hire tab; UpgradeSheet has nothing to buy for it.
            Button {
                if isStaff {
                    staffTab = .hire
                    showStaff = true
                } else {
                    showUpgrades = true
                }
            } label: {
                pill(
                    icon: ready ? "dot_ui_check" : (isStaff ? "dot_ui_staff" : "dot_ui_upgrade"),
                    ready: ready,
                    text: Self.text(for: label)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                format: String(localized: "다음 목표, %@, %@ 코인"),
                label == .warehouse ? String(localized: "창고 확장") : DotContent.loc(next.name),
                CoinFormat.string(next.coinCost)))
            .accessibilityHint(isStaff
                ? String(localized: "탭하면 고용 화면을 엽니다")
                : String(localized: "탭하면 업그레이드 화면을 엽니다"))
        }
    }

    /// The location goal in the player's language, built from the same facts `EarningsSystem` words in Korean.
    private func locationCopy(_ next: LocationDefinition) -> (full: String, compact: String) {
        let stall = store.stall
        let name = DotContent.loc(next.name)
        guard EarningsSystem.nextLocationUnlocked(for: stall) else {
            let needed = DotContent.loc(UpgradeDefinitions.stall[next.requiredStallTier].name)
            return (String(format: String(localized: "dot.goal.prepare"), needed, name),
                    String(format: String(localized: "dot.goal.prepare.short"), needed, name))
        }
        if stall.coins >= next.coinCost {
            let text = String(format: String(localized: "dot.goal.move.ready"), next.destination, name)
            return (text, text)
        }
        let coins = CoinFormat.string(stall.coins)
        let cost = CoinFormat.string(next.coinCost)
        return (String(format: String(localized: "dot.goal.progress"), coins, cost, name),
                String(format: String(localized: "dot.goal.progress.short"), coins, cost, name))
    }

    private static func text(for label: GoalLabel?) -> String {
        switch label {
        case .hire: String(localized: "고용하기")
        case .warehouse: String(localized: "창고 확장")
        case .upgrade, nil: String(localized: "업그레이드")
        }
    }

    /// Cream while the goal is out of reach, green once it can be bought.
    private func pill(icon: String, ready: Bool, text: String, compactText: String? = nil) -> some View {
        let textColor = ready ? DotPalette.paper : DotPalette.ink
        return HStack(spacing: 4) {
            DotImage(icon, scale: 1)
            ViewThatFits(in: .horizontal) {
                label(text, color: textColor).fixedSize(horizontal: true, vertical: false)
                label(compactText ?? text, color: textColor).minimumScaleFactor(0.75)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
        .background { DotNineSlice(name: ready ? "dot_ui_button" : "dot_ui_panel") }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func label(_ string: String, color: Color) -> some View {
        Text(string).dotText(.bold, color: color, shadow: color == DotPalette.paper).lineLimit(1)
    }
}
