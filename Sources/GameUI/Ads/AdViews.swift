import SwiftUI
import UIKit
import GameCore

/// The small play-button badge that marks anything which plays an ad: a gold tile with an ink
/// triangle, drawn pixel by pixel so it needs no sprite.
struct DotAdIcon: View {
    private static let rows = [
        "#########",
        "#ggggggg#",
        "#g#ggggg#",
        "#g##gggg#",
        "#g###ggg#",
        "#g##gggg#",
        "#g#ggggg#",
        "#ggggggg#",
        "#########",
    ]

    var body: some View {
        Canvas { context, _ in
            for (y, row) in Self.rows.enumerated() {
                for (x, c) in row.enumerated() {
                    let rect = CGRect(x: CGFloat(x) * DotTheme.px, y: CGFloat(y) * DotTheme.px,
                                      width: DotTheme.px, height: DotTheme.px)
                    context.fill(Path(rect), with: .color(c == "g" ? DotPalette.gold : DotPalette.ink))
                }
            }
        }
        .frame(width: 9 * DotTheme.px, height: 9 * DotTheme.px)
        .accessibilityHidden(true)
    }
}

/// "AD" button label: the play badge, then the text.
struct DotAdLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            DotAdIcon()
            Text(text)
        }
    }
}

enum DotAdText {
    /// "충전, 광고가 재생돼요": every ad button says it plays an ad.
    static func accessibility(_ action: String) -> String {
        String(format: String(localized: "dot.ad.accessibility"), action)
    }
}

/// Centred pixel card offering one rewarded ad; the player can always close it.
public struct AdOfferDialog: View {
    let title: String
    let message: String
    let rewardCoins: Double?
    let actionTitle: String
    let isReady: Bool
    let onWatch: () -> Void
    let onClose: () -> Void

    public init(title: String, message: String, rewardCoins: Double? = nil, actionTitle: String, isReady: Bool,
                onWatch: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.rewardCoins = rewardCoins
        self.actionTitle = actionTitle
        self.isReady = isReady
        self.onWatch = onWatch
        self.onClose = onClose
    }

    public var body: some View {
        DotOverlay {
            VStack(spacing: 12) {
                Text(title).dotText(.title).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(message).dotText(.body, color: DotPalette.textSecondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let rewardCoins {
                    HStack(spacing: 6) {
                        DotImage("dot_ui_coin", scale: 2)
                        Text(CoinFormat.string(rewardCoins)).dotText(.title, color: DotPalette.goldDark)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .accessibilityElement(children: .combine)
                }
                Button(action: onWatch) {
                    Group {
                        if isReady {
                            DotAdLabel(text: actionTitle)
                        } else {
                            Text(String(localized: "dot.ad.loading"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dot)
                .disabled(!isReady)
                .accessibilityLabel(isReady ? DotAdText.accessibility(actionTitle) : String(localized: "dot.ad.loading"))
                Button(action: onClose) {
                    Text(String(localized: "닫기")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.dotQuiet)
            }
        }
    }
}

/// "AD 충전" beside the fever gauge: opens the offer dialog that fills it from an ad. Hops one pixel
/// only while it owns the screen's single pulse.
public struct FeverAdButton: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ads: RewardedAds
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPulsing: Bool
    let onTap: () -> Void

    public init(isPulsing: Bool, onTap: @escaping () -> Void) {
        self.isPulsing = isPulsing
        self.onTap = onTap
    }

    public var body: some View {
        if store.isFeverAdAvailable {
            let isReady = ads.isReady(.fever)
            TimelineView(.periodic(from: .now, by: 0.35)) { context in
                let hop = isPulsing && isReady && !reduceMotion
                    && Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
                Button(action: onTap) {
                    if isReady {
                        DotAdLabel(text: String(localized: "dot.ad.fever.charge"))
                    } else {
                        Text(String(localized: "dot.ad.loading"))
                    }
                }
                .buttonStyle(.dotCompact)
                .disabled(!isReady)
                .offset(y: hop ? -DotTheme.px : 0)
            }
            .accessibilityLabel(DotAdText.accessibility(String(localized: "dot.ad.fever.accessibility")))
            .onAppear { ads.prepare(.fever) }
        }
    }
}

/// Next to the weather chip: "AD x2" when a boost can be bought, the countdown while it runs (a button
/// that extends it while there is room for another ad), the cooldown after. Tapping an available chip asks for confirmation (the dialog lives in the root).
public struct BoostChip: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ads: RewardedAds
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPulsing: Bool
    let onTap: () -> Void

    public init(isPulsing: Bool, onTap: @escaping () -> Void) {
        self.isPulsing = isPulsing
        self.onTap = onTap
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let active = store.boostRemaining
            let cooling = store.boostCooldownRemaining
            if active > 0, store.isBoostExtendable {
                Button(action: onTap) {
                    chip(icon: AnyView(DotAdIcon())) {
                        Text(String(format: String(localized: "dot.boost.active"), Self.clock(active)))
                            .foregroundStyle(DotPalette.goldLight)
                    }
                    .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DotAdText.accessibility(
                    String(format: String(localized: "dot.boost.extend.accessibility"), Self.clock(active))))
                .onAppear { ads.prepare(.boost) }
            } else if active > 0 {
                chip(icon: AnyView(DotImage("dot_ui_fever", scale: 1))) {
                    Text(String(format: String(localized: "dot.boost.active"), Self.clock(active)))
                        .foregroundStyle(DotPalette.goldLight)
                }
                .accessibilityLabel(String(format: String(localized: "dot.boost.active.accessibility"), Self.clock(active)))
            } else if cooling > 0 {
                chip(icon: AnyView(DotImage("dot_ui_clock", scale: 1))) { Text(Self.clock(cooling)) }
                    .opacity(0.8)
                    .accessibilityLabel(String(format: String(localized: "dot.boost.cooldown.accessibility"), Self.clock(cooling)))
            } else if store.isBoostAvailable {
                let hop = isPulsing && !reduceMotion
                    && Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
                Button(action: onTap) {
                    chip(icon: AnyView(DotAdIcon())) {
                        Text(String(localized: "dot.boost.available")).foregroundStyle(DotPalette.goldLight)
                    }
                    .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                .offset(y: hop ? -DotTheme.px : 0)
                .accessibilityLabel(DotAdText.accessibility(String(localized: "dot.boost.accessibility")))
                .onAppear { ads.prepare(.boost) }
            }
        }
    }

    private func chip<Content: View>(icon: AnyView, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 4) {
            icon
            content().dotText(.caption, color: DotPalette.paper).fixedSize()
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        .accessibilityElement(children: .ignore)
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
