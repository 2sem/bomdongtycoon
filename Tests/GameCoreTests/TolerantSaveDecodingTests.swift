import XCTest
@testable import GameCore

/// A save is decoded whole, so a single throw resets all progress. These tests pin that every
/// persisted model survives missing, extra and mistyped keys.
final class TolerantSaveDecodingTests: XCTestCase {

    // MARK: Samples (every field set to a non-default value)

    private func sampleStall() -> StallState {
        var s = StallState()
        s.coins = 777; s.menuTier = 2; s.staffTier = 2; s.stallTier = 1; s.locationTier = 1
        s.pendingCoins = 12
        s.tier1Count = 3; s.tier2Count = 2; s.tier3Count = 1
        s.cashierCount = 1; s.menuCooks = [1, 2, 0]
        s.menuCookEnergy = [0.5, 0.6, 0.7]; s.cashierEnergy = 0.4; s.cashierTier = 2
        s.tier1IdleEnergies = [0.9]; s.tier2IdleEnergies = [0.8, 0.7]; s.tier3IdleEnergies = [0.3]
        s.warehouse = 9; s.warehouseCapacity = 40; s.menuStock = [4, 5, 6]
        s.farmWorkers = 2; s.farmWorkerTier = 3
        s.farmerCount = 2; s.farmerIdleEnergies = [0.2, 0.3]
        s.veteranAlbaCount = 1; s.veteranAlbaIdleEnergies = [0.1]
        return s
    }

    private func samplePlot() -> FarmPlot {
        var p = FarmPlot()
        p.growth = 0.7; p.isPlanted = true; p.workerType = .farmer; p.workerEnergy = 0.4
        return p
    }

    private func sampleFarm() -> FarmState {
        var f = FarmState()
        var p2 = samplePlot(); p2.workerType = .veteranAlba
        f.plots = [samplePlot(), p2, FarmPlot()]
        f.farmWorkers = 3
        return f
    }

    private func sampleProgress() -> PlayerProgress {
        var p = PlayerProgress()
        p.isFirstLaunch = false; p.isShopNameSet = true; p.shopName = "행복 분식"
        p.lastActiveDate = Date(timeIntervalSince1970: 1_700_000_000)
        p.seasonStartDate = Date(timeIntervalSince1970: 1_690_000_000)
        p.totalEarned = 12_345; p.earningRate = 4.5; p.rating = 4.2
        p.totalServed = 99; p.totalFailed = 7
        return p
    }

    // MARK: Helpers

    private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: object))
    }

    private func only(_ key: String, in dict: [String: Any]) -> [String: Any] {
        dict[key].map { [key: $0] } ?? [:]
    }

    private func same(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        NSDictionary(dictionary: a).isEqual(to: b)
    }

    /// Runs checks (a)-(d) for one model. `sideEffects` lists keys that legitimately change
    /// together with a dropped key (a migration), so they are excluded from "others unchanged".
    private func exercise<T: Codable>(
        _ type: T.Type,
        sample: T,
        sideEffects: [String: [String]] = [:],
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let encoded = try json(sample)
        let defaults = try json(try decode(type, [:]))
        XCTAssertFalse(encoded.isEmpty, file: file, line: line)

        // (a) round trip
        XCTAssertTrue(same(encoded, try json(try decode(type, encoded))), "round trip", file: file, line: line)

        // (b) empty object -> defaults, and the defaults are what a fresh model encodes to
        XCTAssertTrue(same(defaults, try json(try decode(type, [:]))), file: file, line: line)

        // (c) drop each key in turn
        for key in encoded.keys {
            var partial = encoded
            partial.removeValue(forKey: key)
            let result = try json(try decode(type, partial))
            let skipped = Set([key] + (sideEffects[key] ?? []))
            for other in encoded.keys where !skipped.contains(other) {
                XCTAssertTrue(
                    same(only(other, in: result), only(other, in: encoded)),
                    "dropping \(key) changed \(other)", file: file, line: line)
            }
            // nil optionals are omitted from the encoding, so absence on both sides is a match
            XCTAssertTrue(
                same(only(key, in: result), only(key, in: defaults)),
                "dropped \(key) did not fall back to default", file: file, line: line)
        }

        // (d) unknown keys ignored
        var extra = encoded
        extra["someFutureField"] = 42
        extra["anotherOne"] = ["nested": true]
        XCTAssertTrue(same(encoded, try json(try decode(type, extra))), "extra keys", file: file, line: line)

        // wrong-typed value falls back instead of throwing
        for key in encoded.keys {
            var bad = encoded
            bad[key] = "garbage"
            XCTAssertNoThrow(try decode(type, bad), "mistyped \(key) threw", file: file, line: line)
        }
    }

    // MARK: (a)-(d) per model

    func test_stallState() throws {
        try exercise(StallState.self, sample: sampleStall())
    }

    func test_playerProgress() throws {
        try exercise(PlayerProgress.self, sample: sampleProgress())
    }

    func test_farmPlot() throws {
        // A missing workerType triggers the legacy hasWorker migration, which resets energy.
        try exercise(FarmPlot.self, sample: samplePlot(), sideEffects: ["workerType": ["workerEnergy"]])
    }

    func test_farmState() throws {
        try exercise(FarmState.self, sample: sampleFarm())
    }

    // MARK: Specifics

    func test_emptyFarmState_keepsStartingPlots() throws {
        let farm = try decode(FarmState.self, [:])
        XCTAssertEqual(farm.plots.count, 2)
        XCTAssertEqual(farm.plots[0].workerType, .alba)
    }

    func test_unknownWorkerType_fallsBackToNone() throws {
        var plot = try json(samplePlot())
        plot["workerType"] = "robot"
        let decoded = try decode(FarmPlot.self, plot)
        XCTAssertEqual(decoded.workerType, .none)
        XCTAssertEqual(decoded.growth, 0.7)
    }

    func test_legacyHasWorkerKey_stillMigrates() throws {
        let decoded = try decode(FarmPlot.self, ["growth": 0.3, "isPlanted": true, "hasWorker": true])
        XCTAssertEqual(decoded.workerType, .alba)
        XCTAssertEqual(decoded.workerEnergy, 1.0)
    }

    func test_outOfRangeLocationTier_isClamped() throws {
        var stall = try json(sampleStall())
        stall["locationTier"] = 99
        XCTAssertEqual(try decode(StallState.self, stall).locationTier, UpgradeDefinitions.location.count - 1)
    }

    func test_encodingKeysUnchanged() throws {
        XCTAssertEqual(Set(try json(PlayerProgress()).keys), [
            "isFirstLaunch", "isShopNameSet", "shopName", "totalEarned", "earningRate",
            "rating", "totalServed", "totalFailed"])
        XCTAssertEqual(Set(try json(FarmState()).keys), ["plots", "farmWorkers"])
        XCTAssertEqual(Set(try json(FarmPlot()).keys), ["growth", "isPlanted", "workerType", "workerEnergy"])
    }

    // MARK: (e) 1.0.1-era save

    /// Shape written by 1.0.1: no `locationTier`, plots carry `workerType`, progress has no
    /// later additions. Progress must survive end to end through GameStore.
    @MainActor
    func test_release101Save_keepsProgress() throws {
        let stall = #"""
        {"coins": 4321.5, "menuTier": 2, "staffTier": 2, "stallTier": 1, "pendingCoins": 30,
         "tier1Count": 3, "tier2Count": 1, "tier3Count": 0,
         "cashierCount": 1, "menuCooks": [1, 1, 0],
         "menuCookEnergy": [0.8, 0.6, 1.0], "cashierEnergy": 0.9, "cashierTier": 1,
         "tier1IdleEnergies": [0.5], "tier2IdleEnergies": [], "tier3IdleEnergies": [],
         "warehouse": 12, "warehouseCapacity": 20, "menuStock": [3, 2, 0],
         "farmWorkers": 0, "farmWorkerTier": 1,
         "farmerCount": 1, "farmerIdleEnergies": [0.7],
         "veteranAlbaCount": 0, "veteranAlbaIdleEnergies": []}
        """#
        let farm = #"""
        {"plots": [
           {"growth": 0.9, "isPlanted": true, "workerType": "alba", "workerEnergy": 0.6},
           {"growth": 0.2, "isPlanted": true, "workerType": "none", "workerEnergy": 1.0},
           {"growth": 0.0, "isPlanted": false, "workerType": "farmer", "workerEnergy": 0.3}],
         "farmWorkers": 0}
        """#
        let progress = #"""
        {"isFirstLaunch": false, "isShopNameSet": true, "shopName": "옛날 분식",
         "lastActiveDate": 750000000, "seasonStartDate": 740000000,
         "totalEarned": 98765, "earningRate": 3.25, "rating": 4.1,
         "totalServed": 500, "totalFailed": 12}
        """#

        let suite = "TolerantSaveDecodingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        defaults.set(Data(stall.utf8), forKey: "gameStore.stall")
        defaults.set(Data(farm.utf8), forKey: "gameStore.farm")
        defaults.set(Data(progress.utf8), forKey: "gameStore.progress")

        let store = GameStore(defaults: defaults)

        let s = store.stall
        XCTAssertEqual(s.coins, 4321.5)
        XCTAssertEqual(s.locationTier, 0)
        XCTAssertEqual(s.tier1Count, 3)
        XCTAssertEqual(s.tier2Count, 1)
        XCTAssertEqual(s.menuStock, [3, 2, 0])
        XCTAssertEqual(s.farmerCount, 1)

        let f = store.farm
        XCTAssertEqual(f.plots.count, 3)
        XCTAssertEqual(f.plots[0].growth, 0.9)
        XCTAssertEqual(f.plots[0].workerType, .alba)
        XCTAssertEqual(f.plots[2].workerType, .farmer)

        let p = store.progress
        XCTAssertEqual(p.totalEarned, 98765)
        XCTAssertEqual(p.shopName, "옛날 분식")
        XCTAssertEqual(p.totalServed, 500)
        XCTAssertTrue(p.isShopNameSet)
    }
}
