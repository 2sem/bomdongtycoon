import Foundation

/// The prestige ("새봄 맞이") maths and the text built from it. Pure; the count lives in
/// `PlayerProgress.prestigeCount`.
public enum PrestigeSystem {

    /// Revenue multiplier a player with `prestigeCount` springs earns: 1 + 0.4 * n^0.75.
    /// Exactly 1.0 at n = 0, so a first-run player's prices are unchanged.
    public static func legacyMultiplier(prestigeCount: Int) -> Double {
        1 + 0.4 * pow(Double(max(0, prestigeCount)), 0.75)
    }

    /// "1.4", "1.67", "2": at most two decimals, trailing zeros trimmed, so the text matches the
    /// designed table (1.00 1.40 1.67 1.91 2.13 2.34).
    public static func multiplierNumber(_ multiplier: Double) -> String {
        var text = String(format: "%.2f", multiplier)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// "x1.4", the chip and row text.
    public static func multiplierText(prestigeCount: Int) -> String {
        "x" + multiplierNumber(legacyMultiplier(prestigeCount: prestigeCount))
    }
}

/// Number formatting for the stats sheet, kept apart from the view so it can be tested.
public enum StatsFormat {

    /// Whole-minute abbreviated hours and minutes ("1시간 5분"), or nil under a minute so the
    /// caller can show its localized "1분 미만".
    public static func duration(seconds: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String? {
        guard seconds.isFinite, seconds >= 60 else { return nil }
        let minutes = (seconds / 60).rounded(.down)
        var style = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes], width: .abbreviated)
        style.locale = locale
        return Duration.seconds(minutes * 60).formatted(style)
    }

    /// "87%" from served / (served + failed), or nil before any customer has left.
    public static func successRate(served: Int, failed: Int) -> String? {
        let outcomes = served + failed
        guard outcomes > 0 else { return nil }
        return "\(Int((Double(served) / Double(outcomes) * 100).rounded(.down)))%"
    }
}
