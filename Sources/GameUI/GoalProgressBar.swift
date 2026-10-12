import SwiftUI
import GameCore

public struct GoalProgressBar: View {
    @EnvironmentObject var store: GameStore
    @Binding public var showUpgrades: Bool

    public init(showUpgrades: Binding<Bool>) {
        self._showUpgrades = showUpgrades
    }

    public var body: some View {
        if let text = EarningsSystem.locationGoalText(for: store.stall) {
            let ready = EarningsSystem.nextLocationUnlocked(for: store.stall)
                && store.stall.coins >= (EarningsSystem.nextLocation(for: store.stall)?.coinCost ?? .infinity)
            Button { showUpgrades = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "arrow.up.circle")
                        .foregroundStyle(ready ? .green : .primary)
                        .font(.caption)
                    Text(text)
                        .font(.caption.bold())
                    Image(systemName: "chevron.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        } else if let next = EarningsSystem.nextGoalUpgrade(for: store.stall) {
            let ready = store.stall.coins >= next.coinCost
            Button { showUpgrades = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: ready ? "checkmark.circle.fill" : "arrow.up.circle")
                        .foregroundStyle(ready ? .green : .primary)
                        .font(.caption)
                    Text(String(localized: "upgrade_button_label"))
                        .font(.caption.bold())
                    Image(systemName: "chevron.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
