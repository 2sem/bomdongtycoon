import SwiftUI
import GameCore

public struct SeasonBanner: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.caption)
            Text(store.season.currentSeason.rawValue)
                .font(.caption.bold())
            Text("×\(String(format: "%.1f", multiplier))")
                .font(.caption)
                .foregroundStyle(.orange)
            if store.season.daysRemaining > 0 {
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(store.season.daysRemaining)일 남음")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var emoji: String {
        switch store.season.currentSeason {
        case .spring: "🌸"
        case .summer: "🌞"
        case .autumn: "🍂"
        case .winter: "❄️"
        }
    }

    private var multiplier: Double {
        SeasonSystem.earningsMultiplier(for: store.season.currentSeason)
    }
}
