import SwiftUI
import GameCore

enum ShiftClock {
    static func string(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Above the flyer button: "Hire help" while a part-timer can be hired, the shift countdown while one works.
public struct PartTimerChip: View {
    @EnvironmentObject var store: GameStore
    let onTap: () -> Void

    public init(onTap: @escaping () -> Void) { self.onTap = onTap }

    public var body: some View {
        if store.isPartTimerActive {
            let time = ShiftClock.string(store.partTimerRemaining)
            label(String(format: String(localized: "dot.partTimer.active"), time), color: DotPalette.paper)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: String(localized: "dot.partTimer.active.accessibility"), time))
        } else if store.isPartTimerAvailable {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    DotImage("dot_ui_flyer", scale: 1)
                    Text(String(localized: "dot.partTimer.chip")).lineLimit(1)
                }
                .fixedSize()
            }
            .buttonStyle(.dotCompact)
            .accessibilityLabel(String(localized: "dot.partTimer.chip.accessibility"))
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            DotImage("dot_ui_flyer", scale: 1)
            Text(text).dotText(.caption, color: color).lineLimit(1).monospacedDigit()
        }
        .fixedSize()
        .dotPanel(.dark, padding: EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        .frame(minHeight: 44)
    }
}

/// HUD chip while the renovation rush runs.
public struct RushChip: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        if store.isRushActive {
            let time = ShiftClock.string(store.rushRemaining)
            HStack(spacing: 4) {
                DotImage("dot_ui_upgrade", scale: 1)
                Text(String(format: String(localized: "dot.rush.chip"), time))
                    .dotText(.caption, color: DotPalette.goldLight).lineLimit(1).monospacedDigit()
            }
            .fixedSize()
            .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: String(localized: "dot.rush.accessibility"), time))
        }
    }
}

/// 전단지 알바: what it does and the two ways to pay.
public struct PartTimerDialog: View {
    @EnvironmentObject var store: GameStore
    let isAdAvailable: Bool
    let isAdReady: Bool
    let onPayCoins: () -> Void
    let onWatchAd: () -> Void
    let onClose: () -> Void

    public init(isAdAvailable: Bool, isAdReady: Bool, onPayCoins: @escaping () -> Void,
                onWatchAd: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.isAdAvailable = isAdAvailable
        self.isAdReady = isAdReady
        self.onPayCoins = onPayCoins
        self.onWatchAd = onWatchAd
        self.onClose = onClose
    }

    public var body: some View {
        DotOverlay {
            VStack(spacing: 12) {
                Text(String(localized: "dot.partTimer.title")).dotText(.title).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(String(format: String(localized: "dot.partTimer.message"),
                            Int(PartTimerSystem.shiftDuration / 60)))
                    .dotText(.body, color: DotPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                coinButton
                if isAdAvailable { adButton }
                Button(action: onClose) {
                    Text(String(localized: "닫기")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.dotQuiet)
            }
        }
    }

    private var coinButton: some View {
        Button(action: onPayCoins) {
            HStack(spacing: 4) {
                DotImage("dot_ui_coin", scale: 1)
                Text(String(format: String(localized: "dot.partTimer.coins"), CoinFormat.string(store.partTimerFee)))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dot)
        .disabled(!store.canAffordPartTimer)
    }

    private var adButton: some View {
        let title = String(localized: "dot.partTimer.ad")
        return Button(action: onWatchAd) {
            Group {
                if isAdReady {
                    DotAdLabel(text: title)
                } else {
                    Text(String(localized: "dot.ad.loading"))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dot)
        .disabled(!isAdReady)
        .accessibilityLabel(isAdReady ? DotAdText.accessibility(title) : String(localized: "dot.ad.loading"))
    }
}
