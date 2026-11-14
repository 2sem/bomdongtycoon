import Foundation

/// Transient fever state; lives in the store's run transients, never saved.
public struct FeverState: Equatable {
    public var charge: Double = 0
    /// Seconds since the last served customer; charge only decays once this passes `decayDelay`.
    public var secondsSinceSale: Double = 0
    public var remaining: Double = 0
}

public enum FeverSystem {
    /// Floor of the charge a serve adds (a 36-serve gauge at the fastest pace).
    public static let chargePerServe: Double = 1.0 / 36.0
    /// The gauge is sized to pace: a serve adds `interval / paceSeconds`, so a steady player fills it in
    /// about this many seconds at any rating, however slowly customers arrive.
    public static let paceSeconds: Double = 90.0

    /// `spawnInterval` is the non-fever customer interval at the current rating.
    public static func charge(perServeAtInterval spawnInterval: Double) -> Double {
        max(chargePerServe, spawnInterval / paceSeconds)
    }
    /// Applied when the customer waited less than `fastServeWait`.
    public static let fastServeBonus: Double = 1.5
    public static let fastServeWait: Double = 2.0
    public static let decayDelay: Double = 6.0
    public static let decayPerSecond: Double = 1.0 / 60.0
    public static let duration: Double = 15.0
    public static let priceMultiplier: Double = 3.0
    public static let spawnIntervalMultiplier: Double = 0.35
    /// Crops ripen this much faster during fever (12 s -> 4 s). Instant tap cooking drains the
    /// warehouse in about seven seconds; without this the last half of the rush has nothing to tap.
    public static let growthMultiplier: Double = 3

    /// Free portions every unlocked dish gets when a fever starts, so the rush does not starve the counter.
    public static let startingPortions: Int = 4

    /// Ten serves sum to 0.9999999999999999 in floating point; "full" must tolerate that.
    private static let fullTolerance = 1e-9

    public static func isActive(_ state: FeverState) -> Bool { state.remaining > 0 }

    public static func isReady(_ state: FeverState) -> Bool {
        !isActive(state) && state.charge >= 1 - fullTolerance
    }

    /// Charge does not accumulate while fever is active, but the sale still restarts the decay delay.
    public static func recordServed(_ state: inout FeverState, waitTime: Double, baseCharge: Double = chargePerServe) {
        state.secondsSinceSale = 0
        guard !isActive(state) else { return }
        let gain = waitTime < fastServeWait ? baseCharge * fastServeBonus : baseCharge
        state.charge = min(1, state.charge + gain)
    }

    public static func tick(_ state: inout FeverState, deltaTime: Double) {
        if isActive(state) {
            state.remaining = max(0, state.remaining - deltaTime)
            state.secondsSinceSale = 0
            return
        }
        let before = state.secondsSinceSale
        let after = before + deltaTime
        state.secondsSinceSale = after
        let decaying = max(0, after - max(before, decayDelay))
        state.charge = max(0, state.charge - decaying * decayPerSecond)
    }

    @discardableResult
    public static func start(_ state: inout FeverState) -> Bool {
        guard isReady(state) else { return false }
        state.charge = 0
        state.remaining = duration
        state.secondsSinceSale = 0
        return true
    }
}
