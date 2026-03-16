import SwiftUI;
import GameCore;

public struct TutorialOverlay: View {
    @EnvironmentObject var store: GameStore;
    @State private var step = 0;

    private let steps: [(emoji: String, title: String, subtitle: String)] = [
        ("🥬", "봄동에 오신 걸 환영해요!", "봄봄봄 — 봄동 가게를 운영해보세요"),
        ("👆", "코인을 탭해서 수집하세요!", "손님이 오면 💰 버블이 나타나요"),
        ("⬆️", "코인으로 가게를 업그레이드!", "더 많은 손님, 더 많은 수익!")
    ];

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea();
            VStack(spacing: 24) {
                Text(steps[step].emoji)
                    .font(.system(size: 72));
                Text(steps[step].title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center);
                Text(steps[step].subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center);
                Button(step < steps.count - 1 ? "다음 →" : "시작하기! 🥬") {
                    if step < steps.count - 1 {
                        withAnimation { step += 1; }
                    } else {
                        store.markFirstLaunchComplete();
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14));
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(24);
        }
        .transition(.opacity);
    }
}
