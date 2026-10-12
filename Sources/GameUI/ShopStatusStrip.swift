import SwiftUI
import GameCore

/// Read-only HUD row: warehouse fill, per-menu stock and whether the cashier / cook are on duty.
/// Never intercepts touches; the scene underneath stays fully interactive.
public struct ShopStatusStrip: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Stays false until the store has published once, so the strip never flashes placeholder zeros.
    @State private var hasState = false

    public init() {}

    public var body: some View {
        let status = store.shopStatus
        Group {
            if hasState {
                content(status)
                    .animation(reduceMotion ? nil : .snappy, value: status)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Self.accessibilityLabel(for: status))
                    .allowsHitTesting(false)
            }
        }
        .onReceive(store.objectWillChange.prefix(1)) { _ in hasState = true }
        .task {
            // Fallback for a store that is idle on launch.
            try? await Task.sleep(for: .seconds(1))
            hasState = true
        }
    }

    // MARK: - Layout variants

    @ViewBuilder
    private func content(_ status: ShopStatusSnapshot) -> some View {
        if typeSize.isAccessibilitySize {
            verticalCard(status)
        } else {
            ViewThatFits(in: .horizontal) {
                capsule { fullRow(status) }
                capsule { collapsedRow(status) }
                verticalCard(status)
            }
        }
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullRow(_ status: ShopStatusSnapshot) -> some View {
        HStack(spacing: 10) {
            warehouseChip(status)
            ForEach(status.stocks, id: \.menuIndex) { stockChip($0) }
            crewChips(status)
        }
    }

    private func collapsedRow(_ status: ShopStatusSnapshot) -> some View {
        HStack(spacing: 10) {
            warehouseChip(status)
            chip(tint: status.totalStock == 0 ? .red : .primary, pulse: status.totalStock == 0) {
                Text(String(localized: "재고"))
                Text("\(status.totalStock)")
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            crewChips(status)
        }
    }

    private func verticalCard(_ status: ShopStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            warehouseChip(status)
            HStack(spacing: 10) {
                ForEach(status.stocks, id: \.menuIndex) { stockChip($0) }
            }
            HStack(spacing: 10) { crewChips(status) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chips

    private func warehouseChip(_ status: ShopStatusSnapshot) -> some View {
        let cap = max(status.warehouseCap, 1)
        let full = status.warehouseCount >= cap
        let tint: Color = full ? .red : (Double(status.warehouseCount) / Double(cap) >= 0.8 ? .orange : .primary)
        return chip(tint: tint, pulse: full) {
            Image(systemName: "shippingbox.fill")
            Text("\(status.warehouseCount)/\(status.warehouseCap)")
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
    }

    private func stockChip(_ stock: ShopStatusSnapshot.MenuStock) -> some View {
        let empty = stock.count == 0
        return chip(tint: empty ? .red : .primary, pulse: empty) {
            Text(Self.shortNames[stock.menuIndex] ?? "")
            Text("\(stock.count)")
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
    }

    @ViewBuilder
    private func crewChips(_ status: ShopStatusSnapshot) -> some View {
        crewChip(symbol: "person.fill", present: status.cashierPresent, energy: status.cashierEnergy)
        crewChip(symbol: "flame.fill", present: status.cookPresent, energy: status.cookEnergy)
    }

    private func crewChip(symbol: String, present: Bool, energy: Double) -> some View {
        let low = present && energy < 0.25
        return chip(tint: low ? .orange : .primary, pulse: false) {
            Image(systemName: symbol)
            energyBars(energy: energy, present: present, low: low)
        }
        .opacity(present ? 1 : 0.35)
    }

    private func energyBars(energy: Double, present: Bool, low: Bool) -> some View {
        let filled = present ? min(3, max(1, Int(ceil(energy * 3)))) : 0
        return HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { step in
                Capsule()
                    .fill(step < filled ? (low ? Color.orange : Color.primary) : Color.secondary.opacity(0.35))
                    .frame(width: 4, height: 10)
            }
        }
    }

    private func chip<Content: View>(tint: Color, pulse: Bool,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 3, content: content)
            .font(.caption.monospacedDigit())
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .modifier(AlertPulse(active: pulse, enabled: !reduceMotion))
    }

    // MARK: - Strings

    private static let shortNames = [0: "겉", 1: "김", 2: "비"]

    private static func energyWord(_ energy: Double) -> String {
        if energy >= 0.67 { return String(localized: "에너지 높음") }
        if energy >= 0.25 { return String(localized: "에너지 보통") }
        return String(localized: "지침")
    }

    static func accessibilityLabel(for status: ShopStatusSnapshot) -> String {
        let warehouse = String(format: String(localized: "창고 %d 중 %d"), status.warehouseCap, status.warehouseCount)

        let stock: String
        if status.totalStock == 0 {
            stock = String(localized: "재고 없음")
        } else {
            let items = status.stocks.map {
                "\(UpgradeDefinitions.menu[$0.menuIndex].name) \($0.count)"
            }.joined(separator: ", ")
            stock = "\(String(localized: "재고")) \(items)"
        }

        let cashier = status.cashierPresent
            ? "\(String(localized: "계산대 직원 있음")) \(energyWord(status.cashierEnergy))"
            : String(localized: "계산대 직원 없음")
        let cook = status.cookPresent
            ? "\(String(localized: "요리사 있음")) \(energyWord(status.cookEnergy))"
            : String(localized: "요리사 없음")

        return [warehouse, stock, cashier, cook].joined(separator: ", ")
    }
}

/// One short scale pulse each time `active` flips to true. Skipped under Reduce Motion.
private struct AlertPulse: ViewModifier {
    let active: Bool
    let enabled: Bool
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: active) { _, isActive in
                guard isActive, enabled else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    scale = 1.18
                } completion: {
                    withAnimation(.easeIn(duration: 0.15)) { scale = 1 }
                }
            }
    }
}
