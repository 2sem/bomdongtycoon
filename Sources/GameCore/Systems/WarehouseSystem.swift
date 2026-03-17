import Foundation

public enum WarehouseSystem {
    public static let expansionStep: Int = 10
    public static let baseCapacity:  Int = 10
    // 3 expansions max → 4 slots, matches the 4-column farm grid (no overflow)
    private static let expansionCosts: [Double] = [300, 800, 2_000]

    public static func costForNextExpansion(current capacity: Int) -> Double? {
        let step = (capacity - baseCapacity) / expansionStep
        guard step >= 0, step < expansionCosts.count else { return nil }
        return expansionCosts[step]
    }
}
