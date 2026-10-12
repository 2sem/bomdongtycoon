import Foundation

/// What the shop scene should show of the hired staff: at most one cashier
/// and one cook figure (the shop has one counter and one prep table), each
/// idle or working, optionally dimmed when tired. Derived from `StallState`
/// alone so the scene can diff it and touch nodes only when it changes.
public struct ShopStaffPresence: Equatable {

    /// Energy below this reads as "tired" — the scene dims the figure.
    public static let lowEnergyThreshold: Double = 0.25

    public struct Figure: Equatable {
        public let isWorking: Bool
        public let isTired: Bool
    }

    /// `nil` when nobody is hired for the role.
    public let cashier: Figure?
    public let cook: Figure?

    public init(stall: StallState) {
        if stall.cashierCount > 0 {
            cashier = Figure(
                isWorking: stall.pendingCoins > 0,
                isTired: stall.cashierEnergy < Self.lowEnergyThreshold
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
                menu <= stall.menuTier
                    && stall.warehouse > 0
                    && stall.menuStock.indices.contains(menu)
                    && stall.menuStock[menu] < maxStock
            }
            // One figure stands for every hired cook, so it is tired as
            // soon as any of them is.
            let isTired = hiredMenus.contains {
                stall.menuCookEnergy.indices.contains($0)
                    && stall.menuCookEnergy[$0] < Self.lowEnergyThreshold
            }
            cook = Figure(isWorking: isWorking, isTired: isTired)
        }
    }
}
