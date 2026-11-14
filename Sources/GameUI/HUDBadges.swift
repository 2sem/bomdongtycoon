import SwiftUI
import GameCore

/// Spendable coins as a pixel badge. Reports its centre (global points) so the scene can fly coins
/// to the real spot, and hops one pixel whenever coins arrive.
public struct CoinBadge: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Dims the legacy chip for one slow breath when a new spring lands, so the eye finds what is new.
    @State private var isChipDimmed = false
    @State private var isHopped = false

    private let onCenterChange: (CGPoint) -> Void

    public init(onCenterChange: @escaping (CGPoint) -> Void = { _ in }) {
        self.onCenterChange = onCenterChange
    }

    public var body: some View {
        HStack(spacing: 4) {
            DotImage("dot_ui_coin", scale: 1)
            Text(CoinFormat.string(store.stall.coins))
                .dotText(.bold)
                .lineLimit(1)
                .fixedSize()
        }
        .dotPanel(padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { onCenterChange($0) }
        .offset(y: isHopped ? -DotTheme.px : 0)
        // Hangs off the corner without taking layout space.
        .overlay(alignment: .bottomTrailing) {
            if showsLegacyChip { legacyChip }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "dot.coins.accessibility"),
                                   CoinFormat.string(store.stall.coins)))
        .accessibilityValue(prestigeCount > 0 ? legacyAccessibilityValue : "")
        .onChange(of: store.stall.coins) { old, new in
            if new > old { hop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newSpringDidFinish)) { _ in
            pulseChip()
        }
    }

    private func hop() {
        guard !reduceMotion, !isHopped else { return }
        isHopped = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            isHopped = false
        }
    }

    /// Odd leg count, so the animation ends on full opacity rather than snapping there.
    private func pulseChip() {
        guard !reduceMotion else { return }
        isChipDimmed = true
        withAnimation(.easeInOut(duration: 0.4).repeatCount(3, autoreverses: true)) {
            isChipDimmed = false
        }
    }

    private var prestigeCount: Int { store.progress.prestigeCount }

    private var showsLegacyChip: Bool { prestigeCount > 0 }

    private var legacyChip: some View {
        HStack(spacing: 2) {
            DotImage("dot_ui_star", scale: 1)
            Text(PrestigeSystem.multiplierText(prestigeCount: prestigeCount))
                .dotText(.caption, color: DotPalette.ink)
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 2)
        .background(DotPalette.gold)
        .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px) }
        .opacity(isChipDimmed ? 0.25 : 1)
        .offset(x: 4, y: 10)
        .allowsHitTesting(false)
    }

    private var legacyAccessibilityValue: String {
        String(
            format: String(localized: "prestige.multiplier.accessibility"),
            PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: prestigeCount)))
    }
}

/// The shop's star rating. The HUD wraps it in a button that opens the records.
public struct RatingBadge: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            DotImage("dot_ui_star", scale: 1)
            Text(String(format: "%.1f", store.progress.rating))
                .dotText(.bold, color: ratingColor)
                .fixedSize()
        }
        .dotPanel(padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
    }

    private var ratingColor: Color {
        let r = store.progress.rating
        if r >= 2.5 { return DotPalette.ink }
        return DotPalette.redDark
    }
}

/// Rain remaining, while it rains.
public struct WeatherChip: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        if store.weather == .rain {
            let seconds = Int(store.weatherRemaining.rounded(.up))
            HStack(spacing: 4) {
                DotImage("dot_ui_rain", scale: 1)
                Text(String(format: String(localized: "dot.weather.seconds"), seconds))
                    .dotText(.caption, color: DotPalette.paper)
                    .fixedSize()
            }
            .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: String(localized: "dot.weather.accessibility"), seconds))
        }
    }
}
