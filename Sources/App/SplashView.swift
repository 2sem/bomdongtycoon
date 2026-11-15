import SwiftUI
import GameUI
import GoogleMobileAds

struct SplashView: View {
    @Binding var isDone: Bool
    @EnvironmentObject var adManager: SwiftUIAdManager

    var body: some View {
        ZStack {
            // Same colour as LaunchScreen.storyboard, so the hand-off from launch to splash is seamless.
            DotPalette.meadow.ignoresSafeArea()

            VStack(spacing: 20) {
                DotImage("dot_ui_logo", scale: 4)
                Text(String(localized: "봄동 타이쿤"))
                    .dotText(.title, color: DotPalette.paper, shadow: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .offset(y: -24)
        }
        .transition(.opacity)
        .onAppear { setup() }
    }

    private func setup() {
        MobileAds.shared.start { [self] status in
            print("[AdMob] SDK started — adapters: \(status.adapterStatusesByClassName.count)")
            Task { @MainActor in
                adManager.setup()
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
