import SwiftUI
import GameCore

/// Floating [+] button that adds one more farm plot.
public struct FarmUpgradeButton: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    private var nextCost: Double? {
        FarmSystem.costForNextPlot(currentCount: store.farm.plots.count)
    }

    public var body: some View {
        if let cost = nextCost {
            let canAfford = store.stall.coins >= cost
            Button {
                store.purchaseUpgrade(.farm)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(canAfford ? .green : .secondary)
                        .font(.body)
                    Text("🪙\(Int(cost))")
                        .font(.caption.bold())
                        .foregroundStyle(canAfford ? .primary : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
    }
}
