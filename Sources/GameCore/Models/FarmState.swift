import Foundation

public enum FarmWorkerType: String, Codable {
    case none, alba, farmer, veteranAlba
}

public struct FarmPlot: Codable {
    public var growth: Double = 0.0
    public var isPlanted: Bool = false
    public var workerType: FarmWorkerType = .none
    public var workerEnergy: Double = 1.0

    public var hasWorker: Bool { workerType != .none }
    public var isReady: Bool { isPlanted && growth >= 1.0 }

    public enum Stage: Codable { case empty, sprout, growing, ready }
    public var stage: Stage {
        guard isPlanted else { return .empty }
        if growth < 0.35 { return .sprout }
        if growth < 1.0  { return .growing }
        return .ready
    }

    private enum CodingKeys: String, CodingKey {
        case growth, isPlanted, workerType, workerEnergy
        case hasWorker  // legacy read-only key for migration
    }

    public init() {}

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(growth,       forKey: .growth)
        try c.encode(isPlanted,    forKey: .isPlanted)
        try c.encode(workerType,   forKey: .workerType)
        try c.encode(workerEnergy, forKey: .workerEnergy)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        growth      = try c.decodeIfPresent(Double.self, forKey: .growth)      ?? 0.0
        isPlanted   = try c.decodeIfPresent(Bool.self,   forKey: .isPlanted)   ?? false
        workerEnergy = try c.decodeIfPresent(Double.self, forKey: .workerEnergy) ?? 1.0
        if let wt = try c.decodeIfPresent(FarmWorkerType.self, forKey: .workerType) {
            workerType = wt
        } else {
            // migrate old hasWorker: Bool — reset energy so stale exhaustion doesn't carry over
            let had = try c.decodeIfPresent(Bool.self, forKey: .hasWorker) ?? false
            workerType   = had ? .alba : .none
            workerEnergy = 1.0
        }
    }
}

public struct FarmState: Codable {
    public var plots: [FarmPlot]
    public var farmWorkers: Int = 0

    public init() {
        var plot0 = FarmPlot()
        plot0.isPlanted = true
        plot0.growth = 0.5
        plot0.workerType = .alba   // starting 알바생 auto-harvests from day 1

        var plot1 = FarmPlot()
        plot1.isPlanted = true
        plot1.growth = 0.5

        plots = [plot0, plot1]
    }
}
