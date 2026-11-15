import Foundation
import GameCore

/// QA launch arguments, compiled out of release builds.
///   -dotSeed early|mid|late   start from a seeded save (volatile: never the real save, skips the intro);
///                       early = 골목, tier-1 stall, coins for the 시장 move and a hire; mid = 시장, 2 dishes;
///                       late = 강남, final tiers, ~400k coins, a measured-looking earning rate
///   -dotShopName N      with -dotSeed: the shop name on the signboard (for localized screenshots)
///   -dotEmpty           empty warehouse (the crate "!" and the ripe-plot pulse)
///   -dotResetHints      replay the first-run pointers
///   -dotFever           keep fever running
///   -dotWeather W       keep weather W on: rain, snow, leaves or petals (-dotRain is the same as -dotWeather rain)
///   -dotFeverReady      keep the fever gauge full (the FEVER! button) without starting it
///   -dotGolden          every plot that ripens turns golden (the sparkle, chime and toast)
///   -dotTips            every served customer leaves a tip coin that never fades
///   -dotTapLog          print one line per tap outcome to stderr
///   -dotMissionsDone    complete all of today's missions (the all-done bonus row)
///   -dotSpeed N         run the simulation (and the scene's timers) N times faster; 4-8 for a quick play-through
///   -dotAutoplay        play like an attentive player with no taps, logging a `[DotQA]` line every 30 game seconds
///   -dotAutoplayIdle    like -dotAutoplay but never touches the world: only buys goals, claims missions and starts fever
///   -dotNoFever         with -dotAutoplay: never press the fever button (isolates the base economy)
///   -dotGift            keep a gift crate in the yard
///   -dotNoAds           no ads at all, for screenshots and recordings
///   -dotAdsGrant        every rewarded request succeeds at once, with no ad (also marks every placement ready)
///   -dotAutoplayAds     with -dotAutoplay: also take the ad rewards (fever recharge, x2 missions, boost, gift)
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

    /// Simulation speed multiplier from `-dotSpeed`; always 1 in release.
    static var speed: Double {
        #if DEBUG
        return value(after: "-dotSpeed").flatMap(Double.init).map { max(0.1, min($0, 30)) } ?? 1
        #else
        return 1
        #endif
    }

    /// A seeded or autoplayed run keeps its save in a throwaway suite, so the next plain launch is the real save.
    static var storeDefaults: UserDefaults {
        #if DEBUG
        if arguments.contains("-dotSeed") || wantsAutoplay {
            let name = "dot.volatile"
            let defaults = UserDefaults(suiteName: name) ?? .standard
            defaults.removePersistentDomain(forName: name)
            return defaults
        }
        #endif
        return .standard
    }

    /// The store's clock: real time, run `-dotSpeed` times faster in DEBUG so wall-clock rules (the
    /// boost's 180 s) keep pace with the sped-up simulation.
    static var clock: () -> Date {
        #if DEBUG
        let origin = Date()
        let speed = speed
        return { origin.addingTimeInterval(Date().timeIntervalSince(origin) * speed) }
        #else
        return Date.init
        #endif
    }

    static var autoplayTakesAds: Bool {
        #if DEBUG
        return arguments.contains("-dotAutoplayAds")
        #else
        return false
        #endif
    }

    static var autoplaySkipsFever: Bool {
        #if DEBUG
        return arguments.contains("-dotNoFever")
        #else
        return false
        #endif
    }

    static var wantsAutoplay: Bool {
        #if DEBUG
        return arguments.contains("-dotAutoplay") || arguments.contains("-dotAutoplayIdle")
        #else
        return false
        #endif
    }

    /// `-dotAutoplayIdle`: the autoplayer buys and claims but never taps the world.
    static var autoplayIsIdle: Bool {
        #if DEBUG
        return arguments.contains("-dotAutoplayIdle")
        #else
        return false
        #endif
    }

    /// Seeded and autoplayed QA runs have nobody to tap the notification prompt.
    static var suppressesSystemPrompts: Bool {
        #if DEBUG
        return arguments.contains("-dotSeed") || wantsAutoplay
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
    static var wantsTips: Bool { arguments.contains("-dotTips") }
    private static let launchTime = Date()
    static var wantsDemo: Bool { arguments.contains("-dotDemo") }
    private static var wantsFever: Bool { arguments.contains("-dotFever") }
    private static var wantsGolden: Bool { arguments.contains("-dotGolden") }
    private static var wantedWeather: Weather? {
        if arguments.contains("-dotRain") { return .rain }
        switch value(after: "-dotWeather") {
        case "rain": return .rain
        case "snow": return .snow
        case "leaves": return .leaves
        case "petals": return .petals
        default: return nil
        }
    }
    private static var wantsFeverReady: Bool { arguments.contains("-dotFeverReady") }
    #endif

    /// One line per tap outcome on stdout (`simctl launch --console`), for counting taps that did something.
    static var alwaysTips: Bool {
        #if DEBUG
        return wantsTips
        #else
        return false
        #endif
    }

    /// The QA line the play-through scripts read: `xcrun simctl launch --console-pty ... | grep '\[DotQA\]'`.
    static func qa(_ text: String) {
        #if DEBUG
        NSLog("[DotQA] %@", text)
        #endif
    }

    static func tapLog(_ text: @autoclosure () -> String) {
        #if DEBUG
        if arguments.contains("-dotTapLog") { FileHandle.standardError.write(Data("TAP \(text())\n".utf8)) }
        #endif
    }

    @MainActor
    static func seed(_ store: GameStore) {
        #if DEBUG
        if arguments.contains("-dotResetHints") { FirstRunHint.resetForDebug() }
        if wantsAutoplay, value(after: "-dotSeed") == nil {
            // No fingers for the intro: a fresh install is named and started straight away.
            if store.progress.isFirstLaunch { store.markFirstLaunchComplete() }
            if !store.progress.isShopNameSet { store.setShopName("QA") }
        }
        guard let kind = value(after: "-dotSeed") else { return }
        let late = kind == "late"
        let early = kind == "early"
        var progress = store.progress
        progress.isFirstLaunch = false
        progress.isShopNameSet = true
        if let name = value(after: "-dotShopName") { progress.shopName = name }
        progress.lastActiveDate = Date()
        progress.rating = late ? 4.7 : (early ? 2.5 : 3.8)
        progress.prestigeCount = late ? 1 : 0
        // What a few sessions of play leave behind, so income-scaled rewards and ad offers read true.
        progress.earningRate = late ? 180 : (early ? 0 : 40)
        progress.totalPlaySeconds = late ? 7_200 : (early ? 150 : 1_800)
        progress.lastWageDay = DayCycle.dayIndex(playSeconds: progress.totalPlaySeconds)
        store.progress = progress

        var stall = StallState()
        stall.coins = late ? 400_000 : (early ? 60_000 : 25_000)
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
        stall.menuCookResting = late ? [false, true, false] : [false, false, false]
        stall.warehouseCapacity = late ? 50 : 30
        stall.warehouse = late ? 46 : (early ? 6 : 12)
        stall.menuStock = late ? [9, 12, 0] : (early ? [0, 0, 0] : [3, 0, 0])
        stall.farmerCount = late ? 2 : 0
        stall.veteranAlbaCount = late ? 2 : 0
        stall.recipeLevels = late ? [12, 9, 6] : (early ? [0, 0, 0] : [3, 1, 0])
        stall.renovationLevel = late ? 3 : 0
        if !early { stall.staffTier = late ? 3 : 2 }
        if arguments.contains("-dotEmpty") { stall.warehouse = 0; stall.menuStock = [0, 0, 0] }
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
            plot.workerResting = i == 1 && plot.hasWorker
            return plot
        }
        store.farm = farm
        store.debugRerollMissions()

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

    /// Called every frame; re-arms fever and weather so a screenshot can be taken at leisure.
    @MainActor
    static func keepAlive(_ store: GameStore) {
        #if DEBUG
        if arguments.contains("-dotSeed"), value(after: "-dotSheet") != "offline", store.offlineEarnings > 0 {
            store.offlineEarnings = 0
        }
        if arguments.contains("-dotGift"), !store.isGiftPresent, !store.isGiftHeld { store.debugSpawnGift() }
        if wantsFever, !store.isFeverActive {
            for _ in 0..<10 { store.recordServed(waitTime: 0) }
            store.startFever()
        }
        // Held back 6 s so the first-ready toast lands after the splash instead of behind it.
        if wantsFeverReady, Date().timeIntervalSince(launchTime) > 6, !store.isFeverActive, !store.isFeverReady {
            for _ in 0..<10 { store.recordServed(waitTime: 0) }
        }
        if arguments.contains("-dotMissionsDone"), !store.isDailyBonusReady, !store.isDailyBonusClaimed {
            store.debugCompleteAllMissions()
        }
        if wantsGolden {
            for i in store.farm.plots.indices where store.farm.plots[i].stage == .ready && !store.farm.plots[i].isGolden {
                store.farm.plots[i].isGolden = true
            }
        }
        if let wanted = wantedWeather, store.weather != wanted { store.debugStartWeather(wanted) }
        #endif
    }
}
