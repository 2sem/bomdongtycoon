import SwiftUI
import GameCore

public struct GoalProgressBar: View {
    @EnvironmentObject var store: GameStore
    @Binding public var showUpgrades: Bool

    public init(showUpgrades: Binding<Bool>) {
        self._showUpgrades = showUpgrades
    }

    public var body: some View {
        Button { showUpgrades = true } label: {
            HStack(spacing: 6) {
                goalContent
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

    @ViewBuilder
    private var goalContent: some View {
        if let next = EarningsSystem.nextGoalUpgrade(for: store.stall) {
            let ready = store.stall.coins >= next.coinCost
            HStack(spacing: 4) {
                Image(systemName: ready ? "checkmark.circle.fill" : "arrow.up.circle")
                    .foregroundStyle(ready ? .green : .primary)
                    .font(.caption)
                Text("업그레이드")
                    .font(.caption.bold())
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text("완료").font(.caption.bold()).foregroundStyle(.green)
            }
        }
    }
}
