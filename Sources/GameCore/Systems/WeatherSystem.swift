import Foundation

public enum Weather: Equatable, CaseIterable {
    case clear, rain, snow, leaves, petals

    /// The events a clear gap can lead into, in the order a roll selects them.
    public static let events: [Weather] = [.rain, .snow, .leaves, .petals]
}

/// What a weather does to the shop. Every event has an upside and a tradeoff, never a pure
/// penalty. Multipliers compose on top of fever, not instead of it.
public struct WeatherEffect: Equatable {
    /// Crop growth rate.
    public var growth: Double = 1
    /// Seconds between customers: above 1 is fewer customers, below 1 is more.
    public var spawnInterval: Double = 1
    /// Walking speed of customers on the street.
    public var walkSpeed: Double = 1
    /// How long a queued customer waits before giving up.
    public var patience: Double = 1
    /// Sale price.
    public var price: Double = 1
    /// Added to the chance that a served customer leaves a tip.
    public var tipChance: Double = 0

    public static let clear = WeatherEffect()

    /// Rain hurries people home, snow slows them and warms the wallet, autumn wind brings the
    /// patient crowd, spring blossom brings the biggest, tipping strollers.
    public static func effect(for weather: Weather) -> WeatherEffect {
        switch weather {
        case .clear:  return .clear
        case .rain:   return WeatherEffect(growth: 2, spawnInterval: 1.3, walkSpeed: 1.3, patience: 0.85)
        case .snow:   return WeatherEffect(spawnInterval: 1.2, walkSpeed: 0.7, patience: 1.25, price: 1.15)
        case .leaves: return WeatherEffect(spawnInterval: 0.8, patience: 1.25)
        case .petals: return WeatherEffect(spawnInterval: 0.7, walkSpeed: 0.85, tipChance: 0.15)
        }
    }
}

/// Transient. `timer` is the seconds until `upcoming` starts (clear) or until the running event
/// ends; nil means the next event has not been rolled yet, which happens on the first advance.
public struct WeatherState: Equatable {
    public var weather: Weather = .clear
    public var timer: Double? = nil
    /// The event the current clear gap leads into; rolled together with the gap.
    public var upcoming: Weather? = nil
}

public enum WeatherSystem {
    public static let minGap: Double = 150
    public static let maxGap: Double = 300
    public static let eventDuration: Double = 30

    /// `roll` returns a value in 0..<1. A gap costs two rolls: its length, then which event.
    public static func advance(_ state: inout WeatherState, deltaTime: Double, roll: () -> Double) {
        var left = deltaTime
        if state.timer == nil { rollGap(&state, roll) }
        while left > 0, let timer = state.timer {
            if timer > left {
                state.timer = timer - left
                return
            }
            left -= timer
            if state.weather == .clear {
                state.weather = state.upcoming ?? Weather.events[0]
                state.upcoming = nil
                state.timer = eventDuration
            } else {
                state.weather = .clear
                rollGap(&state, roll)
            }
        }
    }

    public static func growthMultiplier(_ state: WeatherState) -> Double {
        WeatherEffect.effect(for: state.weather).growth
    }

    /// Maps a 0..<1 roll onto the four events in equal shares.
    public static func event(forRoll roll: Double) -> Weather {
        let events = Weather.events
        return events[min(Int(min(max(roll, 0), 1) * Double(events.count)), events.count - 1)]
    }

    private static func rollGap(_ state: inout WeatherState, _ roll: () -> Double) {
        state.timer = minGap + min(max(roll(), 0), 1) * (maxGap - minGap)
        state.upcoming = event(forRoll: roll())
    }
}
