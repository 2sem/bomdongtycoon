import Foundation

public enum SeasonSystem {

    static let springDurationDays: Double = 30

    public static func currentState(seasonStart: Date, now: Date = Date()) -> SeasonState {
        let elapsed = now.timeIntervalSince(seasonStart)
        let daysPassed = elapsed / 86400
        var state = SeasonState()
        state.seasonStartDate = seasonStart

        if daysPassed < springDurationDays {
            state.currentSeason = .spring
            state.daysRemaining = Int(springDurationDays - daysPassed)
        } else {
            state.currentSeason = .summer
            state.daysRemaining = 0
        }
        return state
    }

    public static func earningsMultiplier(for season: Season) -> Double {
        switch season {
        case .spring: return 1.0
        case .summer: return 1.5
        case .autumn: return 1.2
        case .winter: return 1.0
        }
    }
}
