import SwiftUI
import GameCore

/// Floating button that sits above the farm strip.
/// Shows the next farm upgrade and lets the player buy it with one tap.
public struct FarmUpgradeButton: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    private var nextTierIndex: Int { store.farm.upgradeTier + 1 }
    private var nextDef: FarmUpgradeDefinition? {
        guard nextTierIndex < UpgradeDefinitions.farm.count else { return nil }
        return UpgradeDefinitions.farm[nextTierIndex]
    }

    public var body: some View {
        if let def = nextDef {
            let canAfford = store.stall.coins >= def.coinCost
            Button {
                store.purchaseUpgrade(.farm)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(canAfford ? .green : .secondary)
                    Text(def.name)
                        .font(.caption.bold())
                    Text("🪙\(Int(def.coinCost))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAfford)
        }
    }
}
