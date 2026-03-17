import SwiftUI
import GameCore

/// Shows spendable coins in Korean format (e.g. ₩1,234).
public struct CoinBadge: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text("₩")
                .font(.caption.bold())
                .foregroundStyle(.yellow)
            Text(formatted)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var formatted: String {
        let value = Int(store.stall.coins)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// Shows the player's total lifetime earnings in Korean format (e.g. 1,234,567원).
public struct TotalEarnedBadge: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Text("💰")
                .font(.caption)
            Text(formatted)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var formatted: String {
        let value = Int(store.progress.totalEarned)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number)원"
    }
}
