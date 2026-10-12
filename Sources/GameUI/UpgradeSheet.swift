import SwiftUI
import UIKit
import GameCore

public struct UpgradeSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool
    @State private var pendingLocationTier: Int?
    @State private var pendingWarehouseCapacity: Int?

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
                locationSection
                warehouseSection
            }
            .alert(
                String(localized: "창고를 넓힐까요?"),
                isPresented: Binding(
                    get: { pendingWarehouseCapacity != nil },
                    set: { if !$0 { pendingWarehouseCapacity = nil } }
                )
            ) {
                Button(String(localized: "넓히기")) { confirmWarehouseExpansion() }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(warehouseAlertMessage)
            }
            .navigationTitle(String(localized: "업그레이드"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { pendingLocationTier != nil },
                    set: { if !$0 { pendingLocationTier = nil } }
                )
            ) {
                Button(String(localized: "이전하기")) { confirmLocationMove() }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "닫기")) { isPresented = false }
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

    // MARK: Location

    private var locationSection: some View {
        let current = store.stall.locationTier
        let stallTier = store.stall.stallTier
        let coins = store.stall.coins
        return Section {
            ForEach(UpgradeDefinitions.location.indices, id: \.self) { index in
                let def = UpgradeDefinitions.location[index]
                LocationRowView(
                    definition: def,
                    state: Self.locationState(
                        index: index, current: current,
                        stallTier: stallTier, coins: coins, definition: def),
                    onPurchase: { pendingLocationTier = index }
                )
            }
        } header: {
            Text("위치")
        } footer: {
            Text("이전해도 가게와 직원은 그대로 따라와요.")
        }
    }

    static func locationState(
        index: Int, current: Int, stallTier: Int, coins: Double, definition: LocationDefinition
    ) -> LocationRowState {
        if index == current { return .current }
        if index < current { return .past }
        if index > current + 1 { return .lockedQueue(previous: UpgradeDefinitions.location[index - 1].name) }
        if stallTier < definition.requiredStallTier { return .lockedPrerequisite }
        return coins >= definition.coinCost ? .affordable : .short
    }

    private var pendingLocation: LocationDefinition? {
        guard let tier = pendingLocationTier,
              UpgradeDefinitions.location.indices.contains(tier) else { return nil }
        return UpgradeDefinitions.location[tier]
    }

    private var alertTitle: String {
        guard let def = pendingLocation else { return "" }
        return "\(def.destination) 이전할까요?"
    }

    private var alertMessage: String {
        guard let def = pendingLocation else { return "" }
        return "💰 \(Self.formatted(def.coinCost))을 내고 이전하면 판매 수익이 \(Int(def.saleMultiplier))배가 돼요."
    }

    private func confirmLocationMove() {
        guard let tier = pendingLocationTier else { return }
        pendingLocationTier = nil
        // Re-check so a double-fire or stale alert cannot buy twice.
        guard tier == store.stall.locationTier + 1 else { return }
        store.purchaseUpgrade(.location)
        guard store.stall.locationTier == tier else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isPresented = false
    }

    // MARK: Warehouse

    private var warehouseSection: some View {
        let capacity = store.stall.warehouseCapacity
        let shortfall: Double
        if let next = WarehouseSystem.nextExpansion(current: capacity) {
            shortfall = max(0, next.cost - store.stall.coins)
        } else {
            shortfall = 0
        }
        return Section("창고") {
            if let next = WarehouseSystem.nextExpansion(current: capacity) {
                UpgradeRowView(
                    upgrade: UpgradeDefinition(
                        name: "창고 확장", coinCost: next.cost,
                        description: "\(capacity)칸 → \(next.capacity)칸"),
                    displayEffect: shortfall > 0
                        ? "💰 \(Self.formatted(shortfall)) 더 필요해요"
                        : "농장 수확과 오프라인 보관량이 늘어나요",
                    isOwned: false,
                    isNext: true,
                    canAfford: shortfall == 0,
                    onPurchase: { pendingWarehouseCapacity = capacity }
                )
            } else {
                UpgradeRowView(
                    upgrade: UpgradeDefinition(
                        name: "창고 최대", coinCost: 0, description: "\(capacity)칸 · 최대"),
                    isOwned: true, isNext: false, canAfford: false, onPurchase: {})
            }
        }
    }

    private var warehouseAlertMessage: String {
        guard let capacity = pendingWarehouseCapacity,
              let next = WarehouseSystem.nextExpansion(current: capacity) else { return "" }
        return "💰 \(Self.formatted(next.cost))을 내면 창고가 \(capacity)칸에서 \(next.capacity)칸으로 늘어나요."
    }

    private func confirmWarehouseExpansion() {
        guard let capacity = pendingWarehouseCapacity else { return }
        pendingWarehouseCapacity = nil
        // Re-check so a double-fire or stale alert cannot buy twice.
        guard store.stall.warehouseCapacity == capacity else { return }
        store.purchaseUpgrade(.warehouse)
        guard store.stall.warehouseCapacity > capacity else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AccessibilityNotification.Announcement(
            String(localized: "창고가 \(store.stall.warehouseCapacity)칸으로 늘어났습니다.")
        ).post()
    }

    static func formatted(_ value: Double) -> String {
        CoinFormat.string(value)
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
                Text("₩\(CoinFormat.string(upgrade.coinCost))").font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(canAfford ? .orange : .gray)
            .disabled(!canAfford)
        } else {
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
        }
    }
}

// MARK: - LocationRowView

enum LocationRowState: Equatable {
    case current
    case past
    case affordable
    case short
    case lockedPrerequisite
    case lockedQueue(previous: String)
}

private struct LocationRowView: View {
    let definition: LocationDefinition
    let state: LocationRowState
    let onPurchase: () -> Void

    private var opacity: Double {
        switch state {
        case .past: 0.6
        case .lockedPrerequisite, .lockedQueue: 0.5
        default: 1
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(definition.name).font(.headline)
                    if state == .current {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("현재 위치")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.green.opacity(0.2), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text(definition.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(definition.displayEffect)
                    .font(.caption2)
                    .foregroundStyle(.green)
                if let unlocks = definition.unlocks {
                    Text("🔓 \(unlocks)").font(.caption2).foregroundStyle(.blue)
                }
                if let lock = lockText {
                    Text("🔒 \(lock)").font(.caption2).foregroundStyle(.orange)
                }
            }
            .opacity(opacity)
            Spacer()
            trailingView
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.name), \(definition.description)")
        .accessibilityValue(accessibilityValue)
    }

    private var lockText: String? {
        switch state {
        case .lockedPrerequisite: definition.lockedReason
        case .lockedQueue(let previous): "\(previous)에 먼저 이전하세요"
        default: nil
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .current: "현재 위치"
        case .past: "이전 위치"
        case .affordable, .short:
            "\(UpgradeSheet.formatted(definition.coinCost)) 코인" + (state == .affordable ? ", 이전 가능" : "")
        case .lockedPrerequisite: "잠금, \(definition.lockedReason ?? "")"
        case .lockedQueue(let previous): "잠금, \(previous)에 먼저 이전하세요"
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch state {
        case .current:
            EmptyView()
        case .past:
            Image(systemName: "checkmark").foregroundStyle(.secondary).opacity(opacity)
        case .affordable:
            Button(action: onPurchase) {
                Text("💰 \(UpgradeSheet.formatted(definition.coinCost))").font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .frame(minWidth: 44, minHeight: 44)
        case .short:
            Text("💰 \(UpgradeSheet.formatted(definition.coinCost))")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.gray.opacity(0.2), in: Capsule())
        case .lockedPrerequisite, .lockedQueue:
            Image(systemName: "lock.fill").foregroundStyle(.tertiary)
        }
    }
}
