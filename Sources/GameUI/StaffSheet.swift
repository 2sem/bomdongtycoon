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
            Group {
                if store.stall.staffCount == 0 {
                    ContentUnavailableView(
                        "아직 직원이 없어요",
                        systemImage: "person.2.slash",
                        description: Text("업그레이드 탭에서 직원을 먼저 고용하세요")
                    )
                } else {
                    List {
                        availableSection
                        cashierSection
                        cookSection
                    }
                }
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

    // MARK: - Available Workers Banner

    private var availableSection: some View {
        Section {
            HStack {
                Label("여유 인력", systemImage: "person.2.fill")
                    .font(.headline)
                Spacer()
                Text("\(max(0, store.availableWorkers))명")
                    .font(.title2.bold())
                    .foregroundStyle(store.availableWorkers > 0 ? Color.deepAmber : .secondary)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.creamBackground)

            Text("알바생 \(store.stall.tier1Count)명 · 이모님 \(store.stall.tier2Count)명 · 요리사 \(store.stall.tier3Count)명")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                let count = i < store.stall.menuCooks.count ? store.stall.menuCooks[i] : 0
                StaffPositionRow(
                    icon: cookEmoji(for: i),
                    iconBg: cookColor(for: i),
                    iconIsEmoji: true,
                    positionName: "\(menuName) 요리사",
                    statusText: count > 0 ? "\(count)명 배정 · 자동 조리 활성" : "비어있음",
                    assignedCount: count,
                    isSingleSlot: false,
                    canAssign: store.availableWorkers > 0,
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
