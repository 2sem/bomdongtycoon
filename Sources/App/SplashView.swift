import SwiftUI
import GoogleMobileAds

struct SplashView: View {
    @Binding var isDone: Bool
    @EnvironmentObject var rewardAd: SwiftUIRewardAdManager

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🥬")
                    .font(.system(size: 72))
                Text("봄동 타이쿤")
                    .font(.title.bold())
            }
        }
        .transition(.opacity)
        .onAppear {
            setup()
        }
    }

    private func setup() {
        NotificationManager.requestPermission()
        GADMobileAds.sharedInstance().start { status in
            print("[AdMob] SDK started — adapters: \(status.adapterStatusesByClassName.count)")
            rewardAd.preload()
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    isDone = true
                }
            }
        }
    }
}
