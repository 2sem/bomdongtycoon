import SwiftUI
import GameCore

/// Bottom navigation: upgrades, staff, missions, records. Each tab opens a sheet, so none stays selected.
public struct DotTabBar: View {
    @EnvironmentObject var store: GameStore
    let onUpgrades: () -> Void
    let onStaff: () -> Void
    let onMissions: () -> Void
    let onStats: () -> Void

    public init(onUpgrades: @escaping () -> Void, onStaff: @escaping () -> Void,
                onMissions: @escaping () -> Void, onStats: @escaping () -> Void) {
        self.onUpgrades = onUpgrades
        self.onStaff = onStaff
        self.onMissions = onMissions
        self.onStats = onStats
    }

    public var body: some View {
        HStack(spacing: 0) {
            tab("dot_ui_upgrade", String(localized: "업그레이드"), badge: 0, action: onUpgrades)
            tab("dot_ui_staff", String(localized: "dot.tab.staff"), badge: 0, action: onStaff)
            tab("dot_ui_mission", String(localized: "dot.tab.missions"),
                badge: store.unclaimedCompletedMissionCount, action: onMissions)
            tab("dot_ui_stats", String(localized: "stats.title"), badge: 0, action: onStats)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(alignment: .top) {
            DotPalette.plum
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        DotPalette.ink.frame(height: DotTheme.px)
                        DotPalette.mauve.frame(height: DotTheme.px)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ icon: String, _ title: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                DotImage(icon, scale: 2)
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 { DotBadge(badge).offset(x: 8, y: -4) }
                    }
                Text(title)
                    .dotText(.caption, color: DotPalette.paper)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(DotTabButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(badge > 0 ? String(format: String(localized: "dot.tab.badge.accessibility"), badge) : "")
    }
}

private struct DotTabButtonStyle: ButtonStyle {
    @Environment(\.dotPlaySound) private var play

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? DotTheme.px : 0)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in if pressed { play(.tap) } }
    }
}
