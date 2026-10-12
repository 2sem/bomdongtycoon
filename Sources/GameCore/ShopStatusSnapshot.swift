import Foundation

/// Read-only view of what the shop is doing, derived from `StallState` for the HUD strip.
public struct ShopStatusSnapshot: Equatable {
    public struct MenuStock: Equatable {
        /// Index into `UpgradeDefinitions.menu`.
        public let menuIndex: Int
        public let count: Int

        public init(menuIndex: Int, count: Int) {
            self.menuIndex = menuIndex
            self.count = count
        }
    }

    public let warehouseCount: Int
    public let warehouseCap: Int
    /// Unlocked menus only (`0...menuTier`), in menu order.
    public let stocks: [MenuStock]
    public let cashierPresent: Bool
    /// 0...1; 0 when no cashier is present.
    public let cashierEnergy: Double
    /// True when any menu slot has a cook assigned.
    public let cookPresent: Bool
    /// 0...1, the lowest energy among assigned cooks; 0 when no cook is present.
    public let cookEnergy: Double

    public var totalStock: Int { stocks.reduce(0) { $0 + $1.count } }

    public init(warehouseCount: Int, warehouseCap: Int, stocks: [MenuStock],
                cashierPresent: Bool, cashierEnergy: Double,
                cookPresent: Bool, cookEnergy: Double) {
        self.warehouseCount = warehouseCount
        self.warehouseCap = warehouseCap
        self.stocks = stocks
        self.cashierPresent = cashierPresent
        self.cashierEnergy = cashierEnergy
        self.cookPresent = cookPresent
        self.cookEnergy = cookEnergy
    }

    public init(stall: StallState) {
        let unlocked = min(stall.menuTier, UpgradeDefinitions.menu.count - 1)
        let stocks = (0...max(unlocked, 0)).map {
            MenuStock(menuIndex: $0, count: stall.menuStock.indices.contains($0) ? stall.menuStock[$0] : 0)
        }

        let cookEnergies = stall.menuCooks.indices
            .filter { $0 <= unlocked && stall.menuCooks[$0] > 0 }
            .map { stall.menuCookEnergy.indices.contains($0) ? stall.menuCookEnergy[$0] : 1.0 }

        let cashierPresent = stall.cashierCount > 0
        self.init(
            warehouseCount: stall.warehouse,
            warehouseCap: stall.warehouseCapacity,
            stocks: stocks,
            cashierPresent: cashierPresent,
            cashierEnergy: cashierPresent ? stall.cashierEnergy : 0,
            cookPresent: !cookEnergies.isEmpty,
            cookEnergy: cookEnergies.min() ?? 0
        )
    }
}

extension GameStore {
    public var shopStatus: ShopStatusSnapshot { ShopStatusSnapshot(stall: stall) }
}
