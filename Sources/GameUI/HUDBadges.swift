import SwiftUI
import GameCore

/// Spendable coins as a pixel badge. Reports its centre (global points) so the scene can fly coins
/// to the real spot, and hops one pixel whenever coins arrive.
public struct CoinBadge: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHopped = false
    @State private var isDipped = false

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
        .offset(y: isHopped ? -DotTheme.px : isDipped ? DotTheme.px : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "dot.coins.accessibility"),
                                   CoinFormat.string(store.stall.coins)))
        .onChange(of: store.stall.coins) { old, new in
            if new > old { hop() } else if new < old { dip() }
        }
    }

    /// A purchase pushes the badge down one pixel, the mirror of the hop for income.
    private func dip() {
        guard !reduceMotion, !isDipped else { return }
        isDipped = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            isDipped = false
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
}

/// The prestige multiplier ("★x1.4"), shown once the player has prestiged. It has its own slot in
/// the HUD's top row; it used to hang off the coin badge and covered the status strip.
public struct LegacyChip: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Dims for one slow breath when a new spring lands, so the eye finds what is new.
    @State private var isDimmed = false

    public init() {}

    private var prestigeCount: Int { store.progress.prestigeCount }

    public var body: some View {
        if prestigeCount > 0 {
            HStack(spacing: 2) {
                DotImage("dot_ui_star", scale: 1)
                Text(PrestigeSystem.multiplierText(prestigeCount: prestigeCount))
                    .dotText(.caption, color: DotPalette.ink)
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(DotPalette.gold)
            .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px) }
            .opacity(isDimmed ? 0.25 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: String(localized: "prestige.multiplier.accessibility"),
                PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: prestigeCount))))
            .onReceive(NotificationCenter.default.publisher(for: .newSpringDidFinish)) { _ in pulse() }
        }
    }

    /// Odd leg count, so the animation ends on full opacity rather than snapping there.
    private func pulse() {
        guard !reduceMotion else { return }
        isDimmed = true
        withAnimation(.easeInOut(duration: 0.4).repeatCount(3, autoreverses: true)) { isDimmed = false }
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

/// Always-on weather chip. Clear: the icon of the weather that is coming and the time until it, as m:ss
/// (hidden until it is known). Running: seconds left and what it does for the shop.
public struct WeatherChip: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        let weather = store.weather
        if weather != .clear {
            let seconds = Int(store.weatherRemaining.rounded(.up))
            chip(icon: Self.icon(weather), tint: DotPalette.paper) {
                Text(String(format: String(localized: "dot.weather.seconds"), seconds))
                Text(Self.bonus(weather))
                    .foregroundStyle(DotPalette.goldLight)
            }
            .accessibilityLabel(Self.activeLabel(weather, seconds: seconds))
        } else {
            let seconds = Int(store.secondsUntilWeather.rounded(.up))
            if seconds > 0, let upcoming = store.upcomingWeather {
                chip(icon: Self.icon(upcoming), tint: DotPalette.paper) {
                    Text(String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
                }
                .accessibilityLabel(Self.upcomingLabel(upcoming, minutes: seconds / 60, seconds: seconds % 60))
            }
        }
    }

    static func icon(_ weather: Weather) -> String {
        switch weather {
        case .clear, .rain: return "dot_ui_rain"
        case .snow:         return "dot_ui_snow"
        case .leaves:       return "dot_ui_leaves"
        case .petals:       return "dot_ui_petals"
        }
    }

    private static func bonus(_ weather: Weather) -> String {
        switch weather {
        case .clear, .rain: return String(localized: "dot.weather.boost")
        case .snow:         return String(localized: "dot.weather.snow.bonus")
        case .leaves:       return String(localized: "dot.weather.leaves.bonus")
        case .petals:       return String(localized: "dot.weather.petals.bonus")
        }
    }

    private static func activeLabel(_ weather: Weather, seconds: Int) -> String {
        let format: String
        switch weather {
        case .clear, .rain: format = String(localized: "dot.weather.accessibility")
        case .snow:         format = String(localized: "dot.weather.snow.accessibility")
        case .leaves:       format = String(localized: "dot.weather.leaves.accessibility")
        case .petals:       format = String(localized: "dot.weather.petals.accessibility")
        }
        return String(format: format, seconds)
    }

    private static func upcomingLabel(_ weather: Weather, minutes: Int, seconds: Int) -> String {
        let format: String
        switch weather {
        case .clear, .rain: format = String(localized: "dot.weather.clear.accessibility")
        case .snow:         format = String(localized: "dot.weather.snow.clear.accessibility")
        case .leaves:       format = String(localized: "dot.weather.leaves.clear.accessibility")
        case .petals:       format = String(localized: "dot.weather.petals.clear.accessibility")
        }
        return String(format: format, minutes, seconds)
    }

    private func chip<Content: View>(icon: String, tint: Color, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            DotImage(icon, scale: 1)
            content().dotText(.caption, color: tint).fixedSize()
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .accessibilityElement(children: .ignore)
    }
}
