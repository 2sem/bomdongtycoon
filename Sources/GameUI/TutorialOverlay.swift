import SwiftUI
import GameCore

public struct TutorialOverlay: View {
    @EnvironmentObject var store: GameStore
    @State private var step = 0

    private struct Page {
        let sprites: [String]
        let title: String
        let subtitle: String
    }

    private static var pages: [Page] {
        [
            Page(sprites: ["dot_farm_plot_empty", "dot_farm_plot_growing", "dot_farm_plot_ready_0"],
                 title: String(localized: "dot.tutorial.farm.title"),
                 subtitle: String(localized: "dot.tutorial.farm.subtitle")),
            Page(sprites: ["dot_dish_geotjeori", "dot_char_man_idle_down", "dot_char_woman_idle_down"],
                 title: String(localized: "dot.tutorial.cook.title"),
                 subtitle: String(localized: "dot.tutorial.cook.subtitle")),
            Page(sprites: ["dot_ui_fever", "dot_farm_plot_golden_0"],
                 title: String(localized: "dot.tutorial.fever.title"),
                 subtitle: String(localized: "dot.tutorial.fever.subtitle")),
            Page(sprites: ["dot_ui_mission", "dot_char_alba_idle_down", "dot_ui_coin"],
                 title: String(localized: "dot.tutorial.goal.title"),
                 subtitle: String(format: String(localized: "dot.tutorial.goal.subtitle"),
                                  CoinFormat.string(UpgradeDefinitions.staff[0].coinCost)))
        ]
    }

    public init() {}

    private var isLast: Bool { step == Self.pages.count - 1 }

    public var body: some View {
        let page = Self.pages[step]
        DotOverlay {
            VStack(spacing: 14) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(page.sprites.enumerated()), id: \.offset) { _, name in
                        DotImage(name, scale: 3)
                    }
                }
                .frame(minHeight: 72)
                Text(page.title)
                    .dotText(.title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(page.subtitle)
                    .dotText(.body, color: DotPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                pageDots
                Button {
                    if isLast { store.markFirstLaunchComplete() } else { step += 1 }
                } label: {
                    Text(isLast ? String(localized: "dot.start") : String(localized: "tutorial.next"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dot)
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.pages.count, id: \.self) { index in
                Rectangle()
                    .fill(index == step ? DotPalette.leaf : DotPalette.sand)
                    .frame(width: 8, height: 8)
                    .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px / 2 * 1) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "dot.tutorial.page"), step + 1, Self.pages.count))
    }
}
