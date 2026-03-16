import SwiftUI;
import GameCore;

public struct OfflineEarningsPopup: View {
    @EnvironmentObject var store: GameStore;

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea();
            VStack(spacing: 20) {
                Text("🥬 돌아오셨군요!")
                    .font(.title2.bold());
                Text("가게를 비운 동안 번 돈:")
                    .foregroundStyle(.secondary);
                Text("💰 \(Int(store.offlineEarnings))원")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.orange);

                Button {
                    // 2x ad reward — AdManager called from App layer before this
                    store.applyOfflineEarnings(multiplier: 2.0);
                    store.offlineEarnings = 0;
                } label: {
                    Label("광고 보고 2배 받기", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14));
                }

                Button("그냥 받기") {
                    store.applyOfflineEarnings(multiplier: 1.0);
                    store.offlineEarnings = 0;
                }
                .foregroundStyle(.secondary);
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(32);
        }
    }
}
