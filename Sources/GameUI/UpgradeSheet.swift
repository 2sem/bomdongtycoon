import SwiftUI
import UIKit
import GameCore

public struct UpgradeSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool
    @State private var pendingLocationTier: Int?
    @State private var pendingWarehouseCapacity: Int?
    @State private var showPrestige = false
    @State private var showStats = false
    @Environment(\.dotPlaySound) private var play

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        DotSheet(title: String(localized: "업그레이드"), onClose: { isPresented = false }) {
            DotScroll {
                upgradeSection(
                    title: String(localized: "dot.upgrade.menu"),
                    type: .menu,
                    definitions: UpgradeDefinitions.menu,
                    currentTier: store.stall.menuTier + 1,
                    icons: ["dot_dish_geotjeori", "dot_dish_kimchi", "dot_dish_bibimbap"]
                )
                upgradeSection(
                    title: String(localized: "dot.upgrade.stall"),
                    type: .stall,
                    definitions: UpgradeDefinitions.stall,
                    currentTier: store.stall.stallTier + 1,
                    icons: ["dot_ui_upgrade", "dot_ui_upgrade", "dot_ui_upgrade"]
                )
                warehouseSection
                renovationSection
                locationSection
                springSection
            }
        }
        .sheet(isPresented: $showPrestige) {
            PrestigeSheet(isPresented: $showPrestige) {
                showPrestige = false
                isPresented = false
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showStats) {
            StatsSheet(isPresented: $showStats)
                .environmentObject(store)
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
    }

    @ViewBuilder
    private func upgradeSection(
        title: String,
        type: UpgradeType,
        definitions: [UpgradeDefinition],
        currentTier: Int,
        icons: [String]
    ) -> some View {
        let coins = store.stall.coins
        DotSectionHeader(title)
        ForEach(definitions.indices, id: \.self) { index in
            UpgradeRowView(
                upgrade: definitions[index],
                icon: icons[index],
                isOwned: index < currentTier,
                isNext: index == currentTier,
                canAfford: coins >= definitions[index].coinCost,
                onPurchase: { purchase(type) }
            )
        }
    }

    /// Plays the cue only when the purchase actually went through.
    private func purchase(_ type: UpgradeType) {
        let before = store.stall.coins
        store.purchaseUpgrade(type)
        play(store.stall.coins < before ? .purchase : .error)
    }

    // MARK: Location

    private var locationSection: some View {
        let current = store.stall.locationTier
        let stallTier = store.stall.stallTier
        let coins = store.stall.coins
        return Group {
            DotSectionHeader(String(localized: "위치"))
            ForEach(UpgradeDefinitions.location.indices, id: \.self) { index in
                let def = UpgradeDefinitions.location[index]
                LocationRowView(
                    definition: def,
                    state: Self.locationState(
                        index: index, current: current,
                        stallTier: stallTier, coins: coins, definition: def),
                    prestigeCount: store.progress.prestigeCount,
                    onPurchase: { pendingLocationTier = index }
                )
            }
            DotFootnote(String(localized: "이전해도 가게와 직원은 그대로 따라와요."))
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
        return String(format: String(localized: "dot.location.alert.title"), DotContent.loc(def.name))
    }

    private var alertMessage: String {
        guard let def = pendingLocation else { return "" }
        return String(format: String(localized: "dot.location.alert.message"),
                      Self.formatted(def.coinCost), Int(def.saleMultiplier))
    }

    private func confirmLocationMove() {
        guard let tier = pendingLocationTier else { return }
        pendingLocationTier = nil
        // Re-check so a double-fire or stale alert cannot buy twice.
        guard tier == store.stall.locationTier + 1 else { return }
        store.purchaseUpgrade(.location)
        guard store.stall.locationTier == tier else { return }
        play(.purchase)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isPresented = false
    }

    // MARK: New spring

    /// Always last: the one entry that costs the player their run. Visible but disabled until the
    /// final location and stall tier are reached, so the goal is discoverable from the start.
    private var springSection: some View {
        let available = store.isPrestigeAvailable
        let current = PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount)
        let next = PrestigeSystem.legacyMultiplier(prestigeCount: store.progress.prestigeCount + 1)
        return Group {
            DotSectionHeader(String(localized: "새봄"))
            Button { showPrestige = true } label: {
                HStack(spacing: 10) {
                    DotImage("dot_ui_star", scale: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "prestige.title")).dotText(.bold)
                        Text(String(
                            format: String(localized: "prestige.row.detail"),
                            PrestigeSystem.multiplierNumber(current), PrestigeSystem.multiplierNumber(next)))
                            .dotText(.caption, color: DotPalette.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if !available { DotImage("dot_ui_lock", scale: 1) }
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .dotPanel()
                .opacity(available ? 1 : 0.6)
            }
            .buttonStyle(.plain)
            .disabled(!available)
            Button { showStats = true } label: {
                HStack(spacing: 10) {
                    DotImage("dot_ui_stats", scale: 2)
                    Text(String(localized: "기록 보기")).dotText(.bold)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .dotPanel()
            }
            .buttonStyle(.plain)
            if !available { springLockedFooter }
        }
    }

    private var springLockedFooter: some View {
        let location = PrestigeSystem.locationRequirement(for: store.stall)
        let stall = PrestigeSystem.stallRequirement(for: store.stall)
        return VStack(alignment: .leading, spacing: 2) {
            DotFootnote(String(localized: "prestige.locked"))
            DotFootnote(Self.progressLine(location, met: "prestige.progress.location.met", unmet: "prestige.progress.location"))
            DotFootnote(Self.progressLine(stall, met: "prestige.progress.stall.met", unmet: "prestige.progress.stall"))
        }
    }

    private static func progressLine(
        _ requirement: PrestigeSystem.Requirement,
        met: String.LocalizationValue,
        unmet: String.LocalizationValue
    ) -> String {
        requirement.isMet
            ? String(format: String(localized: met), DotContent.loc(requirement.requiredName))
            : String(format: String(localized: unmet), DotContent.loc(requirement.currentName),
                   DotContent.loc(requirement.requiredName))
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
        return Group {
            DotSectionHeader(String(localized: "창고"))
            if let next = WarehouseSystem.nextExpansion(current: capacity) {
                UpgradeRowView(
                    upgrade: UpgradeDefinition(
                        name: String(localized: "창고 확장"), coinCost: next.cost,
                        description: String(format: String(localized: "dot.warehouse.slots"), capacity, next.capacity)),
                    icon: "dot_farm_warehouse_crate_half",
                    displayEffect: shortfall > 0
                        ? String(format: String(localized: "dot.warehouse.short"), Self.formatted(shortfall))
                        : String(localized: "농장 수확과 오프라인 보관량이 늘어나요"),
                    isOwned: false,
                    isNext: true,
                    canAfford: shortfall == 0,
                    onPurchase: { pendingWarehouseCapacity = capacity }
                )
            } else {
                UpgradeRowView(
                    upgrade: UpgradeDefinition(
                        name: String(localized: "창고 최대"), coinCost: 0,
                        description: String(format: String(localized: "dot.warehouse.max"), capacity)),
                    icon: "dot_farm_warehouse_crate_full",
                    isOwned: true, isNext: false, canAfford: false, onPurchase: {})
            }
        }
    }

    // MARK: Renovation

    /// The endless late-game sink. Listed from the start as a locked row so the goal is discoverable,
    /// like the new-spring entry.
    private var renovationSection: some View {
        let stall = store.stall
        let level = stall.renovationLevel
        let unlocked = RenovationSystem.isUnlocked(for: stall)
        let cost = RenovationSystem.cost(forLevel: level)
        let bonus = Int((RenovationSystem.priceMultiplier(level: level) - 1) * 100 + 0.5)
        return Group {
            DotSectionHeader(String(localized: "dot.renovation.title"))
            UpgradeRowView(
                upgrade: UpgradeDefinition(
                    name: String(localized: "dot.renovation.title"), coinCost: cost,
                    description: String(format: String(localized: "dot.renovation.level"), level)),
                icon: "dot_ui_upgrade",
                displayEffect: String(format: String(localized: "dot.renovation.effect"),
                                      RenovationSystem.percentPerLevel, bonus),
                isOwned: false,
                isNext: unlocked,
                canAfford: unlocked && stall.coins >= cost,
                onPurchase: { purchase(.renovation) })
            if !unlocked {
                DotFootnote(DotContent.loc(UpgradeDefinitions.location[2].lockedReason ?? ""))
            }
        }
    }

    private var warehouseAlertMessage: String {
        guard let capacity = pendingWarehouseCapacity,
              let next = WarehouseSystem.nextExpansion(current: capacity) else { return "" }
        return String(format: String(localized: "dot.warehouse.alert.message"),
                      Self.formatted(next.cost), capacity, next.capacity)
    }

    private func confirmWarehouseExpansion() {
        guard let capacity = pendingWarehouseCapacity else { return }
        pendingWarehouseCapacity = nil
        // Re-check so a double-fire or stale alert cannot buy twice.
        guard store.stall.warehouseCapacity == capacity else { return }
        store.purchaseUpgrade(.warehouse)
        guard store.stall.warehouseCapacity > capacity else { return }
        play(.purchase)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AccessibilityNotification.Announcement(
            String(format: String(localized: "dot.warehouse.expanded"), store.stall.warehouseCapacity)
        ).post()
    }

    static func formatted(_ value: Double) -> String {
        CoinFormat.string(value)
    }
}

// MARK: - UpgradeRowView

private struct UpgradeRowView: View {
    let upgrade: UpgradeDefinition
    var icon: String? = nil
    var displayEffect: String? = nil
    let isOwned: Bool
    let isNext: Bool
    let canAfford: Bool
    let onPurchase: () -> Void

    private var effectText: String { displayEffect ?? DotContent.effect(for: upgrade) }

    var body: some View {
        HStack(spacing: 10) {
            if let icon { DotImage(icon, scale: 2).opacity(isOwned || isNext ? 1 : 0.5) }
            VStack(alignment: .leading, spacing: 2) {
                Text(DotContent.loc(upgrade.name)).dotText(.bold)
                Text(DotContent.loc(upgrade.description))
                    .dotText(.caption, color: DotPalette.textSecondary)
                if !effectText.isEmpty {
                    Text(effectText).dotText(.caption, color: DotPalette.leafDark)
                }
                if let unlocks = upgrade.unlocks {
                    DotHint(icon: "dot_ui_check", text: DotContent.loc(unlocks), color: DotPalette.blue)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            trailingView
        }
        .dotPanel()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isOwned {
            DotImage("dot_ui_check", scale: 2).accessibilityLabel(String(localized: "dot.owned"))
        } else if isNext {
            Button { onPurchase() } label: {
                DotCostLabel(text: CoinFormat.string(upgrade.coinCost))
            }
            .buttonStyle(.dotCompact)
            .disabled(!canAfford)
        } else {
            DotImage("dot_ui_lock", scale: 1).opacity(0.6).accessibilityLabel(String(localized: "잠김"))
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
    let prestigeCount: Int
    let onPurchase: () -> Void

    private var opacity: Double {
        switch state {
        case .past: 0.6
        case .lockedPrerequisite, .lockedQueue: 0.55
        default: 1
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(DotContent.loc(definition.name)).dotText(.bold)
                    if state == .current { DotTag(text: String(localized: "현재 위치")) }
                }
                Text(DotContent.loc(definition.description))
                    .dotText(.caption, color: DotPalette.textSecondary)
                Text(effectText).dotText(.caption, color: DotPalette.leafDark)
                if let unlocks = definition.unlocks {
                    DotHint(icon: "dot_ui_check", text: DotContent.loc(unlocks), color: DotPalette.blue)
                }
                if let lock = lockText {
                    DotHint(icon: "dot_ui_lock", text: lock, color: DotPalette.orangeDark)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .opacity(opacity)
            Spacer(minLength: 0)
            trailingView
        }
        .frame(minHeight: 44)
        .dotPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(DotContent.loc(definition.name)), \(DotContent.loc(definition.description))")
        .accessibilityValue(accessibilityValue)
    }

    /// "시장 x2 · 유산 x1.4 = x2.8" once a spring has been welcomed; the plain effect before.
    private var effectText: String {
        guard prestigeCount > 0 else { return DotContent.effect(for: definition) }
        let legacy = PrestigeSystem.legacyMultiplier(prestigeCount: prestigeCount)
        return String(
            format: String(localized: "prestige.location.product"),
            DotContent.loc(definition.name),
            PrestigeSystem.multiplierNumber(definition.saleMultiplier),
            PrestigeSystem.multiplierNumber(legacy),
            PrestigeSystem.multiplierNumber(definition.saleMultiplier * legacy))
    }

    private var lockText: String? {
        switch state {
        case .lockedPrerequisite: definition.lockedReason.map(DotContent.loc)
        case .lockedQueue(let previous):
            String(format: String(localized: "dot.location.queue"), DotContent.loc(previous))
        default: nil
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .current: String(localized: "현재 위치")
        case .past: String(localized: "dot.location.past")
        case .affordable, .short:
            String(format: String(localized: "dot.location.cost.accessibility"),
                   UpgradeSheet.formatted(definition.coinCost))
                + (state == .affordable ? ", " + String(localized: "dot.location.canMove") : "")
        case .lockedPrerequisite, .lockedQueue:
            String(localized: "잠김") + ", " + (lockText ?? "")
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch state {
        case .current:
            EmptyView()
        case .past:
            DotImage("dot_ui_check", scale: 2).opacity(opacity)
        case .affordable:
            Button(action: onPurchase) {
                DotCostLabel(text: UpgradeSheet.formatted(definition.coinCost))
            }
            .buttonStyle(.dotCompact)
        case .short:
            Button(action: {}) {
                DotCostLabel(text: UpgradeSheet.formatted(definition.coinCost))
            }
            .buttonStyle(.dotCompact)
            .disabled(true)
        case .lockedPrerequisite, .lockedQueue:
            DotImage("dot_ui_lock", scale: 1).opacity(0.6)
        }
    }
}
