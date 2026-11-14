import SwiftUI
import UIKit
import GameCore

/// Today's three missions, with claim buttons and a countdown to the next set.
public struct MissionsSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dotPlaySound) private var play
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        DotSheet(title: String(localized: "dot.mission.title"), onClose: { isPresented = false }) {
            DotScroll {
                ForEach(store.missions) { mission in
                    MissionRow(mission: mission,
                               blockedReason: MissionSystem.blockedReason(kind: mission.kind, rating: store.progress.rating)) {
                        claim(mission)
                    }
                }
                if !store.missions.isEmpty {
                    BonusRow(reward: store.dailyBonusReward, isReady: store.isDailyBonusReady,
                             isClaimed: store.isDailyBonusClaimed,
                             done: store.missions.filter(\.isComplete).count, total: store.missions.count) {
                        guard store.claimDailyBonus() != nil else { return }
                        play(.missionDone)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                MissionCountdown()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private func claim(_ mission: Mission) {
        guard store.claimMission(id: mission.id) != nil else { return }
        play(.missionDone)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Row

private struct MissionRow: View {
    let mission: Mission
    var blockedReason: MissionBlock?
    let onClaim: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isReady: Bool { mission.isComplete && !mission.isClaimed }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            DotImage(Self.icon(mission.kind), scale: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.title(mission)).dotText(.bold).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    DotProgressBar(value: Double(mission.progress) / Double(max(mission.target, 1)),
                                   tint: isReady || mission.isClaimed ? .gold : .leaf)
                    Text("\(CoinFormat.string(Double(mission.progress)))/\(CoinFormat.string(Double(mission.target)))")
                        .dotText(.caption, color: DotPalette.textSecondary)
                        .fixedSize()
                }
                HStack(spacing: 4) {
                    DotImage("dot_ui_coin", scale: 1)
                    Text(CoinFormat.string(mission.reward)).dotText(.bold, color: DotPalette.goldDark)
                }
                if let reason = blockedReason, !mission.isComplete {
                    DotHint(icon: "dot_ui_lock", text: Self.text(for: reason), color: DotPalette.orangeDark)
                }
            }
            trailing
        }
        .dotPanel(.light, padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        .overlay(alignment: .topTrailing) {
            if isReady { readyFlag }
        }
        .opacity(mission.isClaimed ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var trailing: some View {
        if mission.isClaimed {
            VStack(spacing: 2) {
                DotImage("dot_ui_check", scale: 2)
                Text(String(localized: "dot.mission.claimed")).dotText(.caption, color: DotPalette.leafDark)
            }
        } else if mission.isComplete {
            Button(action: onClaim) { Text(String(localized: "dot.mission.claim")) }
                .buttonStyle(.dot)
        } else {
            DotImage("dot_ui_lock", scale: 1)
                .opacity(0.5)
                .accessibilityHidden(true)
        }
    }

    /// Gold tag hanging off the corner, so a finished mission cannot be missed.
    private var readyFlag: some View {
        Text(String(localized: "dot.mission.done"))
            .dotText(.caption, color: DotPalette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DotPalette.gold)
            .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px) }
            .offset(x: -8, y: -8)
            .accessibilityHidden(true)
    }

    private var accessibilityValue: String {
        if mission.isClaimed { return String(localized: "dot.mission.claimed") }
        if mission.isComplete { return String(localized: "dot.mission.done") }
        return "\(mission.progress)/\(mission.target)"
    }

    static func text(for block: MissionBlock) -> String {
        switch block {
        case .needsRating(let rating):
            String(format: String(localized: "dot.mission.gourmetLocked"), String(format: "%.1f", rating))
        }
    }

    static func icon(_ kind: MissionKind) -> String {
        switch kind {
        case .serveCustomers: "dot_ui_staff"
        case .harvest: "dot_ui_cabbage"
        case .earnCoins: "dot_ui_coin"
        case .cookDishes: "dot_dish_pot_0"
        case .triggerFever: "dot_ui_fever"
        case .serveGourmets: "dot_ui_star"
        }
    }

    static func title(_ mission: Mission) -> String {
        let n = mission.target
        switch mission.kind {
        case .serveCustomers: return String(format: String(localized: "dot.mission.serve"), n)
        case .harvest: return String(format: String(localized: "dot.mission.harvest"), n)
        case .earnCoins: return String(format: String(localized: "dot.mission.earn"), CoinFormat.string(Double(n)))
        case .cookDishes: return String(format: String(localized: "dot.mission.cook"), n)
        case .triggerFever: return String(format: String(localized: "dot.mission.fever"), n)
        case .serveGourmets: return String(format: String(localized: "dot.mission.gourmet"), n)
        }
    }
}

// MARK: - Daily bonus

/// The fourth row: finish all of today's missions for twice a single reward.
private struct BonusRow: View {
    let reward: Double
    let isReady: Bool
    let isClaimed: Bool
    let done: Int
    let total: Int
    let onClaim: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            DotImage("dot_ui_mission", scale: 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "dot.mission.bonus.title")).dotText(.bold)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    DotProgressBar(value: Double(done) / Double(max(total, 1)), tint: isReady || isClaimed ? .gold : .leaf)
                    Text("\(done)/\(total)").dotText(.caption, color: DotPalette.textSecondary).fixedSize()
                }
                HStack(spacing: 4) {
                    DotImage("dot_ui_coin", scale: 1)
                    Text(CoinFormat.string(reward)).dotText(.bold, color: DotPalette.goldDark)
                }
            }
            if isClaimed {
                VStack(spacing: 2) {
                    DotImage("dot_ui_check", scale: 2)
                    Text(String(localized: "dot.mission.claimed")).dotText(.caption, color: DotPalette.leafDark)
                }
            } else if isReady {
                Button(action: onClaim) { Text(String(localized: "dot.mission.claim")) }
                    .buttonStyle(.dot)
            } else {
                DotImage("dot_ui_lock", scale: 1).opacity(0.5).accessibilityHidden(true)
            }
        }
        .dotPanel(.light, padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        .opacity(isClaimed ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Countdown

/// "New missions in 5h 10m": missions reset at local midnight. Under an hour it is minutes only.
private struct MissionCountdown: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 6) {
                DotImage("dot_ui_clock", scale: 1)
                Text(Self.text(from: context.date)).dotText(.body, color: DotPalette.soilDark).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    static func text(from now: Date, calendar: Calendar = .current) -> String {
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                         matchingPolicy: .nextTime) ?? now
        let minutes = max(0, Int(midnight.timeIntervalSince(now))) / 60
        if minutes >= 60 {
            return String(format: String(localized: "dot.mission.countdown.hm"), minutes / 60, minutes % 60)
        }
        return String(format: String(localized: "dot.mission.countdown.m"), max(minutes, 1))
    }
}
