import Foundation
import GameCore

/// QA launch arguments, compiled out of release builds.
///   -dotSeed early|mid|late   start from a seeded save (in memory, skips the intro); early = 골목, tier-1 stall,
///                       coins for the 시장 move and a hire
///   -dotResetHints      replay the first-run pointers
///   -dotFever           keep fever running
///   -dotRain            keep it raining
///   -dotFeverReady      keep the fever gauge full (the FEVER! button) without starting it
///   -dotDemo            tap a ripe plot, an empty plot and a dish in turn
///   -dotPhase morning|noon|dusk|night   freeze the time of day
///   -dotSheet upgrades|staff|hire|missions|stats|prestige|tutorial|name|offline   open that screen at launch
enum DotDebug {
    static var dayProgress: Double? {
        #if DEBUG
        let table = ["morning": 0.0, "noon": 0.25, "dusk": 0.5, "night": 0.8]
        return value(after: "-dotPhase").flatMap { table[$0] }
        #else
        return nil
        #endif
    }

    static var sheet: String? {
        #if DEBUG
        return value(after: "-dotSheet")
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
    private static var wantsFeverReady: Bool { arguments.contains("-dotFeverReady") }
    #endif

    @MainActor
    static func seed(_ store: GameStore) {
        #if DEBUG
        if arguments.contains("-dotResetHints") { FirstRunHint.resetForDebug() }
        guard let kind = value(after: "-dotSeed") else { return }
        let late = kind == "late"
        let early = kind == "early"
        var progress = store.progress
        progress.isFirstLaunch = false
        progress.isShopNameSet = true
        progress.lastActiveDate = Date()
        progress.rating = late ? 4.7 : (early ? 2.5 : 3.8)
        progress.prestigeCount = late ? 1 : 0
        store.progress = progress

        var stall = StallState()
        stall.coins = late ? 50_000_000 : (early ? 60_000 : 25_000)
        stall.menuTier = late ? 2 : 1
        stall.stallTier = late ? 2 : 1
        stall.locationTier = late ? 2 : (early ? 0 : 1)
        stall.tier1Count = early ? 0 : 4
        stall.tier2Count = early ? 0 : 2
        stall.tier3Count = late ? 3 : 0
        stall.cashierCount = early ? 0 : 1
        stall.cashierTier = late ? 3 : 1
        stall.menuCooks = late ? [3, 3, 2] : (early ? [0, 0, 0] : [1, 2, 0])
        stall.menuCookEnergy = late ? [1, 0.15, 1] : [1, 1, 1]
        stall.warehouseCapacity = late ? 50 : 30
        stall.warehouse = late ? 46 : (early ? 6 : 12)
        stall.menuStock = late ? [9, 12, 0] : (early ? [0, 0, 0] : [3, 0, 0])
        stall.farmerCount = late ? 2 : 0
        stall.veteranAlbaCount = late ? 2 : 0
        store.stall = stall

        var farm = FarmState()
        let count = late ? 10 : (early ? 3 : 6)
        farm.plots = (0..<count).map { i in
            var plot = FarmPlot()
            plot.isPlanted = i % 5 != 4
            plot.growth = [1, 0.05, 0.6, 1, 0, 0.25, 1, 0.8, 1, 0][i % 10]
            plot.isGolden = i == 3
            if late { plot.workerType = [.alba, .farmer, .veteranAlba, .none][i % 4] }
            else if i < (early ? 0 : 2) { plot.workerType = .alba }
            plot.workerEnergy = i == 1 ? 0.1 : 1
            return plot
        }
        store.farm = farm

        switch value(after: "-dotSheet") {
        case "tutorial":
            progress.isFirstLaunch = true
            store.progress = progress
        case "name":
            progress.isShopNameSet = false
            store.progress = progress
        case "offline":
            store.offlineEarnings = 1_234_567
        default: break
        }
        #endif
    }

    /// Called every frame; re-arms fever and rain so a screenshot can be taken at leisure.
    @MainActor
    static func keepAlive(_ store: GameStore) {
        #if DEBUG
        if arguments.contains("-dotSeed"), value(after: "-dotSheet") != "offline", store.offlineEarnings > 0 {
            store.offlineEarnings = 0
        }
        if wantsFever, !store.isFeverActive {
            for _ in 0..<10 { store.recordServed(waitTime: 0) }
            store.startFever()
        }
        if wantsFeverReady, !store.isFeverActive, !store.isFeverReady {
            for _ in 0..<10 { store.recordServed(waitTime: 0) }
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
