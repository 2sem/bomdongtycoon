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
                    title: "메뉴 업그레이드",
                    type: .menu,
                    definitions: UpgradeDefinitions.menu,
                    currentTier: store.stall.menuTier
                )
                upgradeSection(
                    title: "직원 고용",
                    type: .staff,
                    definitions: UpgradeDefinitions.staff,
                    currentTier: store.stall.staffTier
                )
                upgradeSection(
                    title: "가게 업그레이드",
                    type: .stall,
                    definitions: UpgradeDefinitions.stall,
                    currentTier: store.stall.stallTier
                )
                upgradeSection(
                    title: "위치 이전",
                    type: .location,
                    definitions: UpgradeDefinitions.location,
                    currentTier: store.stall.locationTier
                )
            }
            .navigationTitle("💰 업그레이드")
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
}

// MARK: - UpgradeRowView

private struct UpgradeRowView: View {
    let upgrade: UpgradeDefinition
    let isOwned: Bool
    let isNext: Bool
    let canAfford: Bool
    let onPurchase: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(upgrade.name)
                    .font(.headline)
                Text(upgrade.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !upgrade.displayEffect.isEmpty {
                    Text(upgrade.displayEffect)
                        .font(.caption2)
                        .foregroundStyle(.green)
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
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else if isNext {
            Button {
                onPurchase()
            } label: {
                Text("💰 \(Int(upgrade.coinCost))")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(canAfford ? .orange : .gray)
            .disabled(!canAfford)
        } else {
            Image(systemName: "lock.fill")
                .foregroundStyle(.tertiary)
        }
    }
}
