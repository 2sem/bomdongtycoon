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
                    currentTier: store.stall.menuTier + 1
                )
                upgradeSection(
                    title: "직원 고용",
                    type: .staff,
                    definitions: UpgradeDefinitions.staff,
                    currentTier: store.stall.staffTier
                )
                workerSection
                upgradeSection(
                    title: "가게 업그레이드",
                    type: .stall,
                    definitions: UpgradeDefinitions.stall,
                    currentTier: store.stall.stallTier + 1
                )
                upgradeSection(
                    title: "위치 이전",
                    type: .location,
                    definitions: UpgradeDefinitions.location,
                    currentTier: store.stall.locationTier + 1
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

    private var workerSection: some View {
        Section("직원 배치") {
            workerRow(label: "농장", icon: "leaf",
                      count: store.stall.farmWorkers,
                      onMinus: { store.assignWorkerToShop() },
                      minusDisabled: store.stall.farmWorkers == 0,
                      onPlus:  { store.assignWorkerToFarm() },
                      plusDisabled:  store.stall.shopWorkers == 0)
            workerRow(label: "가게", icon: "storefront",
                      count: store.stall.shopWorkers,
                      onMinus: { store.assignWorkerToFarm() },
                      minusDisabled: store.stall.shopWorkers == 0,
                      onPlus:  { store.assignWorkerToShop() },
                      plusDisabled:  store.stall.farmWorkers == 0)
            if store.stall.staffTier == 0 {
                Text("직원을 고용하면 배치할 수 있어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func workerRow(label: String, icon: String,
                           count: Int,
                           onMinus: @escaping () -> Void, minusDisabled: Bool,
                           onPlus:  @escaping () -> Void, plusDisabled: Bool) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Button("-", action: onMinus)
                .disabled(minusDisabled)
                .sensoryFeedback(.impact(weight: .light), trigger: count)
            Text("\(count)").frame(width: 28)
            Button("+", action: onPlus)
                .disabled(plusDisabled)
                .sensoryFeedback(.impact(weight: .light), trigger: count)
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
                Text(upgrade.name)
                    .font(.headline)
                Text(upgrade.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !effectText.isEmpty {
                    Text(effectText)
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
                Text("₩\(Int(upgrade.coinCost))")
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
