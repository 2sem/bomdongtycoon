import Foundation

/// Transient fever state; lives in the store's run transients, never saved.
public struct FeverState: Equatable {
    public var charge: Double = 0
    /// Seconds since the last served customer; charge only decays once this passes `decayDelay`.
    public var secondsSinceSale: Double = 0
    public var remaining: Double = 0
}

public enum FeverSystem {
    public static let chargePerServe: Double = 1.0 / 10.0
    /// Applied when the customer waited less than `fastServeWait`.
    public static let fastServeBonus: Double = 1.5
    public static let fastServeWait: Double = 2.0
    public static let decayDelay: Double = 6.0
    public static let decayPerSecond: Double = 1.0 / 60.0
    public static let duration: Double = 15.0
    public static let priceMultiplier: Double = 2.0
    public static let spawnIntervalMultiplier: Double = 0.35

    /// Ten serves sum to 0.9999999999999999 in floating point; "full" must tolerate that.
    private static let fullTolerance = 1e-9

    public static func isActive(_ state: FeverState) -> Bool { state.remaining > 0 }

    public static func isReady(_ state: FeverState) -> Bool {
        !isActive(state) && state.charge >= 1 - fullTolerance
    }

    /// Charge does not accumulate while fever is active, but the sale still restarts the decay delay.
    public static func recordServed(_ state: inout FeverState, waitTime: Double) {
        state.secondsSinceSale = 0
        guard !isActive(state) else { return }
        let gain = waitTime < fastServeWait ? chargePerServe * fastServeBonus : chargePerServe
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
