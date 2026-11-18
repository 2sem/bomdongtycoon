import SwiftUI
import GameCore

/// Read-only HUD row: warehouse fill and one stock chip per unlocked menu.
/// Never intercepts touches; the scene underneath stays fully interactive.
public struct ShopStatusStrip: View {
    @EnvironmentObject var store: GameStore
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
        ViewThatFits(in: .horizontal) {
            strip { fullRow(status) }
            verticalCard(status)
        }
    }

    private func strip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullRow(_ status: ShopStatusSnapshot) -> some View {
        HStack(spacing: 8) {
            warehouseChip(status)
            ForEach(status.stocks, id: \.menuIndex) { stockChip($0) }
        }
    }

    private func verticalCard(_ status: ShopStatusSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            warehouseChip(status)
            HStack(spacing: 8) {
                ForEach(status.stocks, id: \.menuIndex) { stockChip($0) }
            }
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chips

    private func warehouseChip(_ status: ShopStatusSnapshot) -> some View {
        let cap = max(status.warehouseCap, 1)
        let full = status.warehouseCount >= cap
        let tint: Color = full ? DotPalette.orange : (Double(status.warehouseCount) / Double(cap) >= 0.8 ? DotPalette.goldLight : DotPalette.paper)
        return chip(tint: tint, pulse: full) {
            DotImage("dot_ui_cabbage", scale: 1)
            Text("\(status.warehouseCount)/\(status.warehouseCap)")
        }
    }

    private func stockChip(_ stock: ShopStatusSnapshot.MenuStock) -> some View {
        let empty = stock.count == 0
        return chip(tint: empty ? DotPalette.orange : DotPalette.paper, pulse: empty) {
            DotImage(Self.dishIcons[stock.menuIndex] ?? "dot_dish_empty_bowl", scale: 1)
            Text("\(stock.count)")
        }
    }

    private func chip<Content: View>(tint: Color, pulse: Bool,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 2, content: content)
            .dotText(.caption, color: tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .modifier(AlertPulse(active: pulse, enabled: !reduceMotion))
    }

    // MARK: - Strings

    private static let dishIcons = [0: "dot_dish_geotjeori", 1: "dot_dish_kimchi", 2: "dot_dish_bibimbap"]

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

/// One pixel hop each time `active` flips to true. Skipped under Reduce Motion.
private struct AlertPulse: ViewModifier {
    let active: Bool
    let enabled: Bool
    @State private var hopped = false

    func body(content: Content) -> some View {
        content
            .offset(y: hopped ? -DotTheme.px : 0)
            .onChange(of: active) { _, isActive in
                guard isActive, enabled else { return }
                hopped = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    hopped = false
                }
            }
    }
}
