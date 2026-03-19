import SwiftUI

struct SplashView: View {
    @Binding var isDone: Bool

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
    }
}
