import Foundation
import GameCore

/// QA launch arguments, compiled out of release builds.
///   -dotSeed mid|late   start from a seeded mid- or late-game save (in memory, skips the intro)
///   -dotFever           keep fever running
///   -dotRain            keep it raining
///   -dotDemo            tap a ripe plot, an empty plot and a dish in turn
///   -dotPhase morning|noon|dusk|night   freeze the time of day
enum DotDebug {
    static var dayProgress: Double? {
        #if DEBUG
        let table = ["morning": 0.0, "noon": 0.25, "dusk": 0.5, "night": 0.8]
        return value(after: "-dotPhase").flatMap { table[$0] }
        #else
        return nil
        #endif
    }

    /// Seeded QA runs have nobody to tap the notification prompt.
    static var suppressesSystemPrompts: Bool {
        #if DEBUG
        return arguments.contains("-dotSeed")
        #else
        return false
        #endif
    }

    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments
    private static func value(after flag: String) -> String? {
        guard let i = arguments.firstIndex(of: flag), arguments.indices.contains(i + 1) else { return nil }
        return arguments[i + 1]
    }
    static var wantsDemo: Bool { arguments.contains("-dotDemo") }
    private static var wantsFever: Bool { arguments.contains("-dotFever") }
    private static var wantsRain: Bool { arguments.contains("-dotRain") }
    #endif

    @MainActor
    static func seed(_ store: GameStore) {
        #if DEBUG
        guard let kind = value(after: "-dotSeed") else { return }
        let late = kind == "late"
        var progress = store.progress
        progress.isFirstLaunch = false
        progress.isShopNameSet = true
        progress.lastActiveDate = Date()
        progress.rating = late ? 4.7 : 3.8
        progress.prestigeCount = late ? 1 : 0
        store.progress = progress

        var stall = StallState()
        stall.coins = late ? 50_000_000 : 25_000
        stall.menuTier = late ? 2 : 1
        stall.stallTier = late ? 2 : 1
        stall.locationTier = late ? 2 : 1
        stall.tier1Count = 4
        stall.tier2Count = 2
        stall.tier3Count = late ? 3 : 0
        stall.cashierCount = 1
        stall.cashierTier = late ? 3 : 1
        stall.menuCooks = late ? [3, 3, 2] : [1, 2, 0]
        stall.menuCookEnergy = late ? [1, 0.15, 1] : [1, 1, 1]
        stall.warehouseCapacity = late ? 50 : 30
        stall.warehouse = late ? 46 : 12
        stall.menuStock = late ? [9, 12, 0] : [3, 0, 0]
        stall.farmerCount = late ? 2 : 0
        stall.veteranAlbaCount = late ? 2 : 0
        store.stall = stall

        var farm = FarmState()
        let count = late ? 10 : 6
        farm.plots = (0..<count).map { i in
            var plot = FarmPlot()
            plot.isPlanted = i % 5 != 4
            plot.growth = [1, 0.05, 0.6, 1, 0, 0.25, 1, 0.8, 1, 0][i % 10]
            plot.isGolden = i == 3
            if late { plot.workerType = [.alba, .farmer, .veteranAlba, .none][i % 4] }
            else if i < 2 { plot.workerType = .alba }
            plot.workerEnergy = i == 1 ? 0.1 : 1
            return plot
        }
        store.farm = farm
        #endif
    }

    /// Called every frame; re-arms fever and rain so a screenshot can be taken at leisure.
    @MainActor
    static func keepAlive(_ store: GameStore) {
        #if DEBUG
        if arguments.contains("-dotSeed"), store.offlineEarnings > 0 { store.offlineEarnings = 0 }
        if wantsFever, !store.isFeverActive {
            for _ in 0..<10 { store.recordServed(waitTime: 0) }
            store.startFever()
        }
        if wantsRain, store.weather == .clear {
            var guardCount = 0
            while store.weather == .clear, guardCount < 60 {
                store.tick(deltaTime: 10)
                guardCount += 1
            }
        }
        #endif
    }
}
