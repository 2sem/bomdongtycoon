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
            // goals, so the sheet mentions them instead of this capsule waiting on them.
            let text = String(
                format: String(localized: "prestige.goal"),
                PrestigeSystem.multiplierNumber(
                    PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount + 1)))
            Button { showPrestige = true } label: {
                // The full text does not fit beside the coin and rating badges on a phone; the
                // compact form is just the name, so the capsule never collapses to its icon.
                capsule(icon: "checkmark.circle.fill", ready: true, text: text,
                        compactText: String(localized: "prestige.title"))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text)
            .accessibilityHint(String(localized: "prestige.goal.hint"))
        } else if let text = EarningsSystem.locationGoalText(for: store.stall) {
            let ready = EarningsSystem.nextLocationUnlocked(for: store.stall)
                && store.stall.coins >= (EarningsSystem.nextLocation(for: store.stall)?.coinCost ?? .infinity)
            Button { showUpgrades = true } label: {
                capsule(icon: ready ? "checkmark.circle.fill" : "arrow.up.circle", ready: ready, text: text,
                        compactText: EarningsSystem.locationGoalCompactText(for: store.stall))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(text)
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
                capsule(
                    icon: isStaff ? "person.badge.plus" : (ready ? "checkmark.circle.fill" : "arrow.up.circle"),
                    ready: ready,
                    text: Self.text(for: label)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(
                format: String(localized: "다음 목표, %@, %@ 코인"),
                label == .warehouse ? String(localized: "창고 확장") : next.name,
                CoinFormat.string(next.coinCost)))
            .accessibilityHint(isStaff
                ? String(localized: "탭하면 고용 화면을 엽니다")
                : String(localized: "탭하면 업그레이드 화면을 엽니다"))
        }
    }

    private static func text(for label: GoalLabel?) -> String {
        switch label {
        case .hire: String(localized: "고용하기")
        case .warehouse: String(localized: "창고 확장")
        case .upgrade, nil: String(localized: "업그레이드")
        }
    }

    private func capsule(icon: String, ready: Bool, text: String, compactText: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(ready ? .green : .primary)
                .font(.caption)
            ViewThatFits(in: .horizontal) {
                label(text).fixedSize(horizontal: true, vertical: false)
                label(compactText ?? text).minimumScaleFactor(0.75)
            }
            Image(systemName: "chevron.up")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 44)
        .background(.ultraThinMaterial, in: Capsule())
        .contentShape(Capsule())
    }

    private func label(_ string: String) -> some View {
        Text(string).font(.caption.bold()).lineLimit(1)
    }
}
