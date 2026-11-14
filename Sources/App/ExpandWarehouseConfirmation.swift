import SwiftUI
import UIKit
import GameCore

/// Confirm-then-purchase for the warehouse crate, same shape as `AddFarmPlotConfirmation`.
/// `DotWorldScene` only posts `.requestExpandWarehouse`; the alert lives here because SwiftUI
/// owns every modal in this app.
struct ExpandWarehouseConfirmation: ViewModifier {
    @EnvironmentObject private var store: GameStore
    @State private var pendingCapacity: Int?

    func body(content: Content) -> some View {
        content
            .preference(key: AlertUpKey.self, value: pendingCapacity != nil)
            .onReceive(NotificationCenter.default.publisher(for: .requestExpandWarehouse)) { _ in
                pendingCapacity = store.stall.warehouseCapacity
            }
            .alert(
                shortOfCoins ? String(localized: "dot.coins.short.title") : String(localized: "warehouse.expand.title"),
                isPresented: Binding(
                    get: { pendingCapacity != nil },
                    set: { if !$0 { pendingCapacity = nil } }
                )
            ) {
                if canConfirm {
                    Button(String(localized: "warehouse.expand.confirm")) { confirm() }
                    Button(String(localized: "취소"), role: .cancel) {}
                } else {
                    Button(String(localized: "확인"), role: .cancel) {}
                }
            } message: {
                Text(message)
            }
    }

    private var next: (capacity: Int, cost: Double)? {
        pendingCapacity.flatMap { WarehouseSystem.nextExpansion(current: $0) }
    }

    private var canConfirm: Bool {
        guard let next else { return false }
        return store.stall.coins >= next.cost
    }

    /// Not the max-size case: that one reads fine under the question title.
    private var shortOfCoins: Bool { next != nil && !canConfirm }

    private var message: String {
        guard let next, let current = pendingCapacity else { return String(localized: "warehouse.expand.max") }
        let cost = CoinFormat.string(next.cost)
        let key = canConfirm ? "warehouse.expand.message" : "warehouse.expand.short"
        return String(format: String(localized: String.LocalizationValue(key)), cost, current, next.capacity)
    }

    private func confirm() {
        guard let capacity = pendingCapacity else { return }
        pendingCapacity = nil
        guard store.stall.warehouseCapacity == capacity else { return }
        store.expandWarehouse()
        guard store.stall.warehouseCapacity > capacity else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DotSound.shared.play(.purchase)
    }
}
