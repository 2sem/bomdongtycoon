import XCTest
@testable import GameCore

/// `save()` is three separate writes, so a kill during a spring can leave a mix of old and new
/// blobs. These tests cut the write sequence after every prefix and check the next launch.
@MainActor
final class SpringRecoveryTests: XCTestCase {

    /// Applies at most `budget` writes (set or remove), then silently drops the rest: a kill.
    private final class KillableDefaults: UserDefaults {
        var budget: Int?
        private(set) var writeCount = 0
        private(set) var writtenKeys: [String] = []

        /// `removeObject` is implemented on top of `set(nil, ...)`: count it once.
        private var isRemoving = false

        override func set(_ value: Any?, forKey defaultName: String) {
            if isRemoving { super.set(value, forKey: defaultName); return }
            if let budget, writeCount >= budget { return }
            writeCount += 1
            writtenKeys.append(defaultName)
            super.set(value, forKey: defaultName)
        }

        /// `set(Int, forKey:)` is a separate overload that does not route through the `Any?` one.
        override func set(_ value: Int, forKey defaultName: String) {
            set(value as Any?, forKey: defaultName)
        }

        override func removeObject(forKey defaultName: String) {
            if let budget, writeCount >= budget { return }
            writeCount += 1
            writtenKeys.append(defaultName)
            isRemoving = true
            super.removeObject(forKey: defaultName)
            isRemoving = false
        }
    }

    private var suiteName: String!
    private var defaults: KillableDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "SpringRecoveryTests.\(UUID().uuidString)"
        defaults = KillableDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    private func makeReadyStore(on defaults: UserDefaults) -> GameStore {
        let store = GameStore(defaults: defaults)
        store.stall.coins = 99_999
        store.stall.locationTier = UpgradeDefinitions.location.count - 1
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
        store.stall.menuTier = 2
        store.stall.tier1Count = 3
        store.progress.earningRate = 42
        store.progress.totalEarned = 700_000
        store.progress.prestigeCount = 1
        store.progress.lastActiveDate = Date().addingTimeInterval(-7200)
        return store
    }

    private func assertConsistent(_ store: GameStore, isNew: Bool, _ message: String = "",
                                  file: StaticString = #filePath, line: UInt = #line) {
        if isNew {
            XCTAssertEqual(store.progress.prestigeCount, 2, "\(message) prestigeCount", file: file, line: line)
            XCTAssertEqual(store.stall.coins, StallState().coins, "\(message) stall.coins", file: file, line: line)
            XCTAssertEqual(store.stall.menuTier, 0, "\(message) menuTier", file: file, line: line)
            XCTAssertEqual(store.progress.earningRate, 0, "\(message) earningRate", file: file, line: line)
            XCTAssertEqual(store.progress.totalEarned, 700_000, "\(message) totalEarned", file: file, line: line)
            XCTAssertEqual(store.progress.lastActiveDate?.timeIntervalSinceNow ?? -999, 0, accuracy: 5,
                           message, file: file, line: line)
        } else {
            XCTAssertEqual(store.progress.prestigeCount, 1, message, file: file, line: line)
            XCTAssertEqual(store.stall.coins, 99_999, message, file: file, line: line)
            XCTAssertEqual(store.stall.tier1Count, 3, message, file: file, line: line)
            XCTAssertEqual(store.progress.earningRate, 42, message, file: file, line: line)
        }
    }

    func test_killAfterEveryWritePrefix_isWholeOldOrWholeNew() {
        // Sequence: snapshot, marker, stall, farm, progress, marker cleared.
        for budget in 0...6 {
            let name = "\(suiteName!).\(budget)"
            let d = KillableDefaults(suiteName: name)!
            defer { UserDefaults.standard.removePersistentDomain(forName: name) }
            let store = makeReadyStore(on: d)
            store.recordBackground()   // the old run is on disk, as a normal session leaves it
            d.budget = d.writeCount + budget
            XCTAssertTrue(store.startNewRun(), "budget \(budget)")

            d.budget = nil
            let reloaded = GameStore(defaults: d)
            // Killed before the marker landed the old run is untouched; from the marker on,
            // recovery must finish the spring whichever blobs were already new.
            assertConsistent(reloaded, isNew: budget >= 2, "budget \(budget)")
            XCTAssertNil(d.object(forKey: GameStore.springInFlightKey), "marker cleared, budget \(budget)")

            let again = GameStore(defaults: d)
            assertConsistent(again, isNew: budget >= 2, "second launch, budget \(budget)")
        }
    }

    func test_markerAbsentInNormalOperation_andClearedAfterSpring() {
        let store = makeReadyStore(on: defaults)
        store.recordBackground()
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
        XCTAssertTrue(store.startNewRun())
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
        XCTAssertNotNil(store.preRestartSnapshot)
        let markerWrites = defaults.writtenKeys.filter { $0 == GameStore.springInFlightKey }
        XCTAssertEqual(markerWrites.count, 2, "set once, removed once")
    }

    func test_markerWithoutUsableSnapshot_keepsLoadedState_andClearsMarker() {
        let store = makeReadyStore(on: defaults)
        store.recordBackground()
        defaults.set(2, forKey: GameStore.springInFlightKey)
        let reloaded = GameStore(defaults: defaults)
        assertConsistent(reloaded, isNew: false)
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
    }

    func test_markerWithStaleSnapshot_isNotTrusted() {
        let store = makeReadyStore(on: defaults)
        XCTAssertTrue(store.startNewRun())          // snapshot now says count 1 -> 2
        store.stall.coins = 777
        store.recordBackground()                    // play on in the new run (count 2)
        defaults.set(5, forKey: GameStore.springInFlightKey)   // a marker the snapshot cannot match
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.progress.prestigeCount, 2)
        XCTAssertEqual(reloaded.stall.coins, 777)
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
    }

    /// A completed spring leaves the snapshot saying count 1 -> 2; a marker of 2 reappearing later
    /// (restored backup, tooling) must not replay it over the new run.
    private func playedNewRun(on d: UserDefaults) -> GameStore {
        let store = makeReadyStore(on: d)
        XCTAssertTrue(store.startNewRun())
        store.stall.coins = 4242
        store.stall.menuTier = 1
        store.stall.tier1Count = 3
        store.recordBackground()
        return store
    }

    func test_staleMarkerEqualToLoadedProgress_changesNothing_andIsCleared() {
        _ = playedNewRun(on: defaults)
        defaults.set(2, forKey: GameStore.springInFlightKey)
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.progress.prestigeCount, 2)
        XCTAssertEqual(reloaded.stall.coins, 4242)
        XCTAssertEqual(reloaded.stall.menuTier, 1)
        XCTAssertEqual(reloaded.stall.tier1Count, 3)
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
    }

    func test_staleMarkerAfterCompletedSpring_keepsPlayedRunThroughTicksAndRelaunch() {
        let store = playedNewRun(on: defaults)
        defaults.set(2, forKey: GameStore.springInFlightKey)
        let relaunched = GameStore(defaults: defaults)
        relaunched.stall.coins = 123_456
        for _ in 0..<2_000 { relaunched.tick(deltaTime: 0.1) }
        relaunched.recordBackground()
        let coins = relaunched.stall.coins
        XCTAssertGreaterThan(coins, 100_000, "ticks may spend a little; a replayed spring would leave ~50")
        _ = store

        let again = GameStore(defaults: defaults)
        XCTAssertEqual(again.progress.prestigeCount, 2)
        XCTAssertEqual(again.stall.coins, coins)
        XCTAssertEqual(again.stall.menuTier, 1)
        XCTAssertEqual(again.stall.tier1Count, 3)
    }

    func test_nonIntMarker_isCleared_stateUnchanged() {
        _ = playedNewRun(on: defaults)
        defaults.set("2", forKey: GameStore.springInFlightKey)
        let reloaded = GameStore(defaults: defaults)
        XCTAssertEqual(reloaded.progress.prestigeCount, 2)
        XCTAssertEqual(reloaded.stall.coins, 4242)
        XCTAssertEqual(reloaded.stall.menuTier, 1)
        XCTAssertNil(defaults.object(forKey: GameStore.springInFlightKey))
    }

    func test_interruptedSpring_completesToNewRunExactlyOnce() {
        for budget in 2...5 {
            let name = "\(suiteName!).once.\(budget)"
            let d = KillableDefaults(suiteName: name)!
            defer { UserDefaults.standard.removePersistentDomain(forName: name) }
            let store = makeReadyStore(on: d)
            store.recordBackground()
            d.budget = d.writeCount + budget
            XCTAssertTrue(store.startNewRun())
            d.budget = nil

            let first = GameStore(defaults: d)
            assertConsistent(first, isNew: true, "budget \(budget)")
            first.stall.coins = 31
            first.recordBackground()
            let second = GameStore(defaults: d)
            XCTAssertEqual(second.progress.prestigeCount, 2, "not re-run, budget \(budget)")
            XCTAssertEqual(second.stall.coins, 31, "budget \(budget)")
        }
    }

    func test_idleTicks_writeCountUnchanged() {
        let store = GameStore(defaults: defaults)
        let start = defaults.writeCount
        for _ in 0..<600 { store.tick(deltaTime: 0.1) }
        XCTAssertFalse(defaults.writtenKeys.contains(GameStore.springInFlightKey))
        XCTAssertFalse(defaults.writtenKeys.contains(GameStore.preRestartSnapshotKey))
        XCTAssertEqual(defaults.writeCount - start, 33, "same as before the spring marker existed")
    }
}
