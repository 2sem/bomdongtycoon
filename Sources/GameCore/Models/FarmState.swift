import Foundation

public struct FarmPlot: Codable {
    public var growth: Double = 0.0;
    public var isPlanted: Bool = false;
    public var hasWorker: Bool = false;
    public var workerEnergy: Double = 1.0;

    public var isReady: Bool { isPlanted && growth >= 1.0 }

    public enum Stage: Codable { case empty, sprout, growing, ready }
    public var stage: Stage {
        guard isPlanted else { return .empty }
        if growth < 0.35 { return .sprout }
        if growth < 1.0  { return .growing }
        return .ready
    }

    private enum CodingKeys: String, CodingKey {
        case growth, isPlanted, hasWorker, workerEnergy
    }

    public init() {}
}

public struct FarmState: Codable {
    public var plots: [FarmPlot]
    public var farmWorkers: Int = 0

    public init() {
        var starter = FarmPlot()
        starter.isPlanted = true
        starter.growth = 0.0
        plots = Array(repeating: starter, count: FarmSystem.startingPlots)
    }
}
