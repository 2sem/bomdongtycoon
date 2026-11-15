import XCTest
@testable import GameCore

@MainActor
final class WeatherTests: DotWorldTestCase {

    func test_startsClear_andFirstEventIsRolledOnFirstTick() {
        XCTAssertEqual(store.weather, .clear)
        XCTAssertNil(store.upcomingWeather)
        script.values = [0.0, 0.3]
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.secondsUntilWeather, 149, accuracy: 1e-9)
        XCTAssertEqual(store.upcomingWeather, .snow)
    }

    func test_eventStartsAfterTheRolledGap() {
        script.values = [0.0, 0.0]   // 150 s, rain
        store.tick(deltaTime: 149.9)
        XCTAssertEqual(store.weather, .clear)
        XCTAssertEqual(store.upcomingWeather, .rain)
        store.tick(deltaTime: 0.2)
        XCTAssertEqual(store.weather, .rain)
        XCTAssertNil(store.upcomingWeather)
        XCTAssertEqual(store.weatherRemaining, 29.9, accuracy: 1e-6)
    }

    func test_gapRange_is150to300() {
        script.values = [1.0, 0.0]
        store.tick(deltaTime: 0)
        XCTAssertEqual(store.secondsUntilWeather, 300, accuracy: 1e-9)
        XCTAssertEqual(WeatherSystem.minGap, 150)
    }

    func test_eventLastsThirtySeconds_thenNextGapAndKindAreRolled() {
        for i in store.farm.plots.indices { store.farm.plots[i].isPlanted = false }   // no golden roll between the gap rolls
        script.values = [0.0, 0.0, 1.0, 0.8]   // rain after 150 s, then a 300 s gap to petals
        store.tick(deltaTime: 150)
        XCTAssertEqual(store.weather, .rain)
        store.tick(deltaTime: 29.9)
        XCTAssertEqual(store.weather, .rain)
        store.tick(deltaTime: 0.2)
        XCTAssertEqual(store.weather, .clear)
        XCTAssertEqual(store.weatherRemaining, 0)
        XCTAssertEqual(store.secondsUntilWeather, 300 - 0.1, accuracy: 1e-6)
        XCTAssertEqual(store.upcomingWeather, .petals)
    }

    func test_kindRoll_coversAllFourEvents() {
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.0), .rain)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.24), .rain)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.25), .snow)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.49), .snow)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.5), .leaves)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.75), .petals)
        XCTAssertEqual(WeatherSystem.event(forRoll: 0.999), .petals)
        XCTAssertEqual(WeatherSystem.event(forRoll: 1.0), .petals)
        XCTAssertEqual(WeatherSystem.event(forRoll: -1), .rain)
    }

    func test_eventStarted_isTheOneThatWasAnnounced() {
        for kind in Weather.events {
            var state = WeatherState()
            let roll = [Weather.rain: 0.1, .snow: 0.3, .leaves: 0.6, .petals: 0.9][kind]!
            var rolls = [0.0, roll]
            WeatherSystem.advance(&state, deltaTime: 1) { rolls.removeFirst() }
            XCTAssertEqual(state.upcoming, kind)
            WeatherSystem.advance(&state, deltaTime: 150) { 0 }
            XCTAssertEqual(state.weather, kind)
        }
    }

    func test_oneHugeTick_crossesSeveralPhases() {
        var state = WeatherState()
        var rolls = [0.0, 0.0, 0.0, 0.3, 0.0, 0.6]
        WeatherSystem.advance(&state, deltaTime: 150 + 30 + 150 + 5) { rolls.removeFirst() }
        XCTAssertEqual(state.weather, .snow)
        XCTAssertEqual(state.timer ?? 0, 25, accuracy: 1e-9)
        XCTAssertEqual(rolls.count, 2, "the third gap is only rolled once the snow ends")
    }

    func test_rainDoublesGrowth_otherEventsDoNot() {
        for (kind, factor) in [(Weather.rain, 2.0), (.snow, 1), (.leaves, 1), (.petals, 1)] {
            store.farm.plots[1].growth = 0
            store.debugStartWeather(kind)
            store.tick(deltaTime: 3)
            XCTAssertEqual(store.farm.plots[1].growth, factor * 3 / FarmSystem.baseGrowthDuration,
                           accuracy: 1e-9, "\(kind)")
        }
    }

    func test_clearGrowth_isUnchanged() {
        store.farm.plots[1].growth = 0
        store.tick(deltaTime: 3)
        XCTAssertEqual(store.farm.plots[1].growth, 3 / FarmSystem.baseGrowthDuration, accuracy: 1e-9)
    }

    func test_pausedSimulation_doesNotAdvanceWeather() {
        script.values = [0.0, 0.0]
        store.tick(deltaTime: 100)
        store.isSimulationPaused = true
        store.tick(deltaTime: 500)
        XCTAssertEqual(store.secondsUntilWeather, 50, accuracy: 1e-9)
        XCTAssertEqual(store.weather, .clear)
    }

    func test_newRun_resetsWeather() {
        script.values = [0.0, 0.0]
        store.tick(deltaTime: 160)
        XCTAssertEqual(store.weather, .rain)
        prepareForPrestige()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.weather, .clear)
        XCTAssertEqual(store.weatherRemaining, 0)
        XCTAssertEqual(store.secondsUntilWeather, 0)
        XCTAssertNil(store.upcomingWeather)
    }

    // MARK: Effect table

    func test_effectTable_values() {
        XCTAssertEqual(WeatherEffect.effect(for: .clear), WeatherEffect())
        XCTAssertEqual(WeatherEffect.effect(for: .rain),
                       WeatherEffect(growth: 2, spawnInterval: 1.3, walkSpeed: 1.3, patience: 0.85))
        XCTAssertEqual(WeatherEffect.effect(for: .snow),
                       WeatherEffect(spawnInterval: 1.2, walkSpeed: 0.7, patience: 1.25, price: 1.15))
        XCTAssertEqual(WeatherEffect.effect(for: .leaves), WeatherEffect(spawnInterval: 0.8, patience: 1.25))
        XCTAssertEqual(WeatherEffect.effect(for: .petals),
                       WeatherEffect(spawnInterval: 0.7, walkSpeed: 0.85, tipChance: 0.15))
    }

    func test_everyEvent_hasAnUpsideAndATradeoff() {
        for kind in Weather.events {
            let e = WeatherEffect.effect(for: kind)
            let upsides = [e.growth > 1, e.spawnInterval < 1, e.walkSpeed > 1 && kind == .rain, e.patience > 1,
                           e.price > 1, e.tipChance > 0]
            let tradeoffs = [e.spawnInterval > 1, e.walkSpeed != 1, e.patience < 1, e.growth == 1]
            XCTAssertTrue(upsides.contains(true), "\(kind) has an upside")
            XCTAssertTrue(tradeoffs.contains(true), "\(kind) has a tradeoff")
        }
    }

    func test_spawnInterval_underEachWeather_andWithFever() {
        let base = store.customerSpawnInterval
        for kind in Weather.events {
            store.debugStartWeather(kind)
            XCTAssertEqual(store.customerSpawnInterval, base * WeatherEffect.effect(for: kind).spawnInterval,
                           accuracy: 1e-9, "\(kind)")
        }
        chargeFever()
        store.debugStartWeather(.clear)
        XCTAssertTrue(store.startFever())
        let fever = store.customerSpawnInterval
        XCTAssertEqual(fever, base * FeverSystem.spawnIntervalMultiplier, accuracy: 1e-9)
        store.debugStartWeather(.petals)
        XCTAssertEqual(store.customerSpawnInterval, fever * 0.7, accuracy: 1e-9)
        store.debugStartWeather(.rain)
        XCTAssertEqual(store.customerSpawnInterval, fever * 1.3, accuracy: 1e-9)
    }

    func test_walkSpeedAndPatience_followTheLiveWeather() {
        XCTAssertEqual(store.customerWalkSpeedMultiplier, 1)
        XCTAssertEqual(store.customerPatienceMultiplier, 1)
        store.debugStartWeather(.snow)
        XCTAssertEqual(store.customerWalkSpeedMultiplier, 0.7, accuracy: 1e-9)
        XCTAssertEqual(store.customerPatienceMultiplier, 1.25, accuracy: 1e-9)
        store.debugStartWeather(.rain)
        XCTAssertEqual(store.customerWalkSpeedMultiplier, 1.3, accuracy: 1e-9)
        XCTAssertEqual(store.customerPatienceMultiplier, 0.85, accuracy: 1e-9)
        store.debugStartWeather(.clear)
        XCTAssertEqual(store.customerWalkSpeedMultiplier, 1)
    }

    func test_snowPaysMore_otherWeathersDoNot() {
        func sale(_ kind: Weather) -> Double {
            store.stall.menuStock[0] = 1
            store.debugStartWeather(kind)
            let before = store.stall.pendingCoins
            _ = store.sellItem(menuIndex: 0)
            return store.stall.pendingCoins - before
        }
        let clear = sale(.clear)
        XCTAssertGreaterThan(clear, 0)
        XCTAssertEqual(sale(.snow), clear * 1.15, accuracy: 1e-9)
        for kind in [Weather.rain, .leaves, .petals] { XCTAssertEqual(sale(kind), clear, accuracy: 1e-9, "\(kind)") }
    }

    func test_petalsRaiseTheTipChance() {
        store.debugStartWeather(.petals)
        script.values = [0.34, 0.36]   // 0.20 + 0.15 = 0.35 chance
        XCTAssertTrue(store.rollTip(isGourmet: false))
        XCTAssertFalse(store.rollTip(isGourmet: false))
        store.debugStartWeather(.rain)
        script.values = [0.34]
        XCTAssertFalse(store.rollTip(isGourmet: false), "rain leaves the 20% chance alone")
    }
}

final class DayCycleTests: XCTestCase {
    func test_phasesOverTheLoop() {
        XCTAssertEqual(DayCycle.phase(playSeconds: 0), .morning)
        XCTAssertEqual(DayCycle.phase(playSeconds: 59.9), .morning)
        XCTAssertEqual(DayCycle.phase(playSeconds: 60), .noon)
        XCTAssertEqual(DayCycle.phase(playSeconds: 119.9), .noon)
        XCTAssertEqual(DayCycle.phase(playSeconds: 120), .dusk)
        XCTAssertEqual(DayCycle.phase(playSeconds: 180), .night)
        XCTAssertEqual(DayCycle.phase(playSeconds: 239.9), .night)
    }

    func test_loops() {
        XCTAssertEqual(DayCycle.phase(playSeconds: 240), .morning)
        XCTAssertEqual(DayCycle.phase(playSeconds: 240 * 7 + 130), .dusk)
        XCTAssertEqual(DayCycle.progress(playSeconds: 240 + 60), 0.25, accuracy: 1e-9)
    }

    func test_progress_isInUnitRange_evenForNegativeInput() {
        XCTAssertEqual(DayCycle.progress(playSeconds: 0), 0)
        XCTAssertEqual(DayCycle.progress(playSeconds: -60), 0.75, accuracy: 1e-9)
        XCTAssertEqual(DayCycle.phase(playSeconds: -1), .night)
    }
}
