import SwiftUI
import GameCore

/// Shows spendable coins in Korean format (e.g. ₩1,234).
public struct CoinBadge: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dynamicTypeSize) private var typeSize

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text("₩")
                .font(.caption.bold())
                .foregroundStyle(.yellow)
            Text(formatted)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        // Hangs off the corner without taking layout space, so the first-run row is unchanged.
        .overlay(alignment: .bottomTrailing) {
            if showsLegacyChip { legacyChip }
        }
        .accessibilityElement(children: prestigeCount > 0 ? .combine : .contain)
        .accessibilityValue(prestigeCount > 0 ? legacyAccessibilityValue : "")
    }

    private var prestigeCount: Int { store.progress.prestigeCount }

    /// Dropped at accessibility sizes, where the chip would collide with the next badge.
    private var showsLegacyChip: Bool { prestigeCount > 0 && !typeSize.isAccessibilitySize }

    private var legacyChip: some View {
        Text("✨" + PrestigeSystem.multiplierText(prestigeCount: prestigeCount))
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.orange.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
            .offset(x: 4, y: 9)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var legacyAccessibilityValue: String {
        String(
            format: String(localized: "prestige.multiplier.accessibility"),
            PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: prestigeCount)))
    }

    private var formatted: String {
        CoinFormat.string(store.stall.coins)
    }
}

/// Shows the shop's star rating (e.g. ★ 3.8) in the top-center HUD.
public struct RatingBadge: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 3) {
            Text("★")
                .font(.caption.bold())
                .foregroundStyle(starColor)
            Text(String(format: "%.1f", store.progress.rating))
                .font(.caption.bold())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.spring(duration: 0.3), value: store.progress.rating)
    }

    private var starColor: Color {
        let r = store.progress.rating
        if r >= 4.0 { return Color(red: 1.0, green: 0.80, blue: 0.0) }
        if r >= 2.5 { return Color(red: 0.95, green: 0.60, blue: 0.1) }
        return Color(red: 0.85, green: 0.25, blue: 0.2)
    }
}
