import XCTest
@testable import GameCore

/// Headless pace model: the director spawns a customer every `customerSpawnInterval`, each one is served
/// at once. Compares coins per minute of each boost against a 90 s fever cycle (15 s fever, then normal).
@MainActor
final class RushPartTimerBalanceTests: DotWorldTestCase {

    private struct Run { var customers = 0; var coins = 0.0 }

    private func prepare(rating: Double) {
        store.progress.rating = rating
        store.stall.menuTier = 1
        store.stall.coins = 1_000_000
        store.stall.stallTier = UpgradeDefinitions.stall.count - 1
    }

    private func simulate(seconds: Double) -> Run {
        var run = Run()
        let start = store.stall.coins
        var timer = store.customerSpawnInterval
        let dt = 0.1
        for _ in 0..<Int(seconds / dt) {
            store.tick(deltaTime: dt)
            timer -= dt
            guard timer <= 0 else { continue }
            store.stall.menuStock[0] = 50
            if store.sellItem(menuIndex: 0) != nil {
                store.recordServed(waitTime: 1)
                run.customers += 1
            }
            timer = store.customerSpawnInterval
        }
        store.collectCoins()
        run.coins = store.stall.coins - start
        return run
    }

    private func feverCycle(rating: Double) -> Run {
        prepare(rating: rating)
        chargeFever()
        store.progress.rating = rating
        store.startFever()
        return simulate(seconds: FeverSystem.paceSeconds)
    }

    private func perMinute(_ run: Run, seconds: Double) -> Double { run.coins / seconds * 60 }

    func test_partTimerAndRush_doNotOutEarnTheFeverCycle() {
        let cycle = feverCycle(rating: 1.5)
        let cyclePerMinute = perMinute(cycle, seconds: 90)

        setUpFreshStore()
        prepare(rating: 1.5)
        let calm = simulate(seconds: 180)

        setUpFreshStore()
        prepare(rating: 1.5)
        XCTAssertTrue(store.hirePartTimer(payment: .ad))
        let shift = simulate(seconds: PartTimerSystem.shiftDuration)

        let rating3Cycle = perMinute(feverCycle(rating: 3.0), seconds: 90)

        setUpFreshStore()
        prepare(rating: 3.0)
        let calm3 = simulate(seconds: 120)

        setUpFreshStore()
        prepare(rating: 1.5)
        store.purchaseUpgrade(.renovation)
        let rush = simulate(seconds: RushSystem.duration)

        let shiftPM = perMinute(shift, seconds: 180), calmPM = perMinute(calm, seconds: 180)
        let ratedRushPM = perMinute(rush, seconds: 120), calm3PM = perMinute(calm3, seconds: 120)
        print("BALANCE 1.5: calm \(calm.customers) cust \(Int(calmPM)) c/min | part-timer 3min \(shift.customers) cust "
              + "\(Int(shiftPM)) c/min | fever cycle 90s \(cycle.customers) cust \(Int(cyclePerMinute)) c/min")
        print("BALANCE 3.0: calm 2min \(calm3.customers) cust \(Int(calm3PM)) c/min | fever cycle \(Int(rating3Cycle)) c/min")
        print("BALANCE rush from 1.5 (rating lifted): 2min \(rush.customers) cust \(Int(ratedRushPM)) c/min")

        XCTAssertGreaterThan(shiftPM, calmPM, "the shift helps")
        XCTAssertLessThan(shiftPM, cyclePerMinute, "the shift must not out-earn fever")
        XCTAssertLessThan(ratedRushPM, rating3Cycle, "the rush at a 3.0 shop must not out-earn fever")
    }

    private func setUpFreshStore() {
        defaults.removePersistentDomain(forName: suiteName)
        store = makeStore()
        store.farm.plots[0].workerType = .none
    }
}
