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
        var plot0 = FarmPlot()
        plot0.isPlanted = true
        plot0.growth = 0.5
        plot0.hasWorker = true   // starting 알바생 auto-harvests from day 1

        var plot1 = FarmPlot()
        plot1.isPlanted = true
        plot1.growth = 0.5

        plots = [plot0, plot1]
    }
}
