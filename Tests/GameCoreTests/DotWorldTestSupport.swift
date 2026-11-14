import XCTest
@testable import GameCore

/// Returns scripted values in order, then `fallback`. The default 0.99 never rolls a golden
/// plot or a gourmet and schedules the first rain ~298 s out.
final class ScriptedRandom {
    var values: [Double]
    let fallback: Double
    private(set) var calls = 0
    init(_ values: [Double] = [], fallback: Double = 0.99) {
        self.values = values
        self.fallback = fallback
    }
    func next() -> Double {
        calls += 1
        return values.isEmpty ? fallback : values.removeFirst()
    }
}

final class TestClock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

enum DotWorldTestSupport {
    static func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar().date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}

@MainActor
class DotWorldTestCase: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var script = ScriptedRandom()
    var clock = TestClock(DotWorldTestSupport.date(2026, 11, 14))
    var store: GameStore!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "DotWorld.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        script = ScriptedRandom()
        clock = TestClock(DotWorldTestSupport.date(2026, 11, 14))
        store = makeStore()
        // Isolate from the starting alba farming and cooking.
        store.farm.plots[0].workerType = .none
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        store = nil
        try await super.tearDown()
    }

    func makeStore() -> GameStore {
        let script = script, clock = clock
        return GameStore(defaults: defaults,
                         random: { script.next() },
                         now: { clock.date },
                         calendar: DotWorldTestSupport.calendar())
    }

    /// Serves `count` customers at a relaxed pace (no fast-serve bonus).
    func serve(_ count: Int, waitTime: Double = 5) {
        for _ in 0..<count { store.recordServed(waitTime: waitTime) }
    }

    func chargeFever() {
        serve(36)
        XCTAssertTrue(store.isFeverReady)
    }
}
