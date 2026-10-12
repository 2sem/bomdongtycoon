import Foundation

/// The one place a coin amount becomes text, so the HUD, goal pill, sheets and
/// VoiceOver labels all group digits the same way (39,530 and never 39530).
public enum CoinFormat {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    public static func string(_ value: Double) -> String {
        let whole = Int(value)
        return formatter.string(from: NSNumber(value: whole)) ?? "\(whole)"
    }
}
