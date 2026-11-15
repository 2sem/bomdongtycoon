import SwiftUI
import UIKit
import GameCore

/// Confirm-then-purchase for a dish's padlock on the counter, same shape as `ExpandWarehouseConfirmation`.
/// `DotWorldScene` decides the toast/shake cases and only posts `.requestUnlockDish` when the
/// purchase is possible; the alert lives here because SwiftUI owns every modal in this app.
struct UnlockDishConfirmation: ViewModifier {
    @EnvironmentObject private var store: GameStore
    @State private var pendingMenu: Int?

    func body(content: Content) -> some View {
        content
            .preference(key: AlertUpKey.self, value: pendingMenu != nil)
            .onReceive(NotificationCenter.default.publisher(for: .requestUnlockDish)) { note in
                guard let menu = note.userInfo?["menu"] as? Int,
                      case .available = MenuUnlockSystem.status(for: store.stall, menuIndex: menu) else { return }
                pendingMenu = menu
            }
            .alert(
                String(format: String(localized: "dish.unlock.title"), dishName),
                isPresented: Binding(
                    get: { pendingMenu != nil },
                    set: { if !$0 { pendingMenu = nil } }
                )
            ) {
                Button(String(localized: "dish.unlock.confirm")) { confirm() }
                Button(String(localized: "취소"), role: .cancel) {}
            } message: {
                Text(message)
            }
    }

    private var dishName: String {
        guard let menu = pendingMenu, UpgradeDefinitions.menu.indices.contains(menu) else { return "" }
        return UpgradeDefinitions.menu[menu].name
    }

    private var message: String {
        guard let menu = pendingMenu, UpgradeDefinitions.menu.indices.contains(menu) else { return "" }
        return String(format: String(localized: "dish.unlock.message"),
                      CoinFormat.string(UpgradeDefinitions.menu[menu].coinCost), dishName)
    }

    private func confirm() {
        guard let menu = pendingMenu else { return }
        pendingMenu = nil
        // A stale alert (coins spent or the dish bought meanwhile) must not buy twice or the wrong dish.
        guard case .available = MenuUnlockSystem.status(for: store.stall, menuIndex: menu) else { return }
        store.purchaseUpgrade(.menu)
        guard store.stall.menuTier >= menu else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DotSound.shared.play(.purchase)
    }
}
