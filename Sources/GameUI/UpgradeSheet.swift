import SwiftUI
import GameCore

public struct UpgradeSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            List {
                upgradeSection(
                    title: "메뉴 추가",
                    type: .menu,
                    definitions: UpgradeDefinitions.menu,
                    currentTier: store.stall.menuTier + 1
                )
                upgradeSection(
                    title: "가게 업그레이드",
                    type: .stall,
                    definitions: UpgradeDefinitions.stall,
                    currentTier: store.stall.stallTier + 1
                )
            }
            .navigationTitle("업그레이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private func upgradeSection(
        title: String,
        type: UpgradeType,
        definitions: [UpgradeDefinition],
        currentTier: Int
    ) -> some View {
        let coins = store.stall.coins
        Section(title) {
            ForEach(definitions.indices, id: \.self) { index in
                UpgradeRowView(
                    upgrade: definitions[index],
                    isOwned: index < currentTier,
                    isNext: index == currentTier,
                    canAfford: coins >= definitions[index].coinCost,
                    onPurchase: { store.purchaseUpgrade(type) }
                )
            }
        }
    }

    private var farmWorkerSection: some View {
        let currentTier = store.stall.farmWorkerTier
        let coins = store.stall.coins
        return Section("농장 인력") {
            ForEach(UpgradeDefinitions.farmWorker.indices, id: \.self) { index in
                let def = UpgradeDefinitions.farmWorker[index]
                let isOwned = index < currentTier
                let isNext  = index == currentTier
                let effect  = index == 0
                    ? "자동 수확 · 속도 기본"
                    : "🌱 ×\(String(format: "%.1f", def.productionMultiplier)) 성장 속도"
                UpgradeRowView(
                    upgrade: def,
                    displayEffect: effect,
                    isOwned: isOwned,
                    isNext: isNext,
                    canAfford: coins >= def.coinCost,
                    onPurchase: { store.purchaseUpgrade(.farmWorker) }
                )
            }
        }
    }

}

// MARK: - UpgradeRowView

private struct UpgradeRowView: View {
    let upgrade: UpgradeDefinition
    var displayEffect: String? = nil
    let isOwned: Bool
    let isNext: Bool
    let canAfford: Bool
    let onPurchase: () -> Void

    private var effectText: String { displayEffect ?? upgrade.displayEffect }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.name).font(.headline)
                Text(upgrade.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !effectText.isEmpty {
                    Text(effectText)
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if let unlocks = upgrade.unlocks {
                    Text("🔓 \(unlocks)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            Spacer()
            trailingView
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isOwned {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if isNext {
            Button { onPurchase() } label: {
                Text("₩\(Int(upgrade.coinCost))").font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(canAfford ? .orange : .gray)
            .disabled(!canAfford)
        } else {
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
        }
    }
}
