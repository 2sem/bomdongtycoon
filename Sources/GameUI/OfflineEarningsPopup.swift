import SwiftUI
import GameCore

public struct OfflineEarningsPopup: View {
    @EnvironmentObject var store: GameStore

    /// Called when user taps the 2× button. App layer shows the rewarded ad,
    /// then calls the completion with `true` if reward was earned, `false` to skip.
    let onWatchAd: (@escaping (Bool) -> Void) -> Void

    public init(onWatchAd: @escaping (@escaping (Bool) -> Void) -> Void) {
        self.onWatchAd = onWatchAd
    }

    private func formattedEarnings(_ amount: Double) -> String {
        let value = Int(amount)
        if value >= 100_000_000 {
            let uk = (value + 50_000_000) / 100_000_000
            return String(localized: "약 \(uk)억원")
        } else if value >= 10_000 {
            let man = (value + 5_000) / 10_000
            return String(localized: "약 \(man)만원")
        } else {
            return String(localized: "₩\(value.formatted())원")
        }
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(String(localized: "🥬 돌아오셨군요!"))
                    .font(.title2.bold())
                Text(String(localized: "가게를 비운 동안 번 돈:"))
                    .foregroundStyle(.secondary)
                Text(formattedEarnings(store.offlineEarnings))
                    .font(.system(size: 48, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.orange)

                Button {
                    onWatchAd { rewarded in
                        let multiplier = rewarded ? 2.0 : 1.0
                        store.collectOfflineEarnings(multiplier: multiplier)
                    }
                } label: {
                    Label("광고 보고 2배 받기", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(String(localized: "그냥 받기")) {
                    store.collectOfflineEarnings(multiplier: 1.0)
                }
                .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
    }
}
