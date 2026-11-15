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
                let capacity = store.stall.warehouseCapacity
                // Maxed out or too poor to buy: a toast, not a modal that would stop the sweep of taps around it.
                guard let next = WarehouseSystem.nextExpansion(current: capacity) else {
                    Notification.Name.postHUDToast(String(localized: "warehouse.expand.max"))
                    return
                }
                guard store.stall.coins >= next.cost else {
                    DotSound.shared.play(.error)
                    Notification.Name.postHUDToast(
                        String(format: String(localized: "dot.toast.coinsShort"), CoinFormat.string(next.cost)))
                    return
                }
                pendingCapacity = capacity
            }
            .alert(
                String(localized: "warehouse.expand.title"),
                isPresented: Binding(
                    get: { pendingCapacity != nil },
                    set: { if !$0 { pendingCapacity = nil } }
                )
            ) {
                Button(String(localized: "warehouse.expand.confirm")) { confirm() }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(message)
            }
    }

    private var next: (capacity: Int, cost: Double)? {
        pendingCapacity.flatMap { WarehouseSystem.nextExpansion(current: $0) }
    }

    private var message: String {
        guard let next, let current = pendingCapacity else { return "" }
        return String(format: String(localized: "warehouse.expand.message"),
                      CoinFormat.string(next.cost), current, next.capacity)
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
