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
                    MissionRow(mission: mission) { claim(mission) }
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

// MARK: - Countdown

/// "New missions in HH:MM": missions reset at local midnight.
private struct MissionCountdown: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = String(format: String(localized: "dot.mission.countdown"), Self.remaining(from: context.date))
            HStack(spacing: 6) {
                DotImage("dot_ui_clock", scale: 1)
                Text(text).dotText(.body, color: DotPalette.soilDark).monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        }
    }

    static func remaining(from now: Date, calendar: Calendar = .current) -> String {
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                         matchingPolicy: .nextTime) ?? now
        let seconds = max(0, Int(midnight.timeIntervalSince(now)))
        return String(format: "%02d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }
}
