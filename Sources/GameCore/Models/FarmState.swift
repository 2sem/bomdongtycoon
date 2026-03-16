import Foundation

public struct FarmPlot: Codable {
    public var growth: Double = 0.0   // 0.0 = empty, 1.0 = ready
    public var hasWorker: Bool = false
    public var isReady: Bool { growth >= 1.0 }

    public enum Stage: Codable { case empty, sprout, growing, ready }
    public var stage: Stage {
        if growth <= 0   { return .empty }
        if growth < 0.35 { return .sprout }
        if growth < 1.0  { return .growing }
        return .ready
    }
    public init() {}
}

public struct FarmState: Codable {
    public var plots: [FarmPlot]
    public var upgradeTier: Int = 0
    public var farmWorkers: Int = 0

    public init() {
        plots = Array(repeating: FarmPlot(), count: 5)  // max 5 slots, active count driven by tier
    }
}
