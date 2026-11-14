import XCTest
@testable import GameCore

@MainActor
final class WeatherTests: DotWorldTestCase {

    func test_startsClear_andFirstRainIsRolledOnFirstTick() {
        XCTAssertEqual(store.weather, .clear)
        script.values = [0.0]
        store.tick(deltaTime: 1)
        XCTAssertEqual(store.secondsUntilRain, 149, accuracy: 1e-9)
    }

    func test_rainStartsAfterTheRolledGap() {
        script.values = [0.0]   // 150 s
        store.tick(deltaTime: 149.9)
        XCTAssertEqual(store.weather, .clear)
        store.tick(deltaTime: 0.2)
        XCTAssertEqual(store.weather, .rain)
        XCTAssertEqual(store.weatherRemaining, 29.9, accuracy: 1e-6)
    }

    func test_gapRange_is150to300() {
        script.values = [1.0]
        store.tick(deltaTime: 0)
        XCTAssertEqual(store.secondsUntilRain, 300, accuracy: 1e-9)
        XCTAssertEqual(WeatherSystem.minGap, 150)
    }

    func test_rainLastsThirtySeconds_thenNextGapIsRolled() {
        for i in store.farm.plots.indices { store.farm.plots[i].isPlanted = false }   // no golden roll between the gap rolls
        script.values = [0.0, 1.0]   // first gap 150, second gap 300
        store.tick(deltaTime: 150)
        XCTAssertEqual(store.weather, .rain)
        store.tick(deltaTime: 29.9)
        XCTAssertEqual(store.weather, .rain)
        store.tick(deltaTime: 0.2)
        XCTAssertEqual(store.weather, .clear)
        XCTAssertEqual(store.weatherRemaining, 0)
        XCTAssertEqual(store.secondsUntilRain, 300 - 0.1, accuracy: 1e-6)
    }

    func test_oneHugeTick_crossesSeveralPhases() {
        var state = WeatherState()
        var rolls = [0.0, 0.0, 0.0]
        WeatherSystem.advance(&state, deltaTime: 150 + 30 + 150 + 5) { rolls.removeFirst() }
        XCTAssertEqual(state.weather, .rain)
        XCTAssertEqual(state.timer ?? 0, 25, accuracy: 1e-9)
    }

    func test_rainDoublesGrowth() {
        store.farm.plots[1].growth = 0
        script.values = [0.0]
        store.tick(deltaTime: 150)     // rain begins exactly at the end of this tick
        XCTAssertEqual(store.weather, .rain)
        let dry = store.farm.plots[1].growth
        store.farm.plots[1].growth = 0
        store.tick(deltaTime: 3)
        XCTAssertGreaterThan(dry, 0)
        XCTAssertEqual(store.farm.plots[1].growth, 2 * 3 / FarmSystem.baseGrowthDuration, accuracy: 1e-9)
    }

    func test_clearGrowth_isUnchanged() {
        store.farm.plots[1].growth = 0
        store.tick(deltaTime: 3)
        XCTAssertEqual(store.farm.plots[1].growth, 3 / FarmSystem.baseGrowthDuration, accuracy: 1e-9)
    }

    func test_pausedSimulation_doesNotAdvanceWeather() {
        script.values = [0.0]
        store.tick(deltaTime: 100)
        store.isSimulationPaused = true
        store.tick(deltaTime: 500)
        XCTAssertEqual(store.secondsUntilRain, 50, accuracy: 1e-9)
        XCTAssertEqual(store.weather, .clear)
    }

    func test_newRun_resetsWeather() {
        script.values = [0.0]
        store.tick(deltaTime: 160)
        XCTAssertEqual(store.weather, .rain)
        prepareForPrestige()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.weather, .clear)
        XCTAssertEqual(store.weatherRemaining, 0)
        XCTAssertEqual(store.secondsUntilRain, 0)
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
