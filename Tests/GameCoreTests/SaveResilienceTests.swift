import XCTest
@testable import GameCore

@MainActor
final class SaveResilienceTests: XCTestCase {

    private var suite: String!
    private var defaults: UserDefaults!
    private var mismatches: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        suite = "SaveResilienceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        mismatches = []
        SaveDiagnostics.onTypeMismatch = { [unowned self] key, _ in mismatches.append(key) }
    }

    override func tearDown() async throws {
        SaveDiagnostics.onTypeMismatch = nil
        UserDefaults.standard.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    private func put(_ json: String, _ blob: GameStore.SaveBlob) {
        defaults.set(Data(json.utf8), forKey: blob.key)
    }

    private func stallJSON(menuCooks: String = "[0,0,0]", menuStock: String = "[0,0,0]",
                           menuCookEnergy: String = "[1,1,1]") -> String {
        #"{"coins":10,"tier1Count":1,"warehouse":5,"menuCooks":\#(menuCooks),"menuStock":\#(menuStock),"menuCookEnergy":\#(menuCookEnergy)}"#
    }

    // MARK: 1. Corrupt blob backup

    func test_corruptBlob_isCopiedBeforeFallback() throws {
        put("not json at all", .stall)
        put("7", .farm)
        let store = GameStore(defaults: defaults)

        XCTAssertEqual(store.corruptBackup(of: .stall), Data("not json at all".utf8))
        XCTAssertEqual(store.corruptBackup(of: .farm), Data("7".utf8))
        XCTAssertNil(store.corruptBackup(of: .progress))
        XCTAssertEqual(store.stall.coins, StallState().coins)
        XCTAssertEqual(store.farm.plots.count, 2)
    }

    func test_backupSurvivesTheNextSave() throws {
        put("[1,2,3]", .progress)
        let store = GameStore(defaults: defaults)
        store.collectCoins()   // save()

        XCTAssertNotEqual(defaults.data(forKey: GameStore.SaveBlob.progress.key), Data("[1,2,3]".utf8))
        XCTAssertEqual(defaults.data(forKey: GameStore.SaveBlob.progress.corruptKey), Data("[1,2,3]".utf8))
    }

    func test_validOrEmptyObjectBlobs_writeNoBackup() throws {
        put("{}", .stall)
        put(#"{"plots":[],"farmWorkers":1}"#, .farm)
        // progress key absent
        let store = GameStore(defaults: defaults)
        for blob in [GameStore.SaveBlob.stall, .farm, .progress] {
            XCTAssertNil(store.corruptBackup(of: blob), "\(blob)")
        }
        XCTAssertTrue(mismatches.isEmpty)
    }

    func test_newerCorruptBlob_replacesOlderBackup() throws {
        put("garbage-1", .stall)
        _ = GameStore(defaults: defaults)
        put("garbage-2", .stall)
        let store = GameStore(defaults: defaults)

        XCTAssertEqual(store.corruptBackup(of: .stall), Data("garbage-2".utf8))
        let corruptKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasSuffix(".corrupt") }
        XCTAssertEqual(corruptKeys.sorted(), ["gameStore.stall.corrupt"])
    }

    // MARK: 2. Per-element plots

    func test_badPlotElement_dropsOnlyThatElement() throws {
        put(#"""
        {"plots":[{"growth":0.1,"isPlanted":true},7,{"growth":0.9,"isPlanted":true,"workerType":"farmer"}],
         "farmWorkers":2}
        """#, .farm)
        let store = GameStore(defaults: defaults)

        XCTAssertEqual(store.farm.plots.count, 2)
        XCTAssertEqual(store.farm.plots[0].growth, 0.1)
        XCTAssertEqual(store.farm.plots[1].growth, 0.9)
        XCTAssertEqual(store.farm.plots[1].workerType, .farmer)
        XCTAssertEqual(store.farm.farmWorkers, 2)
        XCTAssertNotNil(store.corruptBackup(of: .farm))   // a dropped element is damage
    }

    func test_allBadOrEmptyPlots_keepStarterPlots() throws {
        for plots in ["[1,\"x\",null]", "[]", "\"nope\""] {
            put(#"{"plots":\#(plots)}"#, .farm)
            let farm = GameStore(defaults: defaults).farm
            XCTAssertEqual(farm.plots.count, 2, plots)
            XCTAssertEqual(farm.plots[0].workerType, .alba, plots)
        }
    }

    // MARK: 3. Per-menu array lengths

    func test_menuArrays_areNormalisedToMenuCount() throws {
        let n = UpgradeDefinitions.menu.count
        let cases: [(String, String, String)] = [
            ("[]", "[]", "[]"),
            ("[2]", "[4]", "[0.5]"),
            ("[1,1,1,1,1,1,1]", "[1,2,3,4,5,6,7]", "[0.1,0.2,0.3,0.4,0.5,0.6,0.7]"),
        ]
        for (cooks, stock, energy) in cases {
            put(stallJSON(menuCooks: cooks, menuStock: stock, menuCookEnergy: energy), .stall)
            let store = GameStore(defaults: defaults)
            XCTAssertEqual(store.stall.menuCooks.count, n, cooks)
            XCTAssertEqual(store.stall.menuStock.count, n, stock)
            XCTAssertEqual(store.stall.menuCookEnergy.count, n, energy)
            store.stall.menuTier = n - 1
            store.stall.menuCooks = store.stall.menuCooks.map { _ in 1 }
            store.stall.cashierCount = 1
            store.stall.warehouse = 5
            for _ in 0..<20 { store.tick(deltaTime: 1) }
            _ = store.startManualCook(menuIndex: n - 1)
            _ = store.sellItem(menuIndex: n - 1)
            store.batchCook()
        }
    }

    func test_menuArrays_padWithDefaultsAndKeepLeadingValues() throws {
        put(stallJSON(menuCooks: "[2]", menuStock: "[4]", menuCookEnergy: "[0.5]"), .stall)
        let s = GameStore(defaults: defaults).stall
        XCTAssertEqual(s.menuCooks, [2, 0, 0])
        XCTAssertEqual(s.menuStock, [4, 0, 0])
        XCTAssertEqual(s.menuCookEnergy, [0.5, 1.0, 1.0])
    }

    // MARK: 4. Diagnostics

    func test_mistypedPresentKey_isReportedAndDefaulted() throws {
        put(#"{"coins":"lots","warehouse":9}"#, .stall)
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.stall.coins, StallState().coins)
        XCTAssertEqual(store.stall.warehouse, 9)
        XCTAssertEqual(mismatches, ["coins"])
    }

    func test_absentKeysAndEmptyObject_logNothing() throws {
        put("{}", .stall)
        put("{}", .farm)
        put(#"{"shopName":"x"}"#, .progress)
        _ = GameStore(defaults: defaults)
        XCTAssertTrue(mismatches.isEmpty, "\(mismatches)")
    }

    // MARK: 5. Partial damage backup

    func test_mistypedKey_backsUpRawBytes() throws {
        let raw = #"{"coins":"x","warehouse":9,"tier1Count":"y"}"#
        put(raw, .stall)
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.corruptBackup(of: .stall), Data(raw.utf8))
        XCTAssertEqual(store.stall.warehouse, 9)
        store.collectCoins()   // save() overwrites the live key, never the backup
        XCTAssertEqual(store.corruptBackup(of: .stall), Data(raw.utf8))
    }

    func test_droppedPlotElement_backsUpRawBytes() throws {
        let raw = #"{"plots":[{"growth":0.1},7],"farmWorkers":2}"#
        put(raw, .farm)
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.farm.plots.count, 1)
        XCTAssertEqual(store.corruptBackup(of: .farm), Data(raw.utf8))
    }

    func test_oldShapeAndEmptySaves_writeNoBackup() throws {
        put(#"{"coins":5,"menuTier":1}"#, .stall)   // 1.0.1 shape: later keys absent
        put(#"{"plots":[{"growth":0.2,"isPlanted":true}]}"#, .farm)
        put("{}", .progress)
        let store = GameStore(defaults: defaults)
        for blob in [GameStore.SaveBlob.stall, .farm, .progress] {
            XCTAssertNil(store.corruptBackup(of: blob), "\(blob)")
        }
    }

    func test_emptyData_doesNotReplaceNonEmptyBackup() throws {
        put("garbage", .stall)
        _ = GameStore(defaults: defaults)
        defaults.set(Data(), forKey: GameStore.SaveBlob.stall.key)
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.corruptBackup(of: .stall), Data("garbage".utf8))
    }

    func test_nonDataValue_isBackedUpAsCorrupt() throws {
        defaults.set("not data", forKey: GameStore.SaveBlob.stall.key)
        let store = GameStore(defaults: defaults)
        let backup = try XCTUnwrap(store.corruptBackup(of: .stall))
        let obj = try PropertyListSerialization.propertyList(from: backup, options: [], format: nil)
        XCTAssertEqual(obj as? String, "not data")
        XCTAssertEqual(store.stall.coins, StallState().coins)
    }

    func test_droppedElementIsReportedAtOriginalIndex() throws {
        put(#"{"plots":[{"growth":0.1},7,{"growth":0.3},"x"]}"#, .farm)
        _ = GameStore(defaults: defaults)
        XCTAssertEqual(mismatches, ["plots[1]", "plots[3]"])
    }

    // MARK: Encoding unchanged

    func test_encodingKeysUnchanged() throws {
        func keys<T: Encodable>(_ v: T) throws -> Set<String> {
            let obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(v)) as? [String: Any]
            return Set(try XCTUnwrap(obj).keys)
        }
        XCTAssertEqual(try keys(PlayerProgress()), [
            "isFirstLaunch", "isShopNameSet", "shopName", "totalEarned", "earningRate",
            "rating", "totalServed", "totalFailed"])
        XCTAssertEqual(try keys(FarmState()), ["plots", "farmWorkers"])
        XCTAssertEqual(try keys(FarmPlot()), ["growth", "isPlanted", "workerType", "workerEnergy"])
        XCTAssertEqual(try keys(StallState()), [
            "coins", "menuTier", "staffTier", "stallTier", "locationTier", "pendingCoins",
            "tier1Count", "tier2Count", "tier3Count", "cashierCount", "menuCooks",
            "menuCookEnergy", "cashierEnergy", "cashierTier",
            "tier1IdleEnergies", "tier2IdleEnergies", "tier3IdleEnergies",
            "warehouse", "warehouseCapacity", "menuStock", "farmWorkers", "farmWorkerTier",
            "farmerCount", "farmerIdleEnergies", "veteranAlbaCount", "veteranAlbaIdleEnergies"])
    }
}
