import SwiftUI
import GameCore

// MARK: - JobSheet

public struct JobSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        NavigationStack {
            List {
                kitchenSection
                cashierSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "배치 관리"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "닫기")) { isPresented = false }
                }
            }
        }
    }

    // MARK: - Kitchen section

    private var kitchenSection: some View {
        Section {
            ForEach(0...2, id: \.self) { menuIndex in
                if menuIndex <= store.stall.menuTier {
                    MenuSlotRow(
                        menuIndex: menuIndex,
                        workers: allWorkers,
                        onAssign: { assign(menuIndex: menuIndex, workerID: $0) }
                    )
                    .environmentObject(store)
                } else {
                    LockedMenuRow(menuIndex: menuIndex, stallTier: store.stall.stallTier)
                }
            }
            if allWorkers.isEmpty {
                Text(String(localized: "고용 탭에서 직원을 채용하면 여기서 배치할 수 있어요"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        } header: {
            Text(String(localized: "🍳 주방")).foregroundStyle(Color.jobAmber)
        }
    }

    // MARK: - Cashier section

    private var cashierSection: some View {
        Section {
            CashierSlotRow(
                workers: allWorkers.filter { $0.tier <= 2 || $0.tier == 5 },
                onAssign: { assignCashier(workerID: $0) }
            )
            .environmentObject(store)
        } header: {
            Text(String(localized: "💰 계산대")).foregroundStyle(Color.jobAmber)
        }
    }

    // MARK: - Build worker list

    /// All workers with their current assignments and energy — mirrors StaffSheet.buildWorkers().
    private var allWorkers: [JobWorkerItem] {
        var items: [JobWorkerItem] = [];
        var idCounter = 0;
        var remainingCashiers = store.stall.cashierCount;

        func menuSlots(for tier: Int) -> ArraySlice<Int> {
            let slots = (0..<store.stall.menuCooks.count).filter { store.stall.menuCooks[$0] == tier };
            return slots[...];
        }

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

        var t1IdleIdx = 0; var t2IdleIdx = 0; var t3IdleIdx = 0;

        // Tier 3 (봄동 요리사): menus only
        var t3 = menuSlots(for: 3);
        var tier3Idx = 0;
        for _ in 0..<store.stall.tier3Count {
            let a: JobAssignment = t3.isEmpty ? .unassigned : .menu(t3.removeFirst());
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            default:
                e = store.stall.tier3IdleEnergies[safe: t3IdleIdx] ?? 1.0;
                t3IdleIdx += 1;
            }
            items.append(JobWorkerItem(id: idCounter, indexInTier: tier3Idx, tier: 3, assignment: a, energy: e));
            idCounter += 1; tier3Idx += 1;
        }

        // Tier 2 (이모님): menus → cashier → unassigned
        var t2 = menuSlots(for: 2);
        var tier2Idx = 0;
        for _ in 0..<store.stall.tier2Count {
            let a: JobAssignment;
            if !t2.isEmpty                                                  { a = .menu(t2.removeFirst()) }
            else if remainingCashiers > 0 && store.stall.cashierTier == 2  { remainingCashiers -= 1; a = .cashier }
            else                                                            { a = .unassigned }
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            case .cashier:     e = store.stall.cashierEnergy
            default:
                e = store.stall.tier2IdleEnergies[safe: t2IdleIdx] ?? 1.0;
                t2IdleIdx += 1;
            }
            items.append(JobWorkerItem(id: idCounter, indexInTier: tier2Idx, tier: 2, assignment: a, energy: e));
            idCounter += 1; tier2Idx += 1;
        }

        // Tier 1 (알바생): menus → farm → cashier → unassigned
        var t1 = menuSlots(for: 1);
        var albaFarmWorkers = store.farm.plots.filter { $0.workerType == .alba }.count;
        var tier1Idx = 0;
        for _ in 0..<store.stall.tier1Count {
            let a: JobAssignment;
            if !t1.isEmpty                                                  { a = .menu(t1.removeFirst()) }
            else if albaFarmWorkers > 0                                     { albaFarmWorkers -= 1; a = .farm }
            else if remainingCashiers > 0 && store.stall.cashierTier == 1  { remainingCashiers -= 1; a = .cashier }
            else                                                            { a = .unassigned }
            let e: Double;
            switch a {
            case .menu(let i): e = store.stall.menuCookEnergy[safe: i] ?? 1.0
            case .cashier:     e = store.stall.cashierEnergy
            case .farm:        e = nextFarmWorkerEnergy()
            default:
                e = store.stall.tier1IdleEnergies[safe: t1IdleIdx] ?? 1.0;
                t1IdleIdx += 1;
            }
            items.append(JobWorkerItem(id: idCounter, indexInTier: tier1Idx, tier: 1, assignment: a, energy: e));
            idCounter += 1; tier1Idx += 1;
        }

        // Tier 5 (고참 알바): farm → cashier → unassigned
        let vetPlotsOnFarm = store.farm.plots.filter { $0.workerType == .veteranAlba };
        var vetIdx = 0; var vetIdleIdx = 0;
        for _ in 0..<store.stall.veteranAlbaCount {
            let a: JobAssignment;
            if vetIdx < vetPlotsOnFarm.count                                { a = .farm }
            else if remainingCashiers > 0 && store.stall.cashierTier == 5  { remainingCashiers -= 1; a = .cashier }
            else                                                            { a = .unassigned }
            let e: Double;
            switch a {
            case .farm:    e = vetPlotsOnFarm[vetIdx].workerEnergy
            case .cashier: e = store.stall.cashierEnergy
            default:
                e = store.stall.veteranAlbaIdleEnergies[safe: vetIdleIdx] ?? 1.0;
                vetIdleIdx += 1;
            }
            items.append(JobWorkerItem(id: idCounter, indexInTier: vetIdx, tier: 5, assignment: a, energy: e));
            idCounter += 1; vetIdx += 1;
        }

        return items;
    }

    // MARK: - Assignment actions

    /// Assign a worker (by ID) to a menu slot. Pass nil to clear the slot.
    private func assign(menuIndex: Int, workerID: Int?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred();
        guard menuIndex < store.stall.menuCooks.count else { return }

        // Unassign current cook from this slot if any
        if store.stall.menuCooks[menuIndex] > 0 {
            store.removeMenuCook(menuIndex: menuIndex, addToIdle: true)
        }

        guard let wid = workerID,
              let worker = allWorkers.first(where: { $0.id == wid }) else { return }

        // Unassign worker from their current position first
        unassignWorker(worker)

        // Assign to menu slot
        store.assignMenuCook(menuIndex: menuIndex, tier: worker.tier)
    }

    /// Assign a worker (by ID) to the cashier slot. Pass nil to clear.
    private func assignCashier(workerID: Int?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred();

        if store.stall.cashierCount > 0 {
            store.removeFromCashier(addToIdle: true)
        }

        guard let wid = workerID,
              let worker = allWorkers.first(where: { $0.id == wid }) else { return }

        unassignWorker(worker)
        store.assignToCashier(tier: worker.tier)
    }

    /// Remove a worker from their current position without caring what it is.
    private func unassignWorker(_ worker: JobWorkerItem) {
        switch worker.assignment {
        case .menu(let i):
            store.removeMenuCook(menuIndex: i, addToIdle: true)
        case .cashier:
            store.removeFromCashier(addToIdle: true)
        case .farm:
            let wt: FarmWorkerType = worker.tier == 5 ? .veteranAlba : .alba
            if let idx = store.farm.plots.firstIndex(where: { $0.workerType == wt }) {
                store.toggleFarmWorker(plotIndex: idx, workerType: wt, addToIdle: true)
            }
        case .unassigned:
            break
        }
    }
}

// MARK: - MenuSlotRow

private struct MenuSlotRow: View {
    @EnvironmentObject var store: GameStore
    let menuIndex: Int
    let workers: [JobWorkerItem]
    let onAssign: (Int?) -> Void

    private static let menuAssetNames = ["produce_cabbage", "produce_salad", "produce_stew"]

    private var def: UpgradeDefinition? { UpgradeDefinitions.menu[safe: menuIndex] }
    private var assignedWorker: JobWorkerItem? {
        workers.first { $0.assignment == .menu(menuIndex) }
    }
    private var energy: Double { assignedWorker?.energy ?? 1.0 }

    var body: some View {
        HStack(spacing: 12) {
            // Slot icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.93, green: 0.70, blue: 0.18))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(Self.menuAssetNames[safe: menuIndex] ?? "dish_icon")
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                .overlay(alignment: .topTrailing) {
                    if let w = assignedWorker, w.energy < 0.05 {
                        Image("warning_badge")
                            .resizable()
                            .frame(width: 11, height: 11)
                            .offset(x: 6, y: -6)
                    }
                }

            // Name + energy
            VStack(alignment: .leading, spacing: 4) {
                Text(def?.name ?? String(format: String(localized: "menu_slot_number"), menuIndex + 1)).font(.headline)
                Text(String(format: String(localized: "menu_slot_number"), menuIndex + 1)).font(.caption).foregroundStyle(.secondary)
                if assignedWorker != nil {
                    energyBar(energy)
                }
            }

            Spacer()

            // Picker
            workerPicker
        }
        .padding(.vertical, 2)
    }

    private var workerPicker: some View {
        Menu {
            // Clear option
            Button {
                onAssign(nil)
            } label: {
                if assignedWorker == nil {
                    Label(String(localized: "비어있음"), systemImage: "checkmark")
                } else {
                    Text(String(localized: "비어있음"))
                }
            }

            Divider()

            ForEach(eligibleWorkers, id: \.id) { worker in
                Button {
                    onAssign(worker.id)
                } label: {
                    if worker.assignment == .menu(menuIndex) {
                        Label(workerLabel(worker), systemImage: "checkmark")
                    } else {
                        Text(workerLabel(worker))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(pickerLabel).font(.caption.bold())
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.jobAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Color.jobAmber)
        }
    }

    private var pickerLabel: String {
        guard let w = assignedWorker else { return String(localized: "비어있음") }
        return workerName(w)
    }

    private var eligibleWorkers: [JobWorkerItem] {
        workers.filter { ($0.assignment == .menu(menuIndex) || $0.assignment == .unassigned) && $0.tier != 5 }
    }

    private func workerLabel(_ worker: JobWorkerItem) -> String { workerName(worker) }

    private func workerName(_ worker: JobWorkerItem) -> String {
        let names = ["", "알바생", "이모님", "봄동 요리사", "", "고참 알바"]
        return "\(names[safe: worker.tier] ?? "직원") #\(worker.indexInTier + 1)"
    }

    private func energyColor(_ e: Double) -> Color {
        if e > 0.6 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if e > 0.3 { return Color(red: 0.95, green: 0.75, blue: 0.1) }
        return Color(red: 0.9, green: 0.25, blue: 0.2)
    }

    private func energyBar(_ e: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.2))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(energyColor(e))
                    .scaleEffect(x: CGFloat(e), anchor: .leading)
            }
            .frame(height: 4)
            .clipped()
    }
}

// MARK: - CashierSlotRow

private struct CashierSlotRow: View {
    @EnvironmentObject var store: GameStore
    let workers: [JobWorkerItem]   // pre-filtered to tier <= 2
    let onAssign: (Int?) -> Void

    private var assignedWorker: JobWorkerItem? {
        workers.first { $0.assignment == .cashier }
    }
    private var energy: Double { store.stall.cashierEnergy }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.62, green: 0.80, blue: 0.95))
                .frame(width: 40, height: 40)
                .overlay { Text("🧾").font(.system(size: 22)) }
                .overlay(alignment: .topTrailing) {
                    if assignedWorker != nil, energy < 0.05 {
                        Image("warning_badge")
                            .resizable()
                            .frame(width: 11, height: 11)
                            .offset(x: 6, y: -6)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "계산대")).font(.headline)
                Text(String(localized: "판매 자동 처리")).font(.caption).foregroundStyle(.secondary)
                if assignedWorker != nil {
                    energyBar(energy)
                }
            }

            Spacer()

            workerPicker
        }
        .padding(.vertical, 2)
    }

    private var workerPicker: some View {
        Menu {
            Button {
                onAssign(nil)
            } label: {
                if assignedWorker == nil {
                    Label(String(localized: "비어있음"), systemImage: "checkmark")
                } else {
                    Text(String(localized: "비어있음"))
                }
            }

            Divider()

            ForEach(workers.filter { $0.assignment == .cashier || $0.assignment == .unassigned }, id: \.id) { worker in
                Button {
                    onAssign(worker.id)
                } label: {
                    if worker.assignment == .cashier {
                        Label(workerLabel(worker), systemImage: "checkmark")
                    } else {
                        Text(workerLabel(worker))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(pickerLabel).font(.caption.bold())
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.jobAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Color.jobAmber)
        }
    }

    private var pickerLabel: String {
        guard let w = assignedWorker else { return String(localized: "비어있음") }
        return workerName(w)
    }

    private func workerLabel(_ worker: JobWorkerItem) -> String { workerName(worker) }

    private func workerName(_ worker: JobWorkerItem) -> String {
        let names = ["", "알바생", "이모님", "봄동 요리사", "", "고참 알바"]
        return "\(names[safe: worker.tier] ?? "직원") #\(worker.indexInTier + 1)"
    }

    private func energyColor(_ e: Double) -> Color {
        if e > 0.6 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if e > 0.3 { return Color(red: 0.95, green: 0.75, blue: 0.1) }
        return Color(red: 0.9, green: 0.25, blue: 0.2)
    }

    private func energyBar(_ e: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.2))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(energyColor(e))
                    .scaleEffect(x: CGFloat(e), anchor: .leading)
            }
            .frame(height: 4)
            .clipped()
    }
}

// MARK: - LockedMenuRow

private struct LockedMenuRow: View {
    let menuIndex: Int
    let stallTier: Int

    private var def: UpgradeDefinition? { UpgradeDefinitions.menu[safe: menuIndex] }
    private var unlockHint: String {
        switch menuIndex {
        case 1: return "봄동 식당 업그레이드 필요"
        case 2: return "봄동 전문점 업그레이드 필요"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(def?.name ?? String(format: String(localized: "menu_slot_number"), menuIndex + 1))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(unlockHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(String(localized: "잠김")).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - JobWorkerItem

private struct JobWorkerItem: Identifiable {
    let id: Int
    let indexInTier: Int
    let tier: Int
    var assignment: JobAssignment
    var energy: Double
}

// MARK: - JobAssignment

private enum JobAssignment: Hashable {
    case unassigned, farm, cashier, menu(Int)

    var shortLabel: String {
        switch self {
        case .unassigned:  return "미배정"
        case .farm:        return "텃밭"
        case .cashier:     return "계산대"
        case .menu(let i): return "메뉴 \(i + 1)"
        }
    }
}

// MARK: - Helpers

private extension Color {
    static let jobAmber = Color(red: 0.72, green: 0.40, blue: 0.10)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
