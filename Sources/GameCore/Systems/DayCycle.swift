import Foundation

public enum DayPhase: Equatable, CaseIterable {
    case morning, noon, dusk, night
}

/// Purely visual 4-minute loop driven by `totalPlaySeconds`.
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
}
