import Foundation

public enum FarmSystem {
    public static let baseGrowthDuration: Double = 8.0
    public static let harvestYield: Int = 1
    public static let seedCost: Double = 10
    public static let startingPlots: Int = 3
    public static let maxPlots: Int = 10

    /// Price of each additional plot, indexed by `count - 2`: saves made before the farm started with
    /// three plots still pay 500 for their 3rd; a new game starts past that entry.
    private static let firstPricedCount = 2
    private static let plotCosts: [Double] = [500, 1_500, 4_000, 10_000, 25_000, 60_000, 150_000, 400_000]

    public static func growthRate(for farm: FarmState) -> Double {
        1.0 / baseGrowthDuration
    }

    public static func activePlotCount(for farm: FarmState) -> Int {
        farm.plots.count
    }

    /// Cost to add the next plot, or nil if already at max.
    public static func costForNextPlot(currentCount: Int) -> Double? {
        let index = currentCount - firstPricedCount
        guard index >= 0, index < plotCosts.count else { return nil }
        return plotCosts[index]
    }
}
