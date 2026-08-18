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
            Image("money_bag")
                .resizable()
                .frame(width: 14, height: 14)
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

/// Shows the shop's star rating (e.g. ★ 3.8) in the top-center HUD.
public struct RatingBadge: View {
    @EnvironmentObject var store: GameStore

    public init() {}

    public var body: some View {
        HStack(spacing: 3) {
            Text("★")
                .font(.caption.bold())
                .foregroundStyle(starColor)
            Text(String(format: "%.1f", store.progress.rating))
                .font(.caption.bold())
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.spring(duration: 0.3), value: store.progress.rating)
    }

    private var starColor: Color {
        let r = store.progress.rating
        if r >= 4.0 { return Color(red: 1.0, green: 0.80, blue: 0.0) }
        if r >= 2.5 { return Color(red: 0.95, green: 0.60, blue: 0.1) }
        return Color(red: 0.85, green: 0.25, blue: 0.2)
    }
}
