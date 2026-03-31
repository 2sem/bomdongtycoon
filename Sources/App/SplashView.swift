import SwiftUI
import GoogleMobileAds

struct SplashView: View {
    @Binding var isDone: Bool
    @EnvironmentObject var adManager: SwiftUIAdManager

    var body: some View {
        ZStack {
            Image("Splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text(String(localized: "봄동 타이쿤"))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 60)
            }
        }
        .transition(.opacity)
        .onAppear { setup() }
    }

    private func setup() {
        NotificationManager.requestPermission()
        GADMobileAds.sharedInstance().start { [self] status in
            print("[AdMob] SDK started — adapters: \(status.adapterStatusesByClassName.count)")
            adManager.preload()
            Task { @MainActor in
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
