import SwiftUI
import GameCore

public struct TutorialOverlay: View {
    @EnvironmentObject var store: GameStore
    @State private var step = 0

    private static let steps: [(emoji: String, title: String, subtitle: String)] = [
        ("🥬", String(localized: "tutorial.cook.title"), String(localized: "tutorial.cook.subtitle")),
        ("🌱", String(localized: "tutorial.farm.title"), String(localized: "tutorial.farm.subtitle")),
        ("🧑‍🍳", String(localized: "tutorial.staff.title"), String(localized: "tutorial.staff.subtitle")),
        ("⬆️", String(localized: "tutorial.goal.title"), String(localized: "tutorial.goal.subtitle"))
    ]

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(Self.steps[step].emoji)
                    .font(.system(size: 72))
                Text(Self.steps[step].title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(Self.steps[step].subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(step < Self.steps.count - 1 ? String(localized: "tutorial.next") : String(localized: "시작하기! 🥬")) {
                    if step < Self.steps.count - 1 {
                        withAnimation { step += 1 }
                    } else {
                        store.markFirstLaunchComplete()
                    }
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
        .transition(.opacity)
    }
}
