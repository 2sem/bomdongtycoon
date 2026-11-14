import SwiftUI
import GameCore

public struct ShopNameOverlay: View {
    @EnvironmentObject var store: GameStore
    @State private var name = ""
    @FocusState private var focused: Bool

    public init() {}

    public var body: some View {
        DotOverlay {
            VStack(spacing: 14) {
                DotImage("dot_ui_logo", scale: 2)
                Text(String(localized: "가게 이름을 정해주세요!"))
                    .dotText(.title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(String(localized: "dot.name.subtitle"))
                    .dotText(.body, color: DotPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $name,
                          prompt: Text(String(localized: "봄동 가게")).foregroundColor(DotPalette.grey))
                    .font(.dot(.bold))
                    .foregroundStyle(DotPalette.paper)
                    .tint(DotPalette.goldLight)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { store.setShopName(name) }
                    .frame(minHeight: 28)
                    .dotPanel(.dark)
                    .accessibilityLabel(String(localized: "dot.name.field"))

                Button { store.setShopName(name) } label: {
                    Text(String(localized: "dot.start")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.dot)
            }
        }
        .onAppear { focused = true }
    }
}
