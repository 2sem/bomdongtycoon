import SwiftUI
import GameCore

// MARK: - WorkerItem

private struct WorkerItem: Identifiable {
    let id: Int;
    let indexInTier: Int;
    let tier: Int;
    var assignment: Assignment;
    var energy: Double;
    var level = 1;
    /// The plot she works while `.farm`, so firing, levelling and moving act on her and not on another hand of the same type.
    var plot: Int? = nil;
    /// Asleep at a post: assigned, out of energy and not back at full yet.
    var resting = false;
    /// Position in the tier's idle pool; only meaningful while unassigned.
    var idleIndex = 0;

    enum Assignment: Hashable {
        case unassigned, farm, cashier, menu(Int)

        var label: String {
            switch self {
            case .unassigned:   return "미배정"
            case .farm:         return "텃밭"
            case .cashier:      return "계산대"
            case .menu(let i):  return "메뉴 \(i + 1)"
            }
        }
    }
}

// MARK: - StaffTab

/// Tab selection is owned by the presenter so the goal bar can open the sheet on 고용.
public enum StaffTab: Hashable {
    case assign, hire
}

// MARK: - StaffSheet

public struct StaffSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dotPlaySound) private var play
    @Binding public var isPresented: Bool
    @Binding public var tab: StaffTab
    @State private var placementToast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var pendingFire: WorkerItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isPresented: Binding<Bool>, tab: Binding<StaffTab>) {
        self._isPresented = isPresented
        self._tab = tab
    }

    public var body: some View {
        DotSheet(title: String(localized: "직원 관리"), onClose: { isPresented = false }) {
            VStack(spacing: 0) {
                tabBar
                switch tab {
                case .assign: workerList
                case .hire: hireList
                }
            }
        }
        .alert(
            String(localized: "dot.fire.title"),
            isPresented: Binding(get: { pendingFire != nil }, set: { if !$0 { pendingFire = nil } }),
            presenting: pendingFire
        ) { worker in
            Button(String(localized: "dot.fire.confirm"), role: .destructive) { fire(worker) }
            Button(String(localized: "취소"), role: .cancel) {}
        } message: { worker in
            Text(String(format: String(localized: "dot.fire.message"),
                        staffName(worker.tier), CoinFormat.string(WageSystem.wage(forTier: worker.tier))))
        }
        .overlay(alignment: .top) {
            if let placementToast {
                DotToast(text: placementToast)
                    .padding(.top, 110)
                    .padding(.horizontal, 16)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }

    /// "알바생을 겉절이 주방에 배치했어요": says where the new hire went, so a hire is never left
    /// idle without the player knowing. Nothing is shown for a hire that stayed unassigned.
    private func announce(_ result: GameStore.HireResult?) {
        guard let result, let text = HirePlacementText.text(for: result) else { return }
        AccessibilityNotification.Announcement(text).post()
        toastTask?.cancel()
        let animation: Animation = reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4)
        withAnimation(animation) { placementToast = text }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(animation) { placementToast = nil }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            tabButton(String(localized: "직원"), tag: .assign)
            tabButton(String(localized: "고용"), tag: .hire)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private func tabButton(_ title: String, tag: StaffTab) -> some View {
        let selected = tab == tag
        return Button { tab = tag } label: {
            Text(title)
                .dotText(.bold, color: selected ? DotPalette.paper : DotPalette.ink, shadow: selected)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    DotNineSlice(name: selected ? "dot_ui_button" : "dot_ui_panel").padding(.vertical, 4)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Worker list

    private var workerList: some View {
        let workers = buildWorkers()
        return DotScroll {
            if workers.isEmpty {
                VStack(spacing: 8) {
                    DotImage("dot_char_alba_tired", scale: 2).opacity(0.6)
                    Text(String(localized: "고용 탭에서 직원을 채용하세요"))
                        .dotText(.body, color: DotPalette.soilDark)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                DotSectionHeader(String(localized: "직원 목록"))
                payrollSummary
                ForEach(workers) { worker in
                    WorkerRow(
                        worker: worker,
                        menuTier: store.stall.menuTier,
                        menuCooks: store.stall.menuCooks,
                        cashierCount: store.stall.cashierCount,
                        activeFarmPlots: FarmSystem.activePlotCount(for: store.farm),
                        farmPlots: store.farm.plots,
                        coins: store.stall.coins,
                        onReassign: { reassign(worker: worker, to: $0) },
                        onLevelUp: { levelUp(worker) },
                        onFire: { pendingFire = worker }
                    )
                }
            }
        }
    }

    /// Total of the next payday and the time left to it; it counts down with the play clock.
    private var payrollSummary: some View {
        let payroll = store.dailyPayroll
        let time = Self.clockText(store.secondsUntilPayday)
        let paydayText = String(format: String(localized: "dot.staff.payday"), time)
        let payrollText = String(format: String(localized: "dot.staff.payroll"), CoinFormat.string(payroll))
        return VStack(alignment: .leading, spacing: 2) {
            Text(payrollText).dotText(.bold).monospacedDigit()
            Text(paydayText).dotText(.caption, color: DotPalette.soilDark).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dotPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(payrollText), \(paydayText)")
    }

    private static func clockText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Fires from the post the row shows. A farm hand is found by type, as `reassign` finds her.
    private func target(of worker: WorkerItem) -> GameStore.FireTarget? {
        switch worker.assignment {
        case .menu(let i): .cook(menuIndex: i)
        case .cashier: .cashier
        case .farm: worker.plot.map { .farm(plotIndex: $0) }
        case .unassigned: .idle(tier: worker.tier, index: worker.idleIndex)
        }
    }

    private func fire(_ worker: WorkerItem) {
        guard let target = target(of: worker), store.fireWorker(target) else { return play(.error) }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        play(.tap)
        AccessibilityNotification.Announcement(
            String(format: String(localized: "dot.fire.done"), staffName(worker.tier))).post()
    }

    /// Pays for one level of this worker, wherever she is. Same cue as any purchase.
    private func levelUp(_ worker: WorkerItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let target = target(of: worker), store.levelUp(target) else { return play(.error) }
        play(.purchase)
        AccessibilityNotification.Announcement(
            String(format: String(localized: "dot.staff.levelup.done"), staffName(worker.tier), worker.level + 1)).post()
    }

    // MARK: - Hire list

    private var hireList: some View {
        DotScroll {
            DotSectionHeader(String(localized: "직원 고용"))
            ForEach(1...3, id: \.self) { tier in
                HireTierRow(tier: tier, onHired: { result in tab = .assign; announce(result) })
                    .environmentObject(store)
            }
            HireFarmWorkerRow(
                tier: 5,
                def: UpgradeDefinitions.veteranAlba[0],
                count: store.stall.veteranAlbaCount,
                // Three plots, not "more than the starting count": saves from before new games began
                // with three unlocked this by buying their third plot and must keep it.
                isUnlocked: store.farm.plots.count > 2,
                unlockHint: String(localized: "dot.staff.unlock.plots"),
                cashierHint: cashierHireHint(tier: 5),
                onHire: {
                    let result = store.hireVeteranAlba()
                    tab = .assign
                    announce(result)
                }
            )
            HireFarmWorkerRow(
                tier: 4,
                def: UpgradeDefinitions.farmer[0],
                count: store.stall.farmerCount,
                isUnlocked: store.stall.stallTier >= 1,
                unlockHint: String(localized: "dot.staff.unlock.restaurant"),
                onHire: {
                    let result = store.hireFarmer()
                    tab = .assign
                    announce(result)
                }
            )
        }
    }

    // MARK: - Build worker items from store state

    private func buildWorkers() -> [WorkerItem] {
        var items: [WorkerItem] = [];
        var idCounter = 0;
        var remainingCashiers = store.stall.cashierCount;

        func menuSlots(for tier: Int) -> ArraySlice<Int> {
            let slots = (0..<store.stall.menuCooks.count).filter { store.stall.menuCooks[$0] == tier };
            return slots[...];
        }

        // Farm energy cursor: map kth farm-assigned worker to kth plot with hasWorker
        var farmPlotCursor = 0;
        func nextFarmWorker() -> (energy: Double, resting: Bool, level: Int, plot: Int?) {
            while farmPlotCursor < store.farm.plots.count {
                let index = farmPlotCursor
                farmPlotCursor += 1
                let plot = store.farm.plots[index]
                if plot.workerType == .alba { return (plot.workerEnergy, plot.workerResting, plot.workerLevel, index) }
            }
            return (1.0, false, 1, nil);
        }

        // Idle energy cursors — parallel-index into the tier's idle pool
        var t3IdleIdx = 0; var t2IdleIdx = 0; var t1IdleIdx = 0

        // Tier 3 (봄동 요리사): menus only
        var t3 = menuSlots(for: 3);
        var tier3Idx = 0;
        for _ in 0..<store.stall.tier3Count {
            let a: WorkerItem.Assignment = t3.isEmpty ? .unassigned : .menu(t3.removeFirst());
            let e: Double; var asleep = false; var idle = 0; var lvl = 1;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0; asleep = store.stall.menuCookResting[safe: i] ?? false; lvl = store.stall.menuCookLevels[safe: i] ?? 1
            default:
                e = store.stall.tier3IdleEnergies[safe: t3IdleIdx] ?? 1.0
                lvl = store.stall.tier3IdleLevels[safe: t3IdleIdx] ?? 1
                idle = t3IdleIdx
                t3IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier3Idx, tier: 3, assignment: a, energy: e, level: lvl, resting: asleep, idleIndex: idle));
            idCounter += 1; tier3Idx += 1;
        }

        // Tier 2 (이모님): menus → cashier → unassigned
        var t2 = menuSlots(for: 2);
        var tier2Idx = 0;
        for _ in 0..<store.stall.tier2Count {
            let a: WorkerItem.Assignment;
            if !t2.isEmpty                                                  { a = .menu(t2.removeFirst()) }
            else if remainingCashiers > 0 && store.stall.cashierTier == 2  { remainingCashiers -= 1; a = .cashier }
            else                                                            { a = .unassigned }
            let e: Double; var asleep = false; var idle = 0; var lvl = 1;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0; asleep = store.stall.menuCookResting[safe: i] ?? false; lvl = store.stall.menuCookLevels[safe: i] ?? 1
            case .cashier:     e = store.stall.cashierEnergy; asleep = store.stall.cashierResting; lvl = store.stall.cashierLevel
            default:
                e = store.stall.tier2IdleEnergies[safe: t2IdleIdx] ?? 1.0
                lvl = store.stall.tier2IdleLevels[safe: t2IdleIdx] ?? 1
                idle = t2IdleIdx
                t2IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier2Idx, tier: 2, assignment: a, energy: e, level: lvl, resting: asleep, idleIndex: idle));
            idCounter += 1; tier2Idx += 1;
        }

        // Tier 1 (알바생): menus → farm → cashier → unassigned
        var t1 = menuSlots(for: 1);
        var albaFarmWorkers = store.farm.plots.filter { $0.workerType == .alba }.count;
        var tier1Idx = 0;
        for _ in 0..<store.stall.tier1Count {
            let a: WorkerItem.Assignment;
            if !t1.isEmpty                                                  { a = .menu(t1.removeFirst()) }
            else if albaFarmWorkers > 0                                     { albaFarmWorkers -= 1; a = .farm }
            else if remainingCashiers > 0 && store.stall.cashierTier == 1  { remainingCashiers -= 1; a = .cashier }
            else                                                            { a = .unassigned }
            let e: Double; var asleep = false; var idle = 0; var lvl = 1; var farmPlot: Int?
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0; asleep = store.stall.menuCookResting[safe: i] ?? false; lvl = store.stall.menuCookLevels[safe: i] ?? 1
            case .cashier:     e = store.stall.cashierEnergy; asleep = store.stall.cashierResting; lvl = store.stall.cashierLevel
            case .farm:        (e, asleep, lvl, farmPlot) = nextFarmWorker()
            default:
                e = store.stall.tier1IdleEnergies[safe: t1IdleIdx] ?? 1.0
                lvl = store.stall.tier1IdleLevels[safe: t1IdleIdx] ?? 1
                idle = t1IdleIdx
                t1IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier1Idx, tier: 1, assignment: a, energy: e, level: lvl, plot: farmPlot, resting: asleep, idleIndex: idle));
            idCounter += 1; tier1Idx += 1;
        }

        // Farmers (tier 4, farm-only)
        let farmerPlotIndices = store.farm.plots.indices.filter { store.farm.plots[$0].workerType == .farmer }
        let farmerPlotsOnFarm = farmerPlotIndices.map { store.farm.plots[$0] }
        var farmerIdx = 0
        for _ in 0..<store.stall.farmerCount {
            let isOnFarm = farmerIdx < farmerPlotsOnFarm.count
            let a: WorkerItem.Assignment = isOnFarm ? .farm : .unassigned
            let e: Double = isOnFarm
                ? farmerPlotsOnFarm[farmerIdx].workerEnergy
                : (store.stall.farmerIdleEnergies[safe: farmerIdx - farmerPlotsOnFarm.count] ?? 1.0)
            let farmerLevel = isOnFarm
                ? farmerPlotsOnFarm[farmerIdx].workerLevel
                : (store.stall.farmerIdleLevels[safe: farmerIdx - farmerPlotsOnFarm.count] ?? 1)
            items.append(WorkerItem(id: idCounter, indexInTier: farmerIdx, tier: 4, assignment: a, energy: e,
                                    level: farmerLevel, plot: isOnFarm ? farmerPlotIndices[farmerIdx] : nil,
                                    resting: isOnFarm && farmerPlotsOnFarm[farmerIdx].workerResting,
                                    idleIndex: max(0, farmerIdx - farmerPlotsOnFarm.count)))
            idCounter += 1; farmerIdx += 1
        }

        // Veteran albas (tier 5): farm → cashier → unassigned
        let vetPlotIndices = store.farm.plots.indices.filter { store.farm.plots[$0].workerType == .veteranAlba }
        let vetPlotsOnFarm = vetPlotIndices.map { store.farm.plots[$0] }
        var vetIdx = 0; var vetIdleIdx = 0
        var remainingVetCashiers = (store.stall.cashierTier == 5) ? store.stall.cashierCount : 0
        for _ in 0..<store.stall.veteranAlbaCount {
            let a: WorkerItem.Assignment
            if vetIdx < vetPlotsOnFarm.count                  { a = .farm }
            else if remainingVetCashiers > 0                  { remainingVetCashiers -= 1; a = .cashier }
            else                                              { a = .unassigned }
            let e: Double; var asleep = false; var idle = 0; var lvl = 1
            switch a {
            case .farm:    e = vetPlotsOnFarm[vetIdx].workerEnergy; asleep = vetPlotsOnFarm[vetIdx].workerResting; lvl = vetPlotsOnFarm[vetIdx].workerLevel
            case .cashier: e = store.stall.cashierEnergy; asleep = store.stall.cashierResting; lvl = store.stall.cashierLevel
            default:
                e = store.stall.veteranAlbaIdleEnergies[safe: vetIdleIdx] ?? 1.0
                lvl = store.stall.veteranAlbaIdleLevels[safe: vetIdleIdx] ?? 1
                idle = vetIdleIdx
                vetIdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: vetIdx, tier: 5, assignment: a, energy: e, level: lvl,
                                    plot: a == .farm ? vetPlotIndices[vetIdx] : nil, resting: asleep, idleIndex: idle))
            idCounter += 1; vetIdx += 1
        }

        return items.sorted { a, b in
            let aUnassigned = a.assignment == .unassigned
            let bUnassigned = b.assignment == .unassigned
            if aUnassigned != bUnassigned { return aUnassigned }
            return a.energy > b.energy
        }
    }

    // MARK: - Reassign

    /// Maps a WorkerItem tier to the FarmWorkerType used for plot assignment.
    private func farmWorkerType(for tier: Int) -> FarmWorkerType {
        switch tier {
        case 4:  return .farmer
        case 5:  return .veteranAlba
        default: return .alba
        }
    }

    /// Moves a worker. From the bench she is taken by her own row (`idleIndex`), since levels make
    /// benched workers differ; between posts her live energy and level travel with her.
    private func reassign(worker: WorkerItem, to new: WorkerItem.Assignment) {
        guard new != worker.assignment else { return }
        let wt = farmWorkerType(for: worker.tier)
        let farmOnly = worker.tier == 4 || worker.tier == 5
        let activePlots = FarmSystem.activePlotCount(for: store.farm)
        let freePlot = (0..<activePlots).first(where: { !store.farm.plots[$0].hasWorker })

        // Farm-only types: farm and, for the veteran, the counter.
        if farmOnly {
            switch (worker.assignment, new) {
            case (.unassigned, .farm):
                if let freePlot { store.toggleFarmWorker(plotIndex: freePlot, workerType: wt, idleIndex: worker.idleIndex) }
            case (.unassigned, .cashier) where worker.tier == 5:
                store.assignToCashier(tier: 5, idleIndex: worker.idleIndex)
            case (.cashier, .unassigned) where worker.tier == 5:
                store.removeFromCashier(addToIdle: true)
            case (.farm, .unassigned):
                if let plot = worker.plot { store.toggleFarmWorker(plotIndex: plot, workerType: wt, addToIdle: true) }
            default: break
            }
            return
        }

        if worker.assignment == .unassigned {
            switch new {
            case .menu(let i): store.assignMenuCook(menuIndex: i, tier: worker.tier, idleIndex: worker.idleIndex)
            case .cashier:     store.assignToCashier(tier: worker.tier, idleIndex: worker.idleIndex)
            case .farm:
                if let freePlot { store.toggleFarmWorker(plotIndex: freePlot, workerType: .alba, idleIndex: worker.idleIndex) }
            case .unassigned: break
            }
            return
        }

        if new == .unassigned {
            switch worker.assignment {
            case .menu(let i): store.removeMenuCook(menuIndex: i, addToIdle: true)
            case .cashier:     store.removeFromCashier(addToIdle: true)
            case .farm:
                if let plot = worker.plot { store.toggleFarmWorker(plotIndex: plot, workerType: .alba, addToIdle: true) }
            case .unassigned: break
            }
            return
        }

        // Post to post: carry the live energy and level, skip the bench.
        let liveEnergy: Double
        switch worker.assignment {
        case .menu(let i): liveEnergy = store.stall.menuCookEnergy[safe: i] ?? 1.0
        case .cashier:     liveEnergy = store.stall.cashierEnergy
        case .farm:        liveEnergy = worker.plot.map { store.farm.plots[$0].workerEnergy } ?? 1.0
        case .unassigned:  liveEnergy = 1.0
        }
        let level = worker.level
        switch worker.assignment {
        case .menu(let i): store.removeMenuCook(menuIndex: i, addToIdle: false)
        case .cashier:     store.removeFromCashier(addToIdle: false)
        case .farm:
            if let plot = worker.plot { store.toggleFarmWorker(plotIndex: plot, workerType: .alba, addToIdle: false) }
        case .unassigned: break
        }
        let activeAfter = FarmSystem.activePlotCount(for: store.farm)
        switch new {
        case .menu(let i): store.assignMenuCook(menuIndex: i, tier: worker.tier, directEnergy: liveEnergy, directLevel: level)
        case .cashier:     store.assignToCashier(tier: worker.tier, directEnergy: liveEnergy, directLevel: level)
        case .farm:
            if let idx = (0..<activeAfter).first(where: { !store.farm.plots[$0].hasWorker }) {
                store.toggleFarmWorker(plotIndex: idx, workerType: .alba, directEnergy: liveEnergy, directLevel: level)
            }
        case .unassigned: break
        }
    }
}

// MARK: - Worker presentation

/// Sprite family and tier colour for a staff tier (1 alba ... 5 veteran alba).
private enum StaffLook {
    static func sprite(tier: Int, tired: Bool = false) -> String {
        let kind = ["alba", "alba", "imo", "chef", "farmer", "veteran_alba"][min(max(tier, 0), 5)]
        return "dot_char_\(kind)_\(tired ? "tired" : "idle_down")"
    }

    static func color(tier: Int) -> Color {
        switch tier {
        case 1: DotPalette.gold
        case 2: DotPalette.sky
        case 3: DotPalette.orange
        case 4: DotPalette.leaf
        default: DotPalette.mauve
        }
    }

    static func energyColor(_ e: Double) -> Color {
        if e > 0.6 { return DotPalette.leaf }
        if e > 0.3 { return DotPalette.gold }
        return DotPalette.red
    }
}

/// A figure on a small tinted plate, so tiers read at a glance.
private struct StaffPortrait: View {
    let tier: Int
    var tired = false
    var isUnlocked = true

    var body: some View {
        DotImage(StaffLook.sprite(tier: tier, tired: tired), scale: 2)
            .opacity(isUnlocked ? 1 : 0.4)
            .frame(width: 44, height: 52)
            .background(StaffLook.color(tier: tier).opacity(isUnlocked ? 0.45 : 0.2))
            .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px) }
    }
}

private struct DotCaret: View {
    var body: some View {
        // 5 x 3 px downward triangle, one row per step.
        VStack(spacing: 0) {
            Rectangle().frame(width: 10, height: 2)
            Rectangle().frame(width: 6, height: 2)
            Rectangle().frame(width: 2, height: 2)
        }
        .foregroundStyle(DotPalette.ink)
        .accessibilityHidden(true)
    }
}

private func staffName(_ tier: Int) -> String {
    switch tier {
    case 1: DotContent.loc("알바생")
    case 2: DotContent.loc("이모님")
    case 3: DotContent.loc("봄동 요리사")
    case 4: DotContent.loc("농부")
    default: DotContent.loc("고참 알바")
    }
}

// MARK: - WorkerRow

private struct WorkerRow: View {
    let worker: WorkerItem
    let menuTier: Int
    let menuCooks: [Int]
    let cashierCount: Int
    let activeFarmPlots: Int
    let farmPlots: [FarmPlot]
    let coins: Double
    let onReassign: (WorkerItem.Assignment) -> Void
    let onLevelUp: () -> Void
    let onFire: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the name line has no room for a third item: 해고 drops under the portrait.
    private var fireUnderPortrait: Bool { typeSize.isAccessibilitySize }

    /// Asleep at a post, or an idle worker still too drained to take one.
    private var isTired: Bool { worker.resting || (worker.assignment == .unassigned && worker.energy < 0.2) }
    private var levelStep: StaffLevelSystem.Step? {
        StaffLevelSystem.step(tier: worker.tier, fromLevel: worker.level)
    }

    private var options: [(WorkerItem.Assignment, Bool)] {
        var opts: [(WorkerItem.Assignment, Bool)] = [(.unassigned, true)]

        // Farm-only workers (tier 4 = 농부)
        if worker.tier == 4 {
            let freeSlots = (0..<activeFarmPlots).filter { !farmPlots[$0].hasWorker }.count
            opts.append((.farm, freeSlots > 0 || worker.assignment == .farm))
            return opts
        }

        // Tier 5 (고참 알바): farm or cashier
        if worker.tier == 5 {
            let freeSlots = (0..<activeFarmPlots).filter { !farmPlots[$0].hasWorker }.count
            opts.append((.farm, freeSlots > 0 || worker.assignment == .farm))
            let cashierFree = cashierCount == 0 || worker.assignment == .cashier
            opts.append((.cashier, cashierFree))
            return opts
        }

        if worker.tier == 1 {
            let freeSlots = (0..<activeFarmPlots).filter { !farmPlots[$0].hasWorker }.count
            opts.append((.farm, freeSlots > 0 || worker.assignment == .farm))
        }

        // Cashier: tier 1 and 2 only, single slot
        if worker.tier <= 2 {
            let cashierFree = cashierCount == 0 || worker.assignment == .cashier
            opts.append((.cashier, cashierFree))
        }

        for i in 0...menuTier {
            let slotTier = menuCooks[safe: i] ?? 0
            opts.append((.menu(i), slotTier == 0 || worker.assignment == .menu(i)))
        }
        return opts
    }

    private func assignmentLabel(_ a: WorkerItem.Assignment, energy: Double = 1.0, resting: Bool = false) -> String {
        if resting { return String(localized: "dot.staff.rest") }
        if case .unassigned = a, energy < 0.2 { return String(localized: "dot.staff.rest") }
        switch a {
        case .cashier:
            let percent = EarningsSystem.cashierSaleBonusPercent(tier: worker.tier)
            return String(format: String(localized: "cashier_assignment_format"), percent)
        case .menu(let i):
            return DotContent.loc(UpgradeDefinitions.menu[safe: i]?.name ?? "")
        case .farm: return String(localized: "dot.staff.farm")
        case .unassigned: return String(localized: "dot.staff.unassigned")
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 4) {
                StaffPortrait(tier: worker.tier, tired: isTired)
                    .overlay(alignment: .topTrailing) {
                        if worker.resting {
                            DotImage("dot_fx_zzz", scale: 1).offset(x: 4, y: -4)
                        }
                    }
                if fireUnderPortrait { fireButton }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(staffName(worker.tier)).dotText(.bold).lineLimit(1)
                    DotTag(text: String(format: String(localized: "dot.staff.level"), worker.level),
                           fill: StaffLook.color(tier: worker.tier), textColor: DotPalette.ink)
                    Spacer(minLength: 0)
                    if !fireUnderPortrait { fireButton }
                }
                DotMiniBar(value: worker.energy, color: StaffLook.energyColor(worker.energy))
                    .accessibilityLabel(String(localized: "dot.staff.energy"))
                    .accessibilityValue("\(Int((worker.energy * 100).rounded()))%")
                Text(wageText(tier: worker.tier, level: worker.level)).dotText(.caption, color: DotPalette.orangeDark)
                assignmentMenu
                levelControl
            }
        }
        .dotPanel()
        .accessibilityElement(children: .contain)
    }

    private var assignmentMenu: some View {
        Menu {
            ForEach(options, id: \.0) { option, available in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReassign(option)
                } label: {
                    if worker.assignment == option {
                        Label(assignmentLabel(option), systemImage: "checkmark")
                    } else {
                        Text(assignmentLabel(option))
                    }
                }
                .disabled(!available)
            }
        } label: {
            HStack(spacing: 6) {
                Text(assignmentLabel(worker.assignment, energy: worker.energy, resting: worker.resting))
                    .dotText(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                DotCaret()
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background { DotNineSlice(name: "dot_ui_panel").padding(.vertical, 6) }
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "dot.staff.assignment"))
        .accessibilityValue(assignmentLabel(worker.assignment, energy: worker.energy))
    }

    private var fireButton: some View {
        // Quiet cream face, not the green primary: it must not compete with the menu or the promote
        // button. The negative padding keeps the 44 pt hit area without growing the name line.
        Button(action: onFire) { Text(String(localized: "dot.staff.fire")) }
            .buttonStyle(.dotQuiet)
            .padding(.vertical, -10)
            .accessibilityLabel(String(format: String(localized: "dot.staff.fire.a11y"), staffName(worker.tier)))
            .accessibilityHint(String(localized: "dot.staff.fire.hint"))
    }

    /// The tradeoff is on screen before the coins are spent: level, speed and wage, from the GameCore tables.
    @ViewBuilder private var levelControl: some View {
        if let step = levelStep {
            let wageBefore = CoinFormat.string(step.wageBefore), wageAfter = CoinFormat.string(step.wageAfter)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "dot.staff.levelup.tradeoff"),
                            step.fromLevel, step.toLevel, step.speedGainPercent, wageBefore, wageAfter))
                    .dotText(.caption, color: DotPalette.orangeDark)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
                Button(action: onLevelUp) {
                    HStack(spacing: 4) {
                        Text(String(localized: "dot.staff.levelup"))
                        DotCostLabel(text: CoinFormat.string(step.cost))
                    }
                }
                .buttonStyle(.dotCompact)
                .disabled(coins < step.cost)
                .accessibilityLabel(String(
                    format: String(localized: "dot.staff.levelup.a11y"),
                    staffName(worker.tier), step.toLevel, CoinFormat.string(step.cost),
                    step.speedGainPercent, wageBefore, wageAfter))
            }
        } else {
            Text(String(localized: "dot.staff.levelmax")).dotText(.caption, color: DotPalette.soilDark)
        }
    }
}

// MARK: - HireTierRow

private struct HireTierRow: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dotPlaySound) private var play
    let tier: Int
    let onHired: (GameStore.HireResult?) -> Void

    private var def: UpgradeDefinition { UpgradeDefinitions.staff[tier - 1] }

    private var count: Int {
        switch tier {
        case 1: store.stall.tier1Count
        case 2: store.stall.tier2Count
        case 3: store.stall.tier3Count
        default: 0
        }
    }

    private var isUnlocked: Bool {
        UpgradeDefinitions.isStaffTierUnlocked(tier, stallTier: store.stall.stallTier)
    }

    private var unlockHint: String {
        switch tier {
        case 2: String(localized: "dot.staff.unlock.restaurant")
        case 3: String(localized: "dot.staff.unlock.specialty")
        default: ""
        }
    }

    var body: some View {
        HireRowLayout(tier: tier, name: staffName(tier), isUnlocked: isUnlocked, unlockHint: unlockHint,
                      lines: lines, cost: def.coinCost, coins: store.stall.coins, onHire: hire)
    }

    private var lines: [HireLine] {
        var result = [HireLine(DotContent.loc(def.description), color: DotPalette.textSecondary)]
        if tier <= 2 { result.append(HireLine(cashierHireHint(tier: tier), color: DotPalette.blue)) }
        result.append(wageLine(tier: tier))
        result.append(HireLine(String(format: String(localized: "staff_current_count"), count),
                               color: DotPalette.soilDark))
        return result
    }

    private func hire() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let result = store.hireWorker(tier: tier) else { return play(.error) }
        play(.purchase)
        onHired(result)
    }
}

// MARK: - Placement copy

enum HirePlacementText {
    /// nil for a hire that stayed unassigned.
    static func text(for result: GameStore.HireResult) -> String? {
        let key = "dot.hire.obj.\(result.tier)"
        let who = String(localized: String.LocalizationValue(key))
        switch result.placement {
        case .cook(let menu):
            let dish = DotContent.loc(UpgradeDefinitions.menu[menu].name)
            return String(format: String(localized: "dot.hire.placed.cook"), who, dish)
        case .cashier:
            return String(format: String(localized: "dot.hire.placed.cashier"), who)
        case .farm:
            return String(format: String(localized: "dot.hire.placed.farm"), who)
        case .unassigned:
            return nil
        }
    }
}

// MARK: - Cashier copy

/// What the counter pays off, as the hire lists show it; alba/이모님 and the veteran differ only in percent.
private func cashierHireHint(tier: Int) -> String {
    String(format: String(localized: "dot.staff.cashierHint"),
           EarningsSystem.cashierSaleBonusPercent(tier: tier))
}

// MARK: - HireFarmWorkerRow

private struct HireFarmWorkerRow: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dotPlaySound) private var play
    let tier: Int
    let def: UpgradeDefinition
    let count: Int
    let isUnlocked: Bool
    let unlockHint: String
    var cashierHint: String? = nil
    let onHire: () -> Void

    var body: some View {
        HireRowLayout(tier: tier, name: staffName(tier), isUnlocked: isUnlocked, unlockHint: unlockHint,
                      lines: lines, cost: def.coinCost, coins: store.stall.coins, onHire: hire)
    }

    private var lines: [HireLine] {
        var result = [
            HireLine(DotContent.loc(def.description), color: DotPalette.textSecondary),
            HireLine(String(format: String(localized: "growth_speed_format"),
                            String(format: "%.1f", def.productionMultiplier)), color: DotPalette.leafDark)
        ]
        if let cashierHint { result.append(HireLine(cashierHint, color: DotPalette.blue)) }
        result.append(wageLine(tier: tier))
        result.append(HireLine(String(format: String(localized: "staff_current_count"), count),
                               color: DotPalette.soilDark))
        return result
    }

    private func hire() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let before = store.stall.coins
        onHire()
        play(store.stall.coins < before ? .purchase : .error)
    }
}

// MARK: - Wage copy

private func wageText(tier: Int, level: Int = 1) -> String {
    String(format: String(localized: "dot.staff.wage"), CoinFormat.string(WageSystem.wage(forTier: tier, level: level)))
}

private func wageLine(tier: Int) -> HireLine {
    HireLine(wageText(tier: tier), color: DotPalette.orangeDark)
}

// MARK: - Shared hire layout

private struct HireLine: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
}

private struct HireRowLayout: View {
    let tier: Int
    let name: String
    let isUnlocked: Bool
    let unlockHint: String
    let lines: [HireLine]
    let cost: Double
    let coins: Double
    let onHire: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            StaffPortrait(tier: tier, isUnlocked: isUnlocked)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).dotText(.bold, color: isUnlocked ? DotPalette.ink : DotPalette.textSecondary)
                if isUnlocked {
                    ForEach(lines) { Text($0.text).dotText(.caption, color: $0.color) }
                } else {
                    DotHint(icon: "dot_ui_lock", text: unlockHint, color: DotPalette.orangeDark)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if isUnlocked {
                Button(action: onHire) { HireCostLabel(cost: cost, coins: coins) }
                    .buttonStyle(.dotCompact)
                    .disabled(coins < cost)
            }
        }
        .dotPanel()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - HireCostLabel

/// Price on a hire button; when unaffordable it shows the shortfall instead.
private struct HireCostLabel: View {
    let cost: Double
    let coins: Double

    var body: some View {
        if coins >= cost {
            DotCostLabel(text: CoinFormat.string(cost))
        } else {
            Text(String(format: String(localized: "%@ 코인 부족"), CoinFormat.string(ceil(cost - coins))))
        }
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
