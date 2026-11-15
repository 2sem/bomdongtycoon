import Foundation

public enum DayPhase: Equatable, CaseIterable {
    case morning, noon, dusk, night
}

/// The 4-minute day driven by `totalPlaySeconds`. Its phases are visual; the loop boundary is payday
/// (`WageSystem`).
public enum DayCycle {
    public static let loopSeconds: Double = 240

    /// 0..<1 through the loop; 0 is the start of morning.
    public static func progress(playSeconds: Double) -> Double {
        let wrapped = playSeconds.truncatingRemainder(dividingBy: loopSeconds)
        return (wrapped < 0 ? wrapped + loopSeconds : wrapped) / loopSeconds
    }

    public static func phase(playSeconds: Double) -> DayPhase {
        switch progress(playSeconds: playSeconds) {
        case ..<0.25: .morning
        case ..<0.5:  .noon
        case ..<0.75: .dusk
        default:      .night
        }
    }

    /// Whole days of play so far; the day ticks over when night ends and the next morning starts.
    public static func dayIndex(playSeconds: Double) -> Int {
        Int((max(0, playSeconds) / loopSeconds).rounded(.down))
    }

    /// Play seconds left before the next day, and with it payday.
    public static func secondsUntilNextDay(playSeconds: Double) -> Double {
        loopSeconds * (1 - progress(playSeconds: max(0, playSeconds)))
    }
}
