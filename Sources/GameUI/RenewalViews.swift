import SwiftUI
import GameCore

/// Beside the rating while a grand reopening is on offer: a short label that opens the dialog.
public struct RenewalChip: View {
    let onTap: () -> Void

    public init(onTap: @escaping () -> Void) { self.onTap = onTap }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                DotImage("dot_ui_upgrade", scale: 1)
                Text(String(localized: "dot.renewal.chip")).dotText(.caption, color: DotPalette.goldLight).fixedSize()
            }
            .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(String(localized: "dot.renewal.chip.accessibility"))
    }
}

/// 리뉴얼 오픈: what changes (the rating), what it costs, and the two ways to pay.
public struct RenewalDialog: View {
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

    private var ratingText: String { String(format: "%.1f", store.progress.rating) }
    private var targetText: String { String(format: "%.1f", RenewalSystem.resultingRating) }

    public var body: some View {
        DotOverlay {
            VStack(spacing: 12) {
                Text(String(localized: "dot.renewal.title")).dotText(.title).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "dot.renewal.message")).dotText(.body, color: DotPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    DotImage("dot_ui_star", scale: 2)
                    Text(String(format: String(localized: "dot.renewal.rating"), ratingText, targetText))
                        .dotText(.bold).monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: String(localized: "dot.renewal.rating.accessibility"),
                                           ratingText, targetText))
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
                Text(String(format: String(localized: "dot.renewal.coins"), CoinFormat.string(store.renewalFee)))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.dot)
        .disabled(!store.canAffordRenewal)
    }

    private var adButton: some View {
        let title = String(localized: "dot.renewal.ad")
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
