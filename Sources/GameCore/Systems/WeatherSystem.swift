import Foundation

public enum Weather: Equatable {
    case clear, rain
}

/// Transient. `timer` is the seconds until rain starts (clear) or until it ends (rain);
/// nil means the next rain has not been rolled yet, which happens on the first advance.
public struct WeatherState: Equatable {
    public var weather: Weather = .clear
    public var timer: Double? = nil
}

public enum WeatherSystem {
    public static let minGap: Double = 150
    public static let maxGap: Double = 300
    public static let rainDuration: Double = 30
    public static let rainGrowthMultiplier: Double = 2

    /// `roll` returns a value in 0..<1.
    public static func advance(_ state: inout WeatherState, deltaTime: Double, roll: () -> Double) {
        var left = deltaTime
        if state.timer == nil { state.timer = rollGap(roll) }
        while left > 0, let timer = state.timer {
            if timer > left {
                state.timer = timer - left
                return
            }
            left -= timer
            switch state.weather {
            case .clear:
                state.weather = .rain
                state.timer = rainDuration
            case .rain:
                state.weather = .clear
                state.timer = rollGap(roll)
            }
        }
    }

    public static func growthMultiplier(_ state: WeatherState) -> Double {
        state.weather == .rain ? rainGrowthMultiplier : 1
    }

    private static func rollGap(_ roll: () -> Double) -> Double {
        minGap + min(max(roll(), 0), 1) * (maxGap - minGap)
    }
}
