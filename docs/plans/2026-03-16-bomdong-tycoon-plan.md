# 봄동타이쿤 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a free idle tycoon iOS game where the player runs a 봄동 food stall, earns coins passively, upgrades staff/menu/location, and collects offline earnings.

**Architecture:** Three Tuist targets — `GameCore` (pure Swift models + systems, fully testable), `GameUI` (SwiftUI overlays), `App` (SpriteKit scenes + entry point). Game logic never touches UIKit/SpriteKit, making it unit-testable. SpriteKit scenes observe `GameCore` state via Combine.

**Tech Stack:** Swift 5.9, SpriteKit, SwiftUI, Tuist 4.x, Google AdMob (SPM), UserDefaults + Codable, XCTest

---

## Task 0: Install axiom-ios-games skill

Before implementing, install the `axiom-ios-games` skill from agentskills.so. This skill provides SpriteKit scene graph patterns, ECS architecture guidance, and game loop templates used throughout this plan.

---

## Task 1: Tuist Project Scaffold

**Files:**
- Create: `Project.swift`
- Create: `Tuist/Package.swift`
- Create: `Tuist/Config.swift`

**Step 1: Initialize Tuist**

```bash
cd /Users/LYJ/Projects/leesam/bomdong/src/bomdongtycoon
tuist init --name BomDongTycoon --platform ios
```

**Step 2: Replace `Project.swift` with this content**

```swift
import ProjectDescription

let project = Project(
    name: "BomDongTycoon",
    targets: [
        // GameCore: pure Swift, no UIKit/SpriteKit — fully unit testable
        .target(
            name: "GameCore",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.leesam.bomdongtycoon.gamecore",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/GameCore/**"]
        ),
        .target(
            name: "GameCoreTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.leesam.bomdongtycoon.gamecore.tests",
            deploymentTargets: .iOS("17.0"),
            sources: ["Tests/GameCoreTests/**"],
            dependencies: [.target(name: "GameCore")]
        ),
        // GameUI: SwiftUI overlays, depends on GameCore
        .target(
            name: "GameUI",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.leesam.bomdongtycoon.gameui",
            deploymentTargets: .iOS("17.0"),
            sources: ["Sources/GameUI/**"],
            dependencies: [.target(name: "GameCore")]
        ),
        // App: SpriteKit scenes + entry point
        .target(
            name: "BomDongTycoon",
            destinations: .iOS,
            product: .app,
            bundleId: "com.leesam.bomdongtycoon",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchStoryboardName": "LaunchScreen",
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "NSUserNotificationUsageDescription": "봄동 가게 알림을 보내드려요 🥬"
            ]),
            sources: ["Sources/App/**"],
            resources: ["Resources/**"],
            dependencies: [
                .target(name: "GameCore"),
                .target(name: "GameUI"),
                .package(product: "GoogleMobileAds")
            ]
        )
    ],
    packages: [
        .remote(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads",
            requirement: .upToNextMajor(from: "11.0.0")
        )
    ]
)
```

**Step 3: Create source directories**

```bash
mkdir -p Sources/GameCore/{Models,Systems}
mkdir -p Sources/GameUI
mkdir -p Sources/App/{Scenes,Nodes}
mkdir -p Tests/GameCoreTests
mkdir -p Resources
```

**Step 4: Generate Xcode project**

```bash
tuist generate
```

Expected: `BomDongTycoon.xcworkspace` created, opens in Xcode.

**Step 5: Commit**

```bash
git checkout -b feature/bomdong-tycoon
git add .
git commit -m "feat: scaffold Tuist project with GameCore/GameUI/App targets"
```

---

## Task 2: Data Models (GameCore)

**Files:**
- Create: `Sources/GameCore/Models/StallState.swift`
- Create: `Sources/GameCore/Models/PlayerProgress.swift`
- Create: `Sources/GameCore/Models/SeasonState.swift`
- Create: `Sources/GameCore/Models/UpgradeDefinitions.swift`
- Create: `Tests/GameCoreTests/ModelTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/GameCoreTests/ModelTests.swift
import XCTest
@testable import GameCore

final class ModelTests: XCTestCase {

    func test_stallState_defaultValues() {
        let stall = StallState()
        XCTAssertEqual(stall.coins, 0)
        XCTAssertEqual(stall.menuTier, 0)
        XCTAssertEqual(stall.staffTier, 0)
        XCTAssertEqual(stall.stallTier, 0)
        XCTAssertEqual(stall.locationTier, 0)
        XCTAssertFalse(stall.autoCollectEnabled)
    }

    func test_stallState_codableRoundTrip() throws {
        var stall = StallState()
        stall.coins = 999
        stall.menuTier = 2
        let data = try JSONEncoder().encode(stall)
        let decoded = try JSONDecoder().decode(StallState.self, from: data)
        XCTAssertEqual(decoded.coins, 999)
        XCTAssertEqual(decoded.menuTier, 2)
    }

    func test_playerProgress_firstLaunch() {
        let progress = PlayerProgress()
        XCTAssertTrue(progress.isFirstLaunch)
        XCTAssertNil(progress.lastActiveDate)
    }

    func test_upgradeDefinition_coinCost() {
        let upgrade = UpgradeDefinitions.staff[0]
        XCTAssertEqual(upgrade.name, "알바생")
        XCTAssertEqual(upgrade.coinCost, 500)
        XCTAssertGreaterThan(upgrade.earningsMultiplier, 1.0)
    }
}
```

**Step 2: Run to verify it fails**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/ModelTests 2>&1 | tail -20
```

Expected: FAIL — types not found.

**Step 3: Implement models**

```swift
// Sources/GameCore/Models/StallState.swift
import Foundation

public struct StallState: Codable {
    public var coins: Double = 0
    public var menuTier: Int = 0       // 0=겉절이, 1=봄동김치, 2=봄동비빔밥
    public var staffTier: Int = 0      // 0=none, 1=알바생, 2=아주머니, 3=요리사
    public var stallTier: Int = 0      // 0=포장마차, 1=분식집, 2=전문점
    public var locationTier: Int = 0   // 0=골목, 1=시장, 2=강남
    public var autoCollectEnabled: Bool = false
    public var pendingCoins: Double = 0  // tappable coin bubbles

    public init() {}
}
```

```swift
// Sources/GameCore/Models/PlayerProgress.swift
import Foundation

public struct PlayerProgress: Codable {
    public var isFirstLaunch: Bool = true
    public var lastActiveDate: Date? = nil
    public var seasonStartDate: Date? = nil
    public var totalEarned: Double = 0

    public init() {}
}
```

```swift
// Sources/GameCore/Models/SeasonState.swift
import Foundation

public enum Season: String, Codable {
    case spring = "봄"
    case summer = "여름"
    case autumn = "가을"
    case winter = "겨울"
}

public struct SeasonState: Codable {
    public var currentSeason: Season = .spring
    public var seasonStartDate: Date = Date()
    public var daysRemaining: Int = 30

    public init() {}
}
```

```swift
// Sources/GameCore/Models/UpgradeDefinitions.swift
import Foundation

public struct UpgradeDefinition {
    public let name: String
    public let coinCost: Double
    public let earningsMultiplier: Double
    public let description: String
}

public enum UpgradeDefinitions {
    public static let menu: [UpgradeDefinition] = [
        .init(name: "겉절이", coinCost: 0, earningsMultiplier: 1.0, description: "기본 메뉴"),
        .init(name: "봄동김치", coinCost: 1_000, earningsMultiplier: 2.5, description: "인기 메뉴"),
        .init(name: "봄동비빔밥", coinCost: 10_000, earningsMultiplier: 6.0, description: "시그니처 메뉴")
    ]

    public static let staff: [UpgradeDefinition] = [
        .init(name: "알바생", coinCost: 500, earningsMultiplier: 1.5, description: "첫 번째 직원"),
        .init(name: "경력 아주머니", coinCost: 3_000, earningsMultiplier: 3.0, description: "베테랑"),
        .init(name: "봄동 요리사", coinCost: 15_000, earningsMultiplier: 7.0, description: "전문가")
    ]

    public static let stall: [UpgradeDefinition] = [
        .init(name: "포장마차", coinCost: 0, earningsMultiplier: 1.0, description: "시작 가게"),
        .init(name: "분식집", coinCost: 5_000, earningsMultiplier: 2.0, description: "업그레이드"),
        .init(name: "봄동 전문점", coinCost: 25_000, earningsMultiplier: 5.0, description: "최고급")
    ]

    public static let location: [UpgradeDefinition] = [
        .init(name: "골목", coinCost: 0, earningsMultiplier: 1.0, description: "조용한 골목"),
        .init(name: "시장", coinCost: 8_000, earningsMultiplier: 2.5, description: "사람 많은 시장"),
        .init(name: "강남", coinCost: 50_000, earningsMultiplier: 8.0, description: "핫플레이스")
    ]
}
```

**Step 4: Run tests**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/ModelTests 2>&1 | tail -20
```

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add Sources/GameCore/Models Tests/GameCoreTests/ModelTests.swift
git commit -m "feat: add GameCore data models with Codable support"
```

---

## Task 3: EarningsSystem (GameCore)

**Files:**
- Create: `Sources/GameCore/Systems/EarningsSystem.swift`
- Create: `Tests/GameCoreTests/EarningsSystemTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/GameCoreTests/EarningsSystemTests.swift
import XCTest
@testable import GameCore

final class EarningsSystemTests: XCTestCase {

    func test_coinsPerSecond_baseLine() {
        let stall = StallState()
        let rate = EarningsSystem.coinsPerSecond(for: stall)
        XCTAssertEqual(rate, 1.0, accuracy: 0.01)  // base rate: 1 coin/sec
    }

    func test_coinsPerSecond_withStaffTier1() {
        var stall = StallState()
        stall.staffTier = 1
        let rate = EarningsSystem.coinsPerSecond(for: stall)
        XCTAssertEqual(rate, 1.5, accuracy: 0.01)
    }

    func test_coinsPerSecond_multipleUpgrades() {
        var stall = StallState()
        stall.menuTier = 1   // x2.5
        stall.staffTier = 1  // x1.5
        stall.stallTier = 1  // x2.0
        // base 1.0 * 2.5 * 1.5 * 2.0 = 7.5
        let rate = EarningsSystem.coinsPerSecond(for: stall)
        XCTAssertEqual(rate, 7.5, accuracy: 0.01)
    }

    func test_nextUpgrade_returnsLowestAffordable() {
        var stall = StallState()
        stall.coins = 600
        let next = EarningsSystem.nextAffordableUpgrade(for: stall)
        XCTAssertEqual(next?.name, "알바생")  // costs 500
    }

    func test_nextUpgrade_noneAffordable() {
        let stall = StallState()  // 0 coins
        let next = EarningsSystem.nextAffordableUpgrade(for: stall)
        XCTAssertNil(next)
    }
}
```

**Step 2: Run to verify failure**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/EarningsSystemTests 2>&1 | tail -20
```

**Step 3: Implement EarningsSystem**

```swift
// Sources/GameCore/Systems/EarningsSystem.swift
import Foundation

public enum EarningsSystem {

    static let baseCoinsPerSecond: Double = 1.0

    public static func coinsPerSecond(for stall: StallState) -> Double {
        var rate = baseCoinsPerSecond

        if stall.menuTier > 0 {
            rate *= UpgradeDefinitions.menu[stall.menuTier].earningsMultiplier
        }
        if stall.staffTier > 0 {
            rate *= UpgradeDefinitions.staff[stall.staffTier - 1].earningsMultiplier
        }
        if stall.stallTier > 0 {
            rate *= UpgradeDefinitions.stall[stall.stallTier].earningsMultiplier
        }
        if stall.locationTier > 0 {
            rate *= UpgradeDefinitions.location[stall.locationTier].earningsMultiplier
        }
        return rate
    }

    /// Returns the cheapest upgrade the player can afford right now
    public static func nextAffordableUpgrade(for stall: StallState) -> UpgradeDefinition? {
        let candidates: [UpgradeDefinition] = [
            stall.staffTier < UpgradeDefinitions.staff.count
                ? UpgradeDefinitions.staff[stall.staffTier] : nil,
            stall.menuTier + 1 < UpgradeDefinitions.menu.count
                ? UpgradeDefinitions.menu[stall.menuTier + 1] : nil,
            stall.stallTier + 1 < UpgradeDefinitions.stall.count
                ? UpgradeDefinitions.stall[stall.stallTier + 1] : nil,
            stall.locationTier + 1 < UpgradeDefinitions.location.count
                ? UpgradeDefinitions.location[stall.locationTier + 1] : nil
        ].compactMap { $0 }

        return candidates
            .filter { $0.coinCost <= stall.coins }
            .min(by: { $0.coinCost < $1.coinCost })
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/EarningsSystemTests 2>&1 | tail -20
```

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add Sources/GameCore/Systems/EarningsSystem.swift Tests/GameCoreTests/EarningsSystemTests.swift
git commit -m "feat: add EarningsSystem with multiplier calculation"
```

---

## Task 4: OfflineProgressSystem (GameCore)

**Files:**
- Create: `Sources/GameCore/Systems/OfflineProgressSystem.swift`
- Create: `Tests/GameCoreTests/OfflineProgressSystemTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/GameCoreTests/OfflineProgressSystemTests.swift
import XCTest
@testable import GameCore

final class OfflineProgressSystemTests: XCTestCase {

    func test_offlineEarnings_twoHours() {
        let stall = StallState()  // 1 coin/sec base
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twoHoursAgo
        )
        XCTAssertEqual(earnings, 7200, accuracy: 1)  // 1 coin/sec * 7200 sec
    }

    func test_offlineEarnings_cappedAt8Hours() {
        let stall = StallState()
        let twentyHoursAgo = Date().addingTimeInterval(-20 * 3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: twentyHoursAgo
        )
        let maxEarnings = 1.0 * 8 * 3600  // 1 coin/sec * 8hr cap
        XCTAssertEqual(earnings, maxEarnings, accuracy: 1)
    }

    func test_offlineEarnings_firstLaunch_returnsZero() {
        let stall = StallState()
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: nil
        )
        XCTAssertEqual(earnings, 0)
    }

    func test_offlineEarnings_withMultiplier() {
        let stall = StallState()  // 1 coin/sec
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: oneHourAgo,
            multiplier: 2.0
        )
        XCTAssertEqual(earnings, 7200, accuracy: 1)  // 1 * 3600 * 2x
    }
}
```

**Step 2: Run to verify failure**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/OfflineProgressSystemTests 2>&1 | tail -20
```

**Step 3: Implement**

```swift
// Sources/GameCore/Systems/OfflineProgressSystem.swift
import Foundation

public enum OfflineProgressSystem {

    static let maxOfflineHours: Double = 8

    public static func calculateOfflineEarnings(
        stall: StallState,
        lastActiveDate: Date?,
        multiplier: Double = 1.0
    ) -> Double {
        guard let lastActive = lastActiveDate else { return 0 }
        let elapsed = min(
            Date().timeIntervalSince(lastActive),
            maxOfflineHours * 3600
        )
        return EarningsSystem.coinsPerSecond(for: stall) * elapsed * multiplier
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/OfflineProgressSystemTests 2>&1 | tail -20
```

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add Sources/GameCore/Systems/OfflineProgressSystem.swift Tests/GameCoreTests/OfflineProgressSystemTests.swift
git commit -m "feat: add OfflineProgressSystem with 8-hour cap"
```

---

## Task 5: SeasonSystem (GameCore)

**Files:**
- Create: `Sources/GameCore/Systems/SeasonSystem.swift`
- Create: `Tests/GameCoreTests/SeasonSystemTests.swift`

**Step 1: Write failing tests**

```swift
// Tests/GameCoreTests/SeasonSystemTests.swift
import XCTest
@testable import GameCore

final class SeasonSystemTests: XCTestCase {

    func test_season_springFirst30Days() {
        let start = Date()
        let state = SeasonSystem.currentState(seasonStart: start)
        XCTAssertEqual(state.currentSeason, .spring)
        XCTAssertEqual(state.daysRemaining, 30)
    }

    func test_season_transitionsToSummerAfter30Days() {
        let thirtyOneDaysAgo = Date().addingTimeInterval(-31 * 86400)
        let state = SeasonSystem.currentState(seasonStart: thirtyOneDaysAgo)
        XCTAssertEqual(state.currentSeason, .summer)
    }

    func test_springMultiplier_isOne() {
        XCTAssertEqual(SeasonSystem.earningsMultiplier(for: .spring), 1.0)
    }

    func test_summerMultiplier_hasBomDongBonus() {
        XCTAssertGreaterThan(SeasonSystem.earningsMultiplier(for: .summer), 1.0)
    }
}
```

**Step 2: Run to verify failure**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/SeasonSystemTests 2>&1 | tail -20
```

**Step 3: Implement**

```swift
// Sources/GameCore/Systems/SeasonSystem.swift
import Foundation

public enum SeasonSystem {

    static let springDurationDays: Double = 30

    public static func currentState(seasonStart: Date) -> SeasonState {
        let elapsed = Date().timeIntervalSince(seasonStart)
        let daysPassed = elapsed / 86400
        var state = SeasonState()
        state.seasonStartDate = seasonStart

        if daysPassed < springDurationDays {
            state.currentSeason = .spring
            state.daysRemaining = Int(springDurationDays - daysPassed)
        } else {
            state.currentSeason = .summer
            state.daysRemaining = 0
        }
        return state
    }

    public static func earningsMultiplier(for season: Season) -> Double {
        switch season {
        case .spring: return 1.0
        case .summer: return 1.5   // 봄동 is rare in summer = premium bonus
        case .autumn: return 1.2
        case .winter: return 1.0
        }
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/SeasonSystemTests 2>&1 | tail -20
```

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add Sources/GameCore/Systems/SeasonSystem.swift Tests/GameCoreTests/SeasonSystemTests.swift
git commit -m "feat: add SeasonSystem with spring/summer transitions"
```

---

## Task 6: GameStore (Combine state container)

**Files:**
- Create: `Sources/GameCore/GameStore.swift`
- Create: `Tests/GameCoreTests/GameStoreTests.swift`

This is the single source of truth — a Combine `ObservableObject` that SpriteKit scenes and SwiftUI views both observe.

**Step 1: Write failing tests**

```swift
// Tests/GameCoreTests/GameStoreTests.swift
import XCTest
import Combine
@testable import GameCore

final class GameStoreTests: XCTestCase {

    var store: GameStore!
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        store = GameStore()
    }

    func test_tick_increasesCoins() {
        store.tick(deltaTime: 1.0)
        XCTAssertGreaterThan(store.stall.pendingCoins, 0)
    }

    func test_collectCoins_movesToBalance() {
        store.stall.pendingCoins = 100
        store.collectCoins()
        XCTAssertEqual(store.stall.coins, 100)
        XCTAssertEqual(store.stall.pendingCoins, 0)
    }

    func test_applyOfflineEarnings_updatesCoins() {
        store.progress.lastActiveDate = Date().addingTimeInterval(-3600)
        store.applyOfflineEarnings(multiplier: 1.0)
        XCTAssertGreaterThan(store.offlineEarnings, 0)
    }

    func test_purchaseUpgrade_staff_deductsCoins() {
        store.stall.coins = 1000
        store.purchaseUpgrade(.staff)
        XCTAssertEqual(store.stall.coins, 500)   // 1000 - 500 (알바생 cost)
        XCTAssertEqual(store.stall.staffTier, 1)
    }

    func test_purchaseUpgrade_insufficientCoins_doesNothing() {
        store.stall.coins = 10
        store.purchaseUpgrade(.staff)
        XCTAssertEqual(store.stall.coins, 10)
        XCTAssertEqual(store.stall.staffTier, 0)
    }
}
```

**Step 2: Run to verify failure**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/GameStoreTests 2>&1 | tail -20
```

**Step 3: Implement GameStore**

```swift
// Sources/GameCore/GameStore.swift
import Foundation
import Combine

public enum UpgradeType {
    case staff, menu, stall, location
}

@MainActor
public final class GameStore: ObservableObject {

    @Published public var stall = StallState()
    @Published public var progress = PlayerProgress()
    @Published public var season = SeasonState()
    @Published public var offlineEarnings: Double = 0

    private let persistenceKey = "GameStore.stall"
    private let progressKey = "GameStore.progress"

    public init() {
        load()
        if progress.seasonStartDate == nil {
            progress.seasonStartDate = Date()
        }
        season = SeasonSystem.currentState(seasonStart: progress.seasonStartDate!)
    }

    // Called every frame by SpriteKit scene
    public func tick(deltaTime: Double) {
        let rate = EarningsSystem.coinsPerSecond(for: stall)
        let seasonal = SeasonSystem.earningsMultiplier(for: season.currentSeason)
        stall.pendingCoins += rate * seasonal * deltaTime
    }

    public func collectCoins() {
        stall.coins += stall.pendingCoins
        progress.totalEarned += stall.pendingCoins
        stall.pendingCoins = 0
        save()
    }

    public func applyOfflineEarnings(multiplier: Double) {
        let earnings = OfflineProgressSystem.calculateOfflineEarnings(
            stall: stall,
            lastActiveDate: progress.lastActiveDate,
            multiplier: multiplier
        )
        offlineEarnings = earnings
        stall.coins += earnings
        progress.totalEarned += earnings
        progress.lastActiveDate = Date()
        save()
    }

    public func purchaseUpgrade(_ type: UpgradeType) {
        switch type {
        case .staff:
            guard stall.staffTier < UpgradeDefinitions.staff.count else { return }
            let upgrade = UpgradeDefinitions.staff[stall.staffTier]
            guard stall.coins >= upgrade.coinCost else { return }
            stall.coins -= upgrade.coinCost
            stall.staffTier += 1
        case .menu:
            let nextTier = stall.menuTier + 1
            guard nextTier < UpgradeDefinitions.menu.count else { return }
            let upgrade = UpgradeDefinitions.menu[nextTier]
            guard stall.coins >= upgrade.coinCost else { return }
            stall.coins -= upgrade.coinCost
            stall.menuTier = nextTier
        case .stall:
            let nextTier = stall.stallTier + 1
            guard nextTier < UpgradeDefinitions.stall.count else { return }
            let upgrade = UpgradeDefinitions.stall[nextTier]
            guard stall.coins >= upgrade.coinCost else { return }
            stall.coins -= upgrade.coinCost
            stall.stallTier = nextTier
        case .location:
            let nextTier = stall.locationTier + 1
            guard nextTier < UpgradeDefinitions.location.count else { return }
            let upgrade = UpgradeDefinitions.location[nextTier]
            guard stall.coins >= upgrade.coinCost else { return }
            stall.coins -= upgrade.coinCost
            stall.locationTier = nextTier
        }
        save()
    }

    public func markFirstLaunchComplete() {
        progress.isFirstLaunch = false
        save()
    }

    public func recordBackground() {
        progress.lastActiveDate = Date()
        save()
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(stall) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: persistenceKey),
           let saved = try? JSONDecoder().decode(StallState.self, from: data) {
            stall = saved
        }
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let saved = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = saved
        }
    }
}
```

**Step 4: Run tests**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GameCoreTests/GameStoreTests 2>&1 | tail -20
```

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add Sources/GameCore/GameStore.swift Tests/GameCoreTests/GameStoreTests.swift
git commit -m "feat: add GameStore Combine state container with persistence"
```

---

## Task 7: App Entry Point + Scene Bridge

**Files:**
- Create: `Sources/App/BomDongTycoonApp.swift`
- Create: `Sources/App/GameViewController.swift`

**Step 1: Create app entry point**

```swift
// Sources/App/BomDongTycoonApp.swift
import SwiftUI
import GameCore

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            GameRootView()
                .environmentObject(store)
        }
    }
}
```

```swift
// Sources/App/GameRootView.swift
import SwiftUI
import GameCore
import GameUI

struct GameRootView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        ZStack {
            GameSceneView()
            if store.progress.isFirstLaunch {
                TutorialOverlay()
            }
            if store.offlineEarnings > 0 {
                OfflineEarningsPopup()
            }
        }
        .onAppear {
            store.applyOfflineEarnings(multiplier: 1.0)
        }
    }
}
```

**Step 2: Commit**

```bash
git add Sources/App/
git commit -m "feat: add app entry point and GameRootView"
```

---

## Task 8: MainStallScene (SpriteKit)

**Files:**
- Create: `Sources/App/Scenes/MainStallScene.swift`
- Create: `Sources/App/Scenes/GameSceneView.swift`
- Create: `Sources/App/Nodes/CustomerNode.swift`
- Create: `Sources/App/Nodes/CoinBubbleNode.swift`

**Step 1: Create SpriteKit scene**

```swift
// Sources/App/Scenes/MainStallScene.swift
import SpriteKit
import GameCore
import Combine

final class MainStallScene: SKScene {

    weak var store: GameStore?
    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateTime: TimeInterval = 0
    private var customers: [CustomerNode] = []
    private var coinBubbles: [CoinBubbleNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.95, green: 0.98, blue: 0.92, alpha: 1) // soft green
        setupBackground()
        setupStall()
        startCustomerSpawning()
        observeStore()
    }

    private func setupBackground() {
        // Stall background label (placeholder until real art assets added)
        let stallLabel = SKLabelNode(text: "🥬 봄동 가게")
        stallLabel.fontSize = 32
        stallLabel.position = CGPoint(x: frame.midX, y: frame.midY + 100)
        addChild(stallLabel)
    }

    private func setupStall() {
        let stall = SKShapeNode(rectOf: CGSize(width: 240, height: 120), cornerRadius: 12)
        stall.fillColor = .systemYellow
        stall.position = CGPoint(x: frame.midX, y: frame.midY)
        stall.name = "stall"
        addChild(stall)
    }

    private func startCustomerSpawning() {
        let spawn = SKAction.sequence([
            SKAction.run { [weak self] in self?.spawnCustomer() },
            SKAction.wait(forDuration: 3.0)
        ])
        run(SKAction.repeatForever(spawn))
    }

    private func spawnCustomer() {
        let customer = CustomerNode()
        customer.position = CGPoint(x: -50, y: frame.midY - 60)
        addChild(customer)
        customer.walkTo(x: frame.midX - 80) { [weak self] in
            self?.customerArrived(customer)
        }
    }

    private func customerArrived(_ customer: CustomerNode) {
        // Emit coin bubble at customer position
        spawnCoinBubble(at: customer.position)
        customer.walkTo(x: frame.width + 50) { [weak self] in
            customer.removeFromParent()
            self?.customers.removeAll { $0 === customer }
        }
    }

    private func spawnCoinBubble(at position: CGPoint) {
        guard let store = store else { return }
        let coinsPerCustomer = EarningsSystem.coinsPerSecond(for: store.stall) * 3
        let bubble = CoinBubbleNode(amount: coinsPerCustomer)
        bubble.position = position
        addChild(bubble)
        coinBubbles.append(bubble)

        if store.stall.autoCollectEnabled {
            // Auto-collect after short delay
            bubble.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.run { [weak self] in
                    store.stall.pendingCoins += coinsPerCustomer
                    store.collectCoins()
                    bubble.removeFromParent()
                    self?.coinBubbles.removeAll { $0 === bubble }
                }
            ]))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if tapping a coin bubble
        for bubble in coinBubbles {
            if bubble.contains(location) {
                store?.stall.pendingCoins += bubble.amount
                store?.collectCoins()
                bubble.pop()
                coinBubbles.removeAll { $0 === bubble }
                return
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        store?.tick(deltaTime: delta)
    }

    private func observeStore() {
        // React to stall tier changes (update visuals)
        store?.$stall
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateVisuals() }
            .store(in: &cancellables)
    }

    private func updateVisuals() {
        // Update stall appearance based on tier (placeholder)
    }
}
```

```swift
// Sources/App/Nodes/CustomerNode.swift
import SpriteKit

final class CustomerNode: SKNode {
    private let sprite = SKLabelNode(text: "🧑‍🦱")

    override init() {
        super.init()
        sprite.fontSize = 32
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError() }

    func walkTo(x: CGFloat, completion: @escaping () -> Void) {
        let move = SKAction.moveTo(x: x, duration: 2.0)
        run(move, completion: completion)
    }
}
```

```swift
// Sources/App/Nodes/CoinBubbleNode.swift
import SpriteKit

final class CoinBubbleNode: SKNode {
    let amount: Double
    private let label = SKLabelNode()
    private let bubble = SKShapeNode(circleOfRadius: 24)

    init(amount: Double) {
        self.amount = amount
        super.init()
        bubble.fillColor = .systemYellow
        bubble.strokeColor = .orange
        label.text = "💰"
        label.fontSize = 20
        label.verticalAlignmentMode = .center
        addChild(bubble)
        addChild(label)

        // Gentle float animation
        let float = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.6),
            SKAction.moveBy(x: 0, y: -8, duration: 0.6)
        ])
        run(SKAction.repeatForever(float))
    }

    required init?(coder: NSCoder) { fatalError() }

    func pop() {
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.1),
            SKAction.scale(to: 0, duration: 0.15),
            SKAction.removeFromParent()
        ])
        run(pop)
    }
}
```

```swift
// Sources/App/Scenes/GameSceneView.swift
import SwiftUI
import SpriteKit
import GameCore

struct GameSceneView: UIViewRepresentable {
    @EnvironmentObject var store: GameStore

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        let scene = MainStallScene()
        scene.store = store
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}
```

**Step 2: Build to verify no errors**

```bash
xcodebuild build -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/App/Scenes Sources/App/Nodes
git commit -m "feat: add MainStallScene with customer spawning and coin bubbles"
```

---

## Task 9: SwiftUI Overlays (GameUI)

**Files:**
- Create: `Sources/GameUI/OfflineEarningsPopup.swift`
- Create: `Sources/GameUI/TutorialOverlay.swift`
- Create: `Sources/GameUI/UpgradeSheet.swift`
- Create: `Sources/GameUI/GoalProgressBar.swift`

**Step 1: OfflineEarningsPopup**

```swift
// Sources/GameUI/OfflineEarningsPopup.swift
import SwiftUI
import GameCore

public struct OfflineEarningsPopup: View {
    @EnvironmentObject var store: GameStore
    @State private var showAdOffer = true

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🥬 돌아오셨군요!")
                    .font(.title2.bold())
                Text("가게를 비운 동안 번 돈:")
                    .foregroundStyle(.secondary)
                Text("💰 \(Int(store.offlineEarnings))원")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.orange)

                if showAdOffer {
                    Button {
                        // AdMob rewarded ad — implemented in Task 11
                        AdManager.shared.showRewardedAd { store.applyOfflineEarnings(multiplier: 2.0) }
                        showAdOffer = false
                    } label: {
                        Label("광고 보고 2배 받기", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button("그냥 받기") {
                    store.offlineEarnings = 0
                }
                .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}
```

**Step 2: TutorialOverlay**

```swift
// Sources/GameUI/TutorialOverlay.swift
import SwiftUI
import GameCore

public struct TutorialOverlay: View {
    @EnvironmentObject var store: GameStore
    @State private var step = 0

    let steps = [
        ("🥬", "봄동에 오신 걸 환영해요!", "봄동 가게를 운영해보세요"),
        ("👆", "손님이 오면 코인을 탭하세요!", "💰 을 눌러 수집하세요"),
        ("⬆️", "코인으로 가게를 업그레이드하세요!", "더 많은 손님, 더 많은 수익!")
    ]

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(steps[step].0)
                    .font(.system(size: 64))
                Text(steps[step].1)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(steps[step].2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(step < steps.count - 1 ? "다음" : "시작하기!") {
                    if step < steps.count - 1 {
                        step += 1
                    } else {
                        store.markFirstLaunchComplete()
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: step)
    }
}
```

**Step 3: UpgradeSheet**

```swift
// Sources/GameUI/UpgradeSheet.swift
import SwiftUI
import GameCore

public struct UpgradeSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            List {
                upgradeSection("메뉴 업그레이드", type: .menu,
                    definitions: UpgradeDefinitions.menu,
                    currentTier: store.stall.menuTier)
                upgradeSection("직원 고용", type: .staff,
                    definitions: UpgradeDefinitions.staff,
                    currentTier: store.stall.staffTier)
                upgradeSection("가게 업그레이드", type: .stall,
                    definitions: UpgradeDefinitions.stall,
                    currentTier: store.stall.stallTier)
                upgradeSection("위치 이전", type: .location,
                    definitions: UpgradeDefinitions.location,
                    currentTier: store.stall.locationTier)
            }
            .navigationTitle("업그레이드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { isPresented = false }
                }
            }
        }
    }

    @ViewBuilder
    private func upgradeSection(_ title: String, type: UpgradeType,
        definitions: [UpgradeDefinition], currentTier: Int) -> some View {
        Section(title) {
            ForEach(Array(definitions.enumerated()), id: \.offset) { index, upgrade in
                let isOwned = index < currentTier
                let isNext = index == currentTier
                let canAfford = store.stall.coins >= upgrade.coinCost

                HStack {
                    VStack(alignment: .leading) {
                        Text(upgrade.name).font(.headline)
                        Text(upgrade.description).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isOwned {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if isNext {
                        Button("💰 \(Int(upgrade.coinCost))") {
                            store.purchaseUpgrade(type)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAfford)
                        .tint(canAfford ? .orange : .gray)
                    } else {
                        Text("🔒").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
```

**Step 4: GoalProgressBar**

```swift
// Sources/GameUI/GoalProgressBar.swift
import SwiftUI
import GameCore

public struct GoalProgressBar: View {
    @EnvironmentObject var store: GameStore
    @Binding public var showUpgrades: Bool

    public init(showUpgrades: Binding<Bool>) {
        self._showUpgrades = showUpgrades
    }

    public var body: some View {
        if let next = EarningsSystem.nextAffordableUpgrade(for: store.stall) {
            // Can afford — highlight
            goalBar(name: next.name, cost: next.coinCost, current: store.stall.coins, ready: true)
        } else if let next = nextUnaffordableUpgrade() {
            goalBar(name: next.name, cost: next.coinCost, current: store.stall.coins, ready: false)
        }
    }

    private func nextUnaffordableUpgrade() -> UpgradeDefinition? {
        let stall = store.stall
        let candidates: [UpgradeDefinition?] = [
            stall.staffTier < UpgradeDefinitions.staff.count ? UpgradeDefinitions.staff[stall.staffTier] : nil,
            stall.menuTier + 1 < UpgradeDefinitions.menu.count ? UpgradeDefinitions.menu[stall.menuTier + 1] : nil
        ]
        return candidates.compactMap { $0 }.min(by: { $0.coinCost < $1.coinCost })
    }

    @ViewBuilder
    private func goalBar(name: String, cost: Double, current: Double, ready: Bool) -> some View {
        Button { showUpgrades = true } label: {
            HStack(spacing: 8) {
                Text(ready ? "✅" : "🎯")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(name)까지")
                        .font(.caption.bold())
                    ProgressView(value: min(current, cost), total: cost)
                        .tint(ready ? .green : .orange)
                }
                Text("💰\(Int(current))/\(Int(cost))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
```

**Step 5: Build**

```bash
xcodebuild build -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add Sources/GameUI/
git commit -m "feat: add SwiftUI overlays - tutorial, offline popup, upgrade sheet, goal bar"
```

---

## Task 10: Push Notifications

**Files:**
- Create: `Sources/App/NotificationManager.swift`

```swift
// Sources/App/NotificationManager.swift
import UserNotifications

enum NotificationManager {

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func scheduleStallFullNotification(afterHours hours: Double = 2) {
        let content = UNMutableNotificationContent()
        content.title = "봄동 가게"
        content.body = "가게가 꽉 찼어요! 봄동이 기다리고 있어요 🥬"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: hours * 3600,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "stall.full",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
```

Add to `AppDelegate` or `BomDongTycoonApp`:
```swift
// In BomDongTycoonApp.swift, add to init:
init() {
    NotificationManager.requestPermission()
}

// In GameRootView, add .onReceive for scene phase:
.onChange(of: scenePhase) { _, phase in
    if phase == .background {
        store.recordBackground()
        NotificationManager.cancelAll()
        NotificationManager.scheduleStallFullNotification()
    }
}
```

**Step 2: Commit**

```bash
git add Sources/App/NotificationManager.swift Sources/App/BomDongTycoonApp.swift
git commit -m "feat: add push notifications for stall-full reminder"
```

---

## Task 11: AdMob Integration

**Files:**
- Create: `Sources/App/AdManager.swift`

**Step 1: Create AdManager**

```swift
// Sources/App/AdManager.swift
import GoogleMobileAds
import UIKit

@MainActor
final class AdManager: NSObject {
    static let shared = AdManager()

    // Replace with real Ad Unit IDs before App Store submission
    // Test IDs are safe to use during development
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"  // Test ID
    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: (() -> Void)?

    override init() {
        super.init()
        GADMobileAds.sharedInstance().start()
        loadRewardedAd()
    }

    func loadRewardedAd() {
        let request = GADRequest()
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("AdMob load error: \(error.localizedDescription)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    func showRewardedAd(completion: @escaping () -> Void) {
        guard let ad = rewardedAd,
              let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first else {
            // No ad available — give reward anyway (good UX)
            completion()
            return
        }
        rewardCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            self?.rewardCompletion?()
            self?.rewardCompletion = nil
            self?.loadRewardedAd()  // preload next
        }
    }
}

extension AdManager: GADFullScreenContentDelegate {
    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            rewardCompletion?()
            rewardCompletion = nil
            loadRewardedAd()
        }
    }
}
```

**Step 2: Build**

```bash
xcodebuild build -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/App/AdManager.swift
git commit -m "feat: add AdMob rewarded ad integration"
```

---

## Task 12: Run All Tests + Final Build

**Step 1: Run full test suite**

```bash
xcodebuild test -scheme BomDongTycoon -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All tests PASS, no errors.

**Step 2: Run on simulator manually — verify these flows:**
- [ ] First launch shows tutorial
- [ ] Customers walk to stall and spawn coin bubbles
- [ ] Tapping coin bubble collects coins
- [ ] Upgrade sheet opens and shows correct costs
- [ ] Goal bar updates after upgrade
- [ ] Kill app, wait 30 sec, reopen → offline earnings popup appears
- [ ] "광고 보기" button in popup is tappable (uses test Ad ID)

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: complete 봄동타이쿤 v0.1 — idle stall tycoon with SpriteKit + AdMob"
```

---

## Out of Scope (v2+)

- Real sprite art assets (replace emoji placeholders)
- SeasonEventScene (special spring finale)
- iCloud save sync
- App Store Connect setup
- Real AdMob unit IDs (register at admob.google.com)
- Game Center leaderboards
- Haptic feedback on coin collect
