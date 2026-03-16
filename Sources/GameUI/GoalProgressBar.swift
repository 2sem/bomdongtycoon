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
            HStack(spacing: 10) {
                goalContent
                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var goalContent: some View {
        if let next = EarningsSystem.nextGoalUpgrade(for: store.stall) {
            let coins = store.stall.coins
            let cost = next.coinCost
            let ready = coins >= cost
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(ready ? "✅" : "🎯")
                        .font(.caption)
                    Text("\(next.name)까지")
                        .font(.caption.bold())
                }
                ProgressView(value: min(coins, cost), total: max(cost, 1))
                    .tint(ready ? .green : .orange)
                    .frame(maxWidth: .infinity)
                Text("💰 \(Int(coins)) / \(Int(cost))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("🎉 모든 업그레이드 완료!")
                .font(.caption.bold())
                .foregroundStyle(.green)
        }
    }
}
