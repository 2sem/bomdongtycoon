import SwiftUI
import GameCore

public struct ShopNameOverlay: View {
    @EnvironmentObject var store: GameStore
    @State private var name = ""
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("⛺")
                    .font(.system(size: 64))
                Text("가게 이름을 정해주세요!")
                    .font(.title2.bold())
                Text("당신만의 봄동 가게를 만들어보세요 🥬")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                TextField("봄동 가게", text: $name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                Button("시작하기! 🥬") {
                    store.setShopName(name)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
        .onAppear { focused = true }
        .transition(.opacity)
    }
}
