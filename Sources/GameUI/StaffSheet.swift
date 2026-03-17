import SwiftUI
import GameCore

public struct StaffSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            List {
                hireSection
                availableSection
                cashierSection
                cookSection
            }
            .navigationTitle("직원 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Hire Section

    private var hireSection: some View {
        Section {
            ForEach(1...3, id: \.self) { tier in
                HireTierRow(tier: tier)
                    .environmentObject(store)
            }
        } header: {
            Text("직원 고용")
                .foregroundStyle(Color.deepAmber)
        }
    }

    // MARK: - Available Workers Banner

    private var availableSection: some View {
        Section {
            HStack(spacing: 16) {
                TierIconCount(emoji: "👨", count: store.stall.tier1Count)
                TierIconCount(emoji: "👩", count: store.stall.tier2Count)
                TierIconCount(emoji: "👨‍🍳", count: store.stall.tier3Count)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(max(0, store.availableWorkers))명")
                        .font(.title2.bold())
                        .foregroundStyle(store.availableWorkers > 0 ? Color.deepAmber : .secondary)
                    Text("여유")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.creamBackground)
        }
    }

    // MARK: - Cashier Section

    private var cashierSection: some View {
        Section {
            StaffPositionRow(
                icon: "person.crop.circle.badge.checkmark",
                iconBg: Color.warmAmber,
                iconIsEmoji: false,
                positionName: "계산원",
                statusText: store.stall.cashierCount > 0 ? "배정됨 · 자동 수금 활성" : "비어있음",
                assignedCount: store.stall.cashierCount,
                isSingleSlot: true,
                canAssign: store.availableWorkers > 0,
                onAssign: { store.assignToCashier() },
                onRemove: { store.removeFromCashier() }
            )
        } header: {
            Text("계산대")
                .foregroundStyle(Color.deepAmber)
        }
    }

    // MARK: - Cook Section

    private var cookSection: some View {
        Section {
            ForEach(0...store.stall.menuTier, id: \.self) { i in
                let menuName = UpgradeDefinitions.menu[i].name
                let tier = i < store.stall.menuCooks.count ? store.stall.menuCooks[i] : 0
                let tierName = tier > 0 ? UpgradeDefinitions.staff[tier - 1].name : ""
                let speed = tier > 0 ? GameStore.cookSpeedLabel(forTier: tier) : ""
                let status = tier > 0
                    ? "\(tierName) · \(speed) · 자동 조리 활성"
                    : "비어있음 (수동 조리 가능)"
                StaffPositionRow(
                    icon: cookEmoji(for: i),
                    iconBg: cookColor(for: i),
                    iconIsEmoji: true,
                    positionName: "\(menuName) 요리사",
                    statusText: status,
                    assignedCount: tier > 0 ? 1 : 0,
                    isSingleSlot: true,
                    canAssign: store.availableWorkers > 0 && tier == 0,
                    onAssign: { store.assignMenuCook(menuIndex: i) },
                    onRemove: { store.removeMenuCook(menuIndex: i) }
                )
            }
        } header: {
            Text("주방")
                .foregroundStyle(Color.deepAmber)
        }
    }

    private func cookEmoji(for index: Int) -> String {
        ["🥬", "🥗", "🥘"][safe: index] ?? "🍳"
    }

    private func cookColor(for index: Int) -> Color {
        [Color.cookGreen, Color.cookGreen, Color.warmOrange][safe: index] ?? Color.cookGreen
    }
}

// MARK: - StaffPositionRow

private struct StaffPositionRow: View {
    let icon: String
    let iconBg: Color
    let iconIsEmoji: Bool
    let positionName: String
    let statusText: String
    let assignedCount: Int
    let isSingleSlot: Bool
    let canAssign: Bool
    let onAssign: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                if iconIsEmoji {
                    Text(icon)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            // Labels
            VStack(alignment: .leading, spacing: 2) {
                Text(positionName)
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Buttons
            assignmentButtons
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var assignmentButtons: some View {
        if isSingleSlot {
            if assignedCount > 0 {
                removeButton
            } else {
                assignButton
            }
        } else {
            if assignedCount > 0 {
                VStack(spacing: 6) {
                    assignButton
                    removeButton
                }
                .frame(width: 80)
            } else {
                assignButton
                    .frame(width: 80)
            }
        }
    }

    private var assignButton: some View {
        Button {
            haptic()
            onAssign()
        } label: {
            Label(assignedCount > 0 ? "배정 +" : "배정", systemImage: "plus")
                .font(.caption.bold())
                .labelStyle(.titleOnly)
        }
        .buttonStyle(.borderedProminent)
        .tint(canAssign ? Color.deepAmber : .gray)
        .disabled(!canAssign)
        .controlSize(.small)
    }

    private var removeButton: some View {
        Button {
            haptic()
            onRemove()
        } label: {
            Label("해제", systemImage: "minus")
                .font(.caption.bold())
                .labelStyle(.titleOnly)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .controlSize(.small)
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - HireTierRow

private struct HireTierRow: View {
    @EnvironmentObject var store: GameStore
    let tier: Int

    private var def: UpgradeDefinition { UpgradeDefinitions.staff[tier - 1] }

    private var count: Int {
        switch tier {
        case 1: return store.stall.tier1Count
        case 2: return store.stall.tier2Count
        case 3: return store.stall.tier3Count
        default: return 0
        }
    }

    private var isUnlocked: Bool {
        switch tier {
        case 1: return true
        case 2: return store.stall.stallTier >= 1
        case 3: return store.stall.stallTier >= 2
        default: return false
        }
    }

    private var unlockHint: String {
        switch tier {
        case 2: return "봄동 식당 업그레이드 필요"
        case 3: return "봄동 전문점 업그레이드 필요"
        default: return ""
        }
    }

    private var tierEmoji: String {
        switch tier {
        case 1: return "👨"
        case 2: return "👩"
        case 3: return "👨‍🍳"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isUnlocked ? Color.warmAmber : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                Text(tierEmoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? Color.primary : Color.secondary)
                if isUnlocked {
                    Text(def.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("현재 \(count)명")
                        .font(.caption2)
                        .foregroundStyle(Color.deepAmber)
                } else {
                    Text(unlockHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isUnlocked {
                let canAfford = store.stall.coins >= def.coinCost
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.hireWorker(tier: tier)
                } label: {
                    Text("₩\(Int(def.coinCost))")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(canAfford ? Color.deepAmber : .gray)
                .disabled(!canAfford)
                .controlSize(.small)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - TierIconCount

private struct TierIconCount: View {
    let emoji: String
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 26))
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(count > 0 ? Color.deepAmber : Color.secondary)
        }
    }
}

// MARK: - Color Palette

private extension Color {
    static let warmAmber     = Color(red: 0.93, green: 0.70, blue: 0.18)
    static let deepAmber     = Color(red: 0.72, green: 0.40, blue: 0.10)
    static let creamBackground = Color(red: 0.98, green: 0.94, blue: 0.86)
    static let cookGreen     = Color(red: 0.72, green: 0.88, blue: 0.52)
    static let warmOrange    = Color(red: 0.96, green: 0.76, blue: 0.38)
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
