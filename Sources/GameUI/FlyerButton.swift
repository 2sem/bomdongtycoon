import SwiftUI
import UIKit
import GameCore

/// "전단지" in the bottom row, beside the fever gauge: while the shop is quiet (rating under 3.0)
/// a tap brings one customer in. Disabled with a filling bar while it cools down.
public struct FlyerButton: View {
    @EnvironmentObject var store: GameStore
    let onTap: () -> Void

    public init(onTap: @escaping () -> Void = {}) { self.onTap = onTap }

    public var body: some View {
        if store.isFlyerAvailable {
            Button {
                guard store.requestFlyer() else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap()
            } label: {
                HStack(spacing: 4) {
                    DotImage("dot_ui_flyer", scale: 1)
                    Text(String(localized: "dot.flyer.button"))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.dotCompact)
            .disabled(!store.isFlyerReady)
            .overlay(alignment: .bottom) { cooldownBar }
            .accessibilityLabel(accessibilityLabel)
        }
    }

    /// Fills left to right over the cooldown, in whole art pixels like the other gauges.
    @ViewBuilder
    private var cooldownBar: some View {
        let progress = store.flyerCooldownProgress
        if progress < 1 {
            GeometryReader { geo in
                let px = DotTheme.px
                let width = ((geo.size.width - 16 * px) * progress / px).rounded(.down) * px
                Rectangle().fill(DotPalette.goldDark)
                    .frame(width: max(0, width), height: px)
                    .offset(x: 8 * px, y: geo.size.height - 9 * px)
            }
            .allowsHitTesting(false)
        }
    }

    private var accessibilityLabel: String {
        guard store.flyerCooldownRemaining > 0 else { return String(localized: "dot.flyer.accessibility") }
        return String(format: String(localized: "dot.flyer.cooldown.accessibility"),
                      Int(store.flyerCooldownRemaining.rounded(.up)))
    }
}
