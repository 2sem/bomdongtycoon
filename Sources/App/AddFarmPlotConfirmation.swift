import SwiftUI
import UIKit
import GameCore

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
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 56)
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
            return String(
                localized: "💰 \(price)을 내면 밭이 \(count)칸에서 \(count + 1)칸으로 늘어나요. 새 칸에도 작물을 심을 수 있어요.")
        }
        return String(
            localized: "💰 \(price)이 필요해요. 코인을 더 모으면 밭을 \(count + 1)칸으로 넓힐 수 있어요.")
    }

    private func confirm() {
        guard let count = pendingPlotCount else { return }
        pendingPlotCount = nil
        guard store.farm.plots.count == count else { return }
        store.purchaseUpgrade(.farm)
        guard store.farm.plots.count == count + 1 else { return }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let text = String(localized: "🌱 밭이 \(count + 1)칸이 됐어요!")
        AccessibilityNotification.Announcement(
            String(localized: "밭이 \(count + 1)칸으로 늘어났습니다.")
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
