import SwiftUI
import GameCore

public struct GoalProgressBar: View {
    @EnvironmentObject var store: GameStore
    @Binding public var showUpgrades: Bool
    @Binding public var showStaff: Bool
    @Binding public var staffTab: StaffTab

    public init(showUpgrades: Binding<Bool>, showStaff: Binding<Bool>, staffTab: Binding<StaffTab>) {
        self._showUpgrades = showUpgrades
        self._showStaff = showStaff
        self._staffTab = staffTab
    }

    public var body: some View {
        if let text = EarningsSystem.locationGoalText(for: store.stall) {
            let ready = EarningsSystem.nextLocationUnlocked(for: store.stall)
                && store.stall.coins >= (EarningsSystem.nextLocation(for: store.stall)?.coinCost ?? .infinity)
            Button { showUpgrades = true } label: {
                capsule(icon: ready ? "checkmark.circle.fill" : "arrow.up.circle", ready: ready, text: text)
            }
            .buttonStyle(.plain)
        } else if let next = EarningsSystem.nextGoalUpgrade(for: store.stall) {
            let isStaff = EarningsSystem.nextGoalType(for: store.stall) == .staff
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
                    text: isStaff ? String(localized: "고용하기") : String(localized: "업그레이드")
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: String(localized: "다음 목표, %@, %@ 코인"), next.name, CoinFormat.string(next.coinCost)))
            .accessibilityHint(isStaff
                ? String(localized: "탭하면 고용 화면을 엽니다")
                : String(localized: "탭하면 업그레이드 화면을 엽니다"))
        }
    }

    private func capsule(icon: String, ready: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(ready ? .green : .primary)
                .font(.caption)
            Text(text)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
}
