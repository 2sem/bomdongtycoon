import SwiftUI
import GameCore

public struct OfflineEarningsPopup: View {
    @EnvironmentObject var store: GameStore

    /// Called when user taps the 2x button. App layer shows the rewarded ad,
    /// then calls the completion with `true` if reward was earned, `false` to skip.
    let onWatchAd: (@escaping (Bool) -> Void) -> Void

    public init(onWatchAd: @escaping (@escaping (Bool) -> Void) -> Void) {
        self.onWatchAd = onWatchAd
    }

    public var body: some View {
        DotOverlay {
            VStack(spacing: 12) {
                DotImage("dot_ui_logo", scale: 1)
                Text(String(localized: "dot.offline.title"))
                    .dotText(.title)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "가게를 비운 동안 번 돈:"))
                    .dotText(.body, color: DotPalette.textSecondary)
                HStack(spacing: 6) {
                    DotImage("dot_ui_coin", scale: 2)
                    Text(CoinFormat.string(store.offlineEarnings))
                        .dotText(.title, color: DotPalette.goldDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .accessibilityElement(children: .combine)

                Button {
                    onWatchAd { rewarded in
                        store.collectOfflineEarnings(multiplier: rewarded ? 2.0 : 1.0)
                    }
                } label: {
                    Text(String(localized: "광고 보고 2배 받기")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.dot)

                Button { store.collectOfflineEarnings(multiplier: 1.0) } label: {
                    Text(String(localized: "그냥 받기")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.dotQuiet)
            }
        }
    }
}
