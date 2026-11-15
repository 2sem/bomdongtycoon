import SwiftUI
import GameUI
import GoogleMobileAds

struct SplashView: View {
    @Binding var isDone: Bool
    @EnvironmentObject var adManager: SwiftUIAdManager

    var body: some View {
        ZStack {
            // Colour and layout mirror LaunchScreen.storyboard (same images, same offsets), so the hand-off is seamless.
            DotPalette.meadow.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchLogo")
                    .accessibilityHidden(true)
                Image("LaunchTitle")
                    .accessibilityLabel(String(localized: "봄동 타이쿤"))
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(height: 192, alignment: .top)
            .offset(y: -46)
        }
        .transition(.opacity)
        .onAppear { setup() }
    }

    private func setup() {
        adManager.setup()
        MobileAds.shared.start { [self] status in
            print("[AdMob] SDK started — adapters: \(status.adapterStatusesByClassName.count)")
            Task { @MainActor in
                adManager.preload()
                let deadline = Date().addingTimeInterval(3)
                while !adManager.isAppOpenReady && Date() < deadline {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                withAnimation(.easeOut(duration: 0.3)) {
                    isDone = true
                }
            }
        }
    }
}
