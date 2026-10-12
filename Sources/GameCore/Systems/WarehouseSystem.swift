import Foundation

public enum WarehouseSystem {
    public static let expansionStep: Int = 10
    public static let baseCapacity:  Int = 10
    // 4 expansions max → 5 slots
    private static let expansionCosts: [Double] = [300, 800, 2_000, 5_000]

    public static func costForNextExpansion(current capacity: Int) -> Double? {
        let step = (capacity - baseCapacity) / expansionStep
        guard step >= 0, step < expansionCosts.count else { return nil }
        return expansionCosts[step]
    }

    /// Fill ratio (inclusive) at which the warehouse counts as the throttle. Below it,
    /// an expansion is never offered as the goal, so it cannot displace staff/menu/stall
    /// goals while the warehouse still has room.
    public static let throttleFillRatio: Double = 0.8

    /// The next expansion's resulting capacity and cost; nil at the max.
    public static func nextExpansion(current capacity: Int) -> (capacity: Int, cost: Double)? {
        guard let cost = costForNextExpansion(current: capacity) else { return nil }
        return (capacity + expansionStep, cost)
    }

    /// Integer form of `count / capacity >= throttleFillRatio` (80% -> count * 5 >= capacity * 4)
    /// so 8/10 is in and 7/10 out with no floating-point edge.
    public static func isThrottling(count: Int, capacity: Int) -> Bool {
        capacity > 0 && count * 5 >= capacity * 4
    }
}
