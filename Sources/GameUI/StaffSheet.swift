import SwiftUI
import GameCore

// MARK: - WorkerItem

private struct WorkerItem: Identifiable {
    let id: Int;
    let indexInTier: Int;
    let tier: Int;
    var assignment: Assignment;
    var energy: Double;

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

// MARK: - StaffSheet

public struct StaffSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool
    @State private var tab = 0

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                TabView(selection: $tab) {
                    workerList.tag(0)
                    hireList.tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: tab)
            }
            .navigationTitle("직원 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("직원", tag: 0)
            tabButton("고용", tag: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Worker list

    private var workerList: some View {
        let workers = buildWorkers()
        return List {
            if workers.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("고용 탭에서 직원을 채용하세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                }
            } else {
                Section {
                    ForEach(workers) { worker in
                        WorkerRow(
                            worker: worker,
                            menuTier: store.stall.menuTier,
                            menuCooks: store.stall.menuCooks,
                            cashierCount: store.stall.cashierCount,
                            activeFarmPlots: FarmSystem.activePlotCount(for: store.farm),
                            farmPlots: store.farm.plots,
                            onReassign: { reassign(worker: worker, to: $0) }
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if worker.assignment == .unassigned, worker.tier < 3 {
                                let cost = UpgradeDefinitions.staff[safe: worker.tier]?.coinCost ?? 0
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    store.upgradeWorker(fromTier: worker.tier, preservingEnergy: worker.energy)
                                } label: {
                                    Label("업그레이드", systemImage: "arrow.up.circle.fill")
                                }
                                .tint(store.stall.coins >= cost ? .green : .gray)
                                .disabled(store.stall.coins < cost)
                            }
                        }
                    }
                } header: {
                    Text("직원 목록")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Hire list

    private var hireList: some View {
        List {
            Section {
                ForEach(1...3, id: \.self) { tier in
                    HireTierRow(tier: tier, menuCount: store.stall.menuTier + 1,
                                onHired: { withAnimation { tab = 0 } })
                        .environmentObject(store)
                }
            } header: {
                Text("직원 고용").foregroundStyle(Color.staffAmber)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Tab button

    private func tabButton(_ title: String, tag: Int) -> some View {
        Button { tab = tag } label: {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    tab == tag ? Color.staffAmber : Color.staffAmber.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(tab == tag ? .white : Color.staffAmber)
        }
        .buttonStyle(.plain)
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
        func nextFarmWorkerEnergy() -> Double {
            while farmPlotCursor < store.farm.plots.count {
                if store.farm.plots[farmPlotCursor].hasWorker {
                    let e = store.farm.plots[farmPlotCursor].workerEnergy;
                    farmPlotCursor += 1;
                    return e;
                }
                farmPlotCursor += 1;
            }
            return 1.0;
        }

        // Idle energy cursors — parallel-index into the tier's idle pool
        var t3IdleIdx = 0; var t2IdleIdx = 0; var t1IdleIdx = 0

        // Tier 3 (봄동 요리사): menus only
        var t3 = menuSlots(for: 3);
        var tier3Idx = 0;
        for _ in 0..<store.stall.tier3Count {
            let a: WorkerItem.Assignment = t3.isEmpty ? .unassigned : .menu(t3.removeFirst());
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            default:
                e = store.stall.tier3IdleEnergies[safe: t3IdleIdx] ?? 1.0
                t3IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier3Idx, tier: 3, assignment: a, energy: e));
            idCounter += 1; tier3Idx += 1;
        }

        // Tier 2 (이모님): menus → cashier → unassigned
        var t2 = menuSlots(for: 2);
        var tier2Idx = 0;
        for _ in 0..<store.stall.tier2Count {
            let a: WorkerItem.Assignment;
            if !t2.isEmpty               { a = .menu(t2.removeFirst()) }
            else if remainingCashiers > 0 { remainingCashiers -= 1; a = .cashier }
            else                          { a = .unassigned }
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            case .cashier:     e = store.stall.cashierEnergy
            default:
                e = store.stall.tier2IdleEnergies[safe: t2IdleIdx] ?? 1.0
                t2IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier2Idx, tier: 2, assignment: a, energy: e));
            idCounter += 1; tier2Idx += 1;
        }

        // Tier 1 (알바생): menus → farm → cashier → unassigned
        var t1 = menuSlots(for: 1);
        var farmWorkers = store.farm.plots.filter { $0.hasWorker }.count;
        var tier1Idx = 0;
        for _ in 0..<store.stall.tier1Count {
            let a: WorkerItem.Assignment;
            if !t1.isEmpty               { a = .menu(t1.removeFirst()) }
            else if farmWorkers > 0       { farmWorkers -= 1; a = .farm }
            else if remainingCashiers > 0 { remainingCashiers -= 1; a = .cashier }
            else                          { a = .unassigned }
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            case .cashier:     e = store.stall.cashierEnergy
            case .farm:        e = nextFarmWorkerEnergy()
            default:
                e = store.stall.tier1IdleEnergies[safe: t1IdleIdx] ?? 1.0
                t1IdleIdx += 1
            }
            items.append(WorkerItem(id: idCounter, indexInTier: tier1Idx, tier: 1, assignment: a, energy: e));
            idCounter += 1; tier1Idx += 1;
        }

        return items.sorted { a, b in
            let aUnassigned = a.assignment == .unassigned
            let bUnassigned = b.assignment == .unassigned
            if aUnassigned != bUnassigned { return aUnassigned }
            return a.energy > b.energy
        }
    }

    // MARK: - Reassign

    private func reassign(worker: WorkerItem, to new: WorkerItem.Assignment) {
        guard new != worker.assignment else { return }

        // Unassign from current — pass worker.energy so the displayed value is preserved
        switch worker.assignment {
        case .menu(let i):   store.removeMenuCook(menuIndex: i, displayedEnergy: worker.energy)
        case .cashier:       store.removeFromCashier(displayedEnergy: worker.energy)
        case .farm:
            if let idx = store.farm.plots.firstIndex(where: { $0.hasWorker }) {
                store.toggleWorker(plotIndex: idx, displayedEnergy: worker.energy)
            }
        case .unassigned: break
        }

        // Assign to new position
        switch new {
        case .menu(let i):   store.assignMenuCook(menuIndex: i, tier: worker.tier)
        case .cashier:       store.assignToCashier(tier: worker.tier)
        case .farm:
            let active = FarmSystem.activePlotCount(for: store.farm)
            if let idx = (0..<active).first(where: { !store.farm.plots[$0].hasWorker }) {
                store.toggleWorker(plotIndex: idx)
            }
        case .unassigned: break
        }
    }
}

// MARK: - WorkerRow

private struct WorkerRow: View {
    let worker: WorkerItem;
    let menuTier: Int;
    let menuCooks: [Int];
    let cashierCount: Int;
    let activeFarmPlots: Int;
    let farmPlots: [FarmPlot];
    let onReassign: (WorkerItem.Assignment) -> Void;

    private static let name  = ["", "알바생", "이모님", "봄동 요리사"];

    private static let tier1Emojis = ["🧑", "👦", "👧", "👱‍♂️", "👱‍♀️", "🧑‍💼"]
    private static let tier3Emojis = ["👨‍🍳", "👩‍🍳"]

    private func workerEmoji(tier: Int, indexInTier: Int) -> String {
        switch tier {
        case 1:  Self.tier1Emojis[indexInTier % Self.tier1Emojis.count]
        case 2:  "👵"
        case 3:  Self.tier3Emojis[indexInTier % Self.tier3Emojis.count]
        default: "🧑"
        }
    }

    private var options: [(WorkerItem.Assignment, Bool)] {
        var opts: [(WorkerItem.Assignment, Bool)] = [(.unassigned, true)]

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

    private func assignmentLabel(_ a: WorkerItem.Assignment, energy: Double = 1.0) -> String {
        if case .unassigned = a, energy < 0.2 { return "😴 휴식" }
        switch a {
        case .menu(let i): return UpgradeDefinitions.menu[safe: i]?.name ?? "메뉴 \(i + 1)"
        default:           return a.label
        }
    }

    private func energyColor(_ e: Double) -> Color {
        if e > 0.6 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if e > 0.3 { return Color(red: 0.95, green: 0.75, blue: 0.1) }
        return Color(red: 0.9, green: 0.25, blue: 0.2);
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tierColor(worker.tier))
                    .frame(width: 40, height: 40)
                Text(workerEmoji(tier: worker.tier, indexInTier: worker.indexInTier))
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.name[worker.tier]).font(.headline)
                Text(assignmentLabel(worker.assignment, energy: worker.energy))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(energyColor(worker.energy))
                            .frame(width: geo.size.width * CGFloat(worker.energy), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

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
                    HStack(spacing: 4) {
                        Text(assignmentLabel(worker.assignment, energy: worker.energy)).font(.caption.bold())
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.staffAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.staffAmber)
                }
        }
        .padding(.vertical, 2)
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1:  Color(red: 0.93, green: 0.70, blue: 0.18)
        case 2:  Color(red: 0.62, green: 0.80, blue: 0.95)
        case 3:  Color(red: 0.96, green: 0.76, blue: 0.38)
        default: Color.gray.opacity(0.3)
        }
    }
}

// MARK: - HireTierRow

private struct HireTierRow: View {
    @EnvironmentObject var store: GameStore
    let tier: Int
    let menuCount: Int
    let onHired: () -> Void

    private var def: UpgradeDefinition { UpgradeDefinitions.staff[tier - 1] }

    private var count: Int {
        switch tier {
        case 1: store.stall.tier1Count
        case 2: store.stall.tier2Count
        case 3: store.stall.tier3Count
        default: 0
        }
    }

    /// Tier 2+3 workers fill menu slots — cap at total menus
    private var isAtCap: Bool {
        guard tier >= 2 else { return false }
        return store.stall.tier2Count + store.stall.tier3Count >= menuCount
    }

    private var isUnlocked: Bool {
        switch tier {
        case 1: true
        case 2: store.stall.stallTier >= 1
        case 3: store.stall.stallTier >= 2
        default: false
        }
    }

    private var unlockHint: String {
        switch tier {
        case 2: return "봄동 식당 업그레이드 필요"
        case 3: return "봄동 전문점 업그레이드 필요"
        default: return ""
        }
    }

    private static let hireEmoji = ["", "🧑", "👵", "👨‍🍳"]

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isUnlocked ? Color.staffAmber.opacity(0.8) : Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(Self.hireEmoji[tier]).font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(def.name).font(.headline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                if isUnlocked {
                    Text(def.description).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("현재 \(count)명").font(.caption2).foregroundStyle(Color.staffAmber)
                        if tier >= 2 {
                            Text("/ 최대 \(menuCount)명").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text(unlockHint).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isUnlocked {
                if isAtCap {
                    Text("최대").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.hireWorker(tier: tier)
                        onHired()
                    } label: {
                        Text("₩\(Int(def.coinCost))").font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(store.stall.coins >= def.coinCost ? Color.staffAmber : .gray)
                    .disabled(store.stall.coins < def.coinCost)
                    .controlSize(.small)
                }
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

private extension Color {
    static let staffAmber = Color(red: 0.72, green: 0.40, blue: 0.10)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
