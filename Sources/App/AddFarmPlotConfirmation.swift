import SwiftUI
import UIKit
import GameCore
import GameUI

/// Confirm-then-purchase for the field's `plot_add` cell, same shape as
/// the location move in `UpgradeSheet`: a two-button alert naming the
/// cost and the gain, a re-check on confirm so a stale alert cannot buy
/// twice, a success haptic, and a VoiceOver announcement plus a short
/// toast. `MainStallScene` only posts `.requestAddFarmPlot`; the alert
/// lives here because SwiftUI owns every modal in this app.
struct AddFarmPlotConfirmation: ViewModifier {
    @EnvironmentObject private var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingPlotCount: Int?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .requestAddFarmPlot)) { _ in
                guard FarmSystem.costForNextPlot(currentCount: store.farm.plots.count) != nil else { return }
                pendingPlotCount = store.farm.plots.count
            }
            .alert(
                String(localized: "밭을 넓힐까요?"),
                isPresented: Binding(
                    get: { pendingPlotCount != nil },
                    set: { if !$0 { pendingPlotCount = nil } }
                )
            ) {
                if canAfford {
                    Button(String(localized: "넓히기")) { confirm() }
                    Button(String(localized: "취소"), role: .cancel) {}
                } else {
                    Button(String(localized: "확인"), role: .cancel) {}
                }
            } message: {
                Text(message)
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .dotText(.bold, color: DotPalette.paper, shadow: true)
                        .multilineTextAlignment(.center)
                        .dotPanel(.dark, padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                        .padding(.top, 96)
                        .transition(.opacity)
                        .accessibilityHidden(true) // announced separately
                }
            }
    }

    private var cost: Double? {
        pendingPlotCount.flatMap { FarmSystem.costForNextPlot(currentCount: $0) }
    }

    private var canAfford: Bool {
        guard let cost else { return false }
        return store.stall.coins >= cost
    }

    private var message: String {
        guard let cost, let count = pendingPlotCount else { return "" }
        let price = Self.formatted(cost)
        if canAfford {
            return String(format: String(localized: "dot.plot.message"), price, count, count + 1)
        }
        return String(format: String(localized: "dot.plot.short"), price, count + 1)
    }

    private func confirm() {
        guard let count = pendingPlotCount else { return }
        pendingPlotCount = nil
        guard store.farm.plots.count == count else { return }
        store.purchaseUpgrade(.farm)
        guard store.farm.plots.count == count + 1 else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DotSound.shared.play(.purchase)
        let text = String(format: String(localized: "dot.plot.toast"), count + 1)
        AccessibilityNotification.Announcement(
            String(format: String(localized: "dot.plot.announce"), count + 1)
        ).post()

        toastTask?.cancel()
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4)
        withAnimation(animation) { toast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { toast = nil }
        }
    }

    private static func formatted(_ value: Double) -> String {
        CoinFormat.string(value)
    }
}
