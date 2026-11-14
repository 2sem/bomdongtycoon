import SwiftUI
import UIKit
import GameCore

/// Charge gauge that becomes the FEVER button once full, then a countdown while fever runs.
public struct FeverButton: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        if store.isFeverActive {
            active
        } else if store.isFeverReady {
            ready
        } else {
            charging
        }
    }

    private var percent: Int { Int((store.feverCharge * 100).rounded(.down)) }

    private var charging: some View {
        HStack(spacing: 6) {
            DotImage("dot_ui_fever", scale: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "dot.fever.title")).dotText(.caption, color: DotPalette.paper)
                DotProgressBar(value: store.feverCharge, tint: .gold).frame(width: 84)
            }
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "dot.fever.charging.accessibility"), percent))
    }

    /// Pulses by hopping one pixel; frozen under Reduce Motion.
    private var ready: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let hop = !reduceMotion && Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
            Button {
                if store.startFever() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            } label: {
                HStack(spacing: 4) {
                    DotImage("dot_ui_fever", scale: 1)
                    Text(String(localized: "dot.fever.ready"))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.dot)
            .offset(y: hop ? -DotTheme.px : 0)
        }
        .accessibilityLabel(String(localized: "dot.fever.ready.accessibility"))
    }

    private var active: some View {
        HStack(spacing: 6) {
            DotImage("dot_ui_fever", scale: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "dot.fever.active"), Int(store.feverRemaining.rounded(.up))))
                    .dotText(.caption, color: DotPalette.goldLight)
                DotProgressBar(value: store.feverRemaining / FeverSystem.duration, tint: .gold).frame(width: 84)
            }
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "dot.fever.active.accessibility"),
                                   Int(store.feverRemaining.rounded(.up))))
    }
}
