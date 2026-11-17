import SwiftUI
import UIKit
import GameCore

/// "홍보" in the bottom row, beside the fever gauge: while the shop is quiet (rating under 3.0)
/// a tap pays a small fee and brings one customer in. Disabled with a filling bar while it cools down,
/// and with a red price while the coins are short.
///
/// Width (Galmuri11 Bold 12 pt: Hangul 12, digit 6): flyer icon 16 + 4 + "홍보" 24 + 4 + coin 16 + 2 +
/// fee + 24 panel padding is about 96 pt at a one-digit fee and 114 pt at four characters, against the
/// 125 pt left of a 375 pt row once the AD button (94) and fever gauge (128) are in. The style's 0.8
/// scale factor absorbs the last pt.
public struct FlyerButton: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPulsing: Bool
    let onTap: () -> Void
    @State private var pops: [Int] = []
    @State private var nextPop = 0

    public init(isPulsing: Bool = false, onTap: @escaping () -> Void = {}) {
        self.isPulsing = isPulsing
        self.onTap = onTap
    }

    public var body: some View {
        if store.isFlyerAvailable {
            TimelineView(.periodic(from: .now, by: 0.35)) { context in
                let hop = isPulsing && store.isFlyerReady && !reduceMotion
                    && Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
                button.offset(y: hop ? -DotTheme.px : 0)
            }
            .overlay(alignment: .top) { popLayer }
            .accessibilityLabel(accessibilityLabel)
            .onChange(of: store.flyerHandouts) { _, _ in addPop() }
        }
    }

    private var button: some View {
        Button {
            guard store.requestFlyer() else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            FlyerLabel(fee: CoinFormat.string(store.flyerFee), isShort: !store.canAffordFlyer)
        }
        .buttonStyle(.dotCompact)
        .disabled(!store.isFlyerReady)
        .overlay(alignment: .bottom) { cooldownBar }
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

    private var popLayer: some View {
        ZStack {
            ForEach(pops, id: \.self) { id in
                FlyerPop(reduceMotion: reduceMotion)
                    .id(id)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func addPop() {
        let id = nextPop
        nextPop += 1
        pops.append(id)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            pops.removeAll { $0 == id }
        }
    }

    private var accessibilityLabel: String {
        let fee = CoinFormat.string(store.flyerFee)
        if store.flyerCooldownRemaining > 0 {
            return String(format: String(localized: "dot.flyer.cooldown.accessibility"), fee,
                          Int(store.flyerCooldownRemaining.rounded(.up)))
        }
        if !store.canAffordFlyer { return String(format: String(localized: "dot.flyer.short.accessibility"), fee) }
        return String(format: String(localized: "dot.flyer.accessibility"), fee)
    }
}

private struct FlyerLabel: View {
    let fee: String
    let isShort: Bool
    @Environment(\.isEnabled) private var isEnabled

    /// One line, so it fits the compact face. The word takes the button style's own text (bold, paper or
    /// grey, ink drop); only the price overrides the colour. No `fixedSize`: a long fee must shrink.
    var body: some View {
        HStack(spacing: 4) {
            DotImage("dot_ui_flyer", scale: 1)
            Text(String(localized: "dot.flyer.button"))
            HStack(spacing: 2) {
                DotImage("dot_ui_coin", scale: 1)
                Text(fee).foregroundStyle(priceColor)
            }
        }
    }

    private var priceColor: Color {
        if isShort { return DotPalette.redDark }
        return isEnabled ? DotPalette.goldLight : DotPalette.greyDark
    }
}

/// "+1" and the fee rising from the button; a short static fade under Reduce Motion.
private struct FlyerPop: View {
    let reduceMotion: Bool
    @State private var isRisen = false

    var body: some View {
        Text("+1").dotText(.bold, color: DotPalette.goldLight, shadow: true)
            .offset(y: isRisen && !reduceMotion ? -34 : -10)
            .opacity(isRisen ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.8)) { isRisen = true } }
    }
}
