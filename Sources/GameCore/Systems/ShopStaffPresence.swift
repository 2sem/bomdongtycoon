import Foundation

/// What the shop scene should show of the hired staff: at most one cashier
/// and one cook figure (the shop has one counter and one prep table), each
/// idle or working, or asleep. Derived from `StallState`
/// alone so the scene can diff it and touch nodes only when it changes.
public struct ShopStaffPresence: Equatable {

    /// A worker assigned with less energy than this starts asleep instead of working.
    public static let lowEnergyThreshold: Double = 0.25

    public struct Figure: Equatable {
        public let isWorking: Bool
        public let isResting: Bool
    }

    /// `nil` when nobody is hired for the role.
    public let cashier: Figure?
    public let cook: Figure?

    /// `cashierRecentlySold` is `GameStore.cashierRecentlySold`: collection is instant, so
    /// `pendingCoins` alone would flash the working pose for a single tick per sale.
    public init(stall: StallState, cashierRecentlySold: Bool = false) {
        if stall.cashierCount > 0 {
            cashier = Figure(
                isWorking: !stall.cashierResting && (cashierRecentlySold || stall.pendingCoins > 0),
                isResting: stall.cashierResting
            )
        } else {
            cashier = nil
        }

        let hiredMenus = stall.menuCooks.indices.filter { stall.menuCooks[$0] > 0 }
        if hiredMenus.isEmpty {
            cook = nil
        } else {
            // Mirrors `GameStore.canAutoCook`: a hired cook produces only
            // while the menu is unlocked, the warehouse has supplies and
            // that menu's stock is not full.
            let maxStock = EarningsSystem.maxStock(for: stall)
            let isWorking = hiredMenus.contains { menu in
                !Self.isCookResting(stall, menu)
                    && menu <= stall.menuTier
                    && stall.warehouse > 0
                    && stall.menuStock.indices.contains(menu)
                    && stall.menuStock[menu] < maxStock
            }
            // One figure stands for every hired cook, so it sleeps only when
            // all of them do; one awake cook keeps it on its feet.
            let isResting = hiredMenus.allSatisfy { Self.isCookResting(stall, $0) }
            cook = Figure(isWorking: isWorking, isResting: isResting)
        }
    }

    private static func isCookResting(_ stall: StallState, _ menu: Int) -> Bool {
        stall.menuCookResting.indices.contains(menu) && stall.menuCookResting[menu]
    }
}
