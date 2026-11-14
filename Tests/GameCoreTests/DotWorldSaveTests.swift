import XCTest
@testable import GameCore

@MainActor
final class DotWorldSaveTests: DotWorldTestCase {

    private func put(_ json: String, _ blob: GameStore.SaveBlob) {
        defaults.set(Data(json.utf8), forKey: blob.key)
    }

    func test_oldFormatBlobs_loadWithDefaults() throws {
        put(#"{"coins":10,"warehouse":5}"#, .stall)
        put(#"{"plots":[{"growth":0.4,"isPlanted":true,"workerType":"alba","workerEnergy":0.5}]}"#, .farm)
        put(#"{"totalServed":12,"rating":3.5,"prestigeCount":1}"#, .progress)
        let loaded = makeStore()

        XCTAssertFalse(loaded.farm.plots[0].isGolden)
        XCTAssertEqual(loaded.farm.plots[0].growth, 0.4)
        XCTAssertEqual(loaded.progress.totalGourmetServed, 0)
        XCTAssertEqual(loaded.progress.totalGoldenHarvested, 0)
        XCTAssertEqual(loaded.progress.totalFevers, 0)
        XCTAssertEqual(loaded.progress.totalServed, 12)
        XCTAssertEqual(loaded.missions.count, 3, "no missions blob: today's are rolled")
        XCTAssertNil(loaded.corruptBackup(of: .farm))
        XCTAssertNil(loaded.corruptBackup(of: .progress))
        XCTAssertNil(loaded.corruptBackup(of: .missions))
    }

    func test_newFields_roundTrip() throws {
        store.farm.plots[1].isGolden = true
        store.progress.totalGourmetServed = 4
        store.progress.totalGoldenHarvested = 5
        store.progress.totalFevers = 6
        store.collectCoins()   // save

        let loaded = makeStore()
        XCTAssertTrue(loaded.farm.plots[1].isGolden)
        XCTAssertEqual(loaded.progress.totalGourmetServed, 4)
        XCTAssertEqual(loaded.progress.totalGoldenHarvested, 5)
        XCTAssertEqual(loaded.progress.totalFevers, 6)
    }

    func test_newStats_surviveNewRun() {
        store.progress.totalGourmetServed = 4
        store.progress.totalGoldenHarvested = 5
        store.progress.totalFevers = 6
        prepareForPrestige()
        XCTAssertTrue(store.startNewRun())
        XCTAssertEqual(store.progress.totalGourmetServed, 4)
        XCTAssertEqual(store.progress.totalGoldenHarvested, 5)
        XCTAssertEqual(store.progress.totalFevers, 6)
    }

    func test_mistypedGolden_defaultsFalse() {
        put(#"{"plots":[{"growth":1,"isPlanted":true,"isGolden":"yes"}]}"#, .farm)
        XCTAssertFalse(makeStore().farm.plots[0].isGolden)
    }

    func test_missionsBlob_roundTrips() throws {
        let state = MissionState(dayKey: 20261114, missions: [
            Mission(id: "20261114-harvest", kind: .harvest, target: 15, progress: 3, isClaimed: false, reward: 180),
        ])
        defaults.set(try JSONEncoder().encode(state), forKey: GameStore.SaveBlob.missions.key)
        let loaded = makeStore()
        XCTAssertEqual(loaded.missionState, state)
    }

    func test_missionsBlob_dropsBadMissions_andKeepsABackup() {
        put(#"{"dayKey":20261114,"missions":[{"id":"a","kind":"harvest","target":15,"progress":2,"reward":120},{"id":"b","kind":"bogus","target":1},{"nope":1}]}"#, .missions)
        let loaded = makeStore()
        XCTAssertEqual(loaded.missions.map(\.id), ["a"])
        XCTAssertNotNil(loaded.corruptBackup(of: .missions))
    }

    func test_corruptMissionsBlob_isBackedUp_andFreshMissionsRolled() {
        put("not json", .missions)
        let loaded = makeStore()
        XCTAssertEqual(loaded.corruptBackup(of: .missions), Data("not json".utf8))
        XCTAssertEqual(loaded.missions.count, 3)
    }

    func test_missionDecoding_isTolerantOfMissingOptionalFields() throws {
        let m = try JSONDecoder().decode(Mission.self, from: Data(#"{"id":"x","kind":"earnCoins","target":500}"#.utf8))
        XCTAssertEqual(m.progress, 0)
        XCTAssertFalse(m.isClaimed)
        XCTAssertEqual(m.reward, 100)
    }
}
