import SwiftUI
import UIKit
import GameCore

/// Charge gauge that becomes the FEVER button once full, then a countdown while fever runs.
public struct FeverButton: View {
    @EnvironmentObject var store: GameStore
    @EnvironmentObject var ads: RewardedAds
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPulsing: Bool
    let onTap: () -> Void

    /// Tall enough for the tallest of the three forms, so the bar above the tab bar never changes height.
    public static let slotHeight: CGFloat = 60

    public init(isPulsing: Bool = false, onTap: @escaping () -> Void = {}) {
        self.isPulsing = isPulsing
        self.onTap = onTap
    }

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

    @ViewBuilder
    private var charging: some View {
        // No ad surface before ads are set up: the root view is mounted under the splash, and an
        // `onAppear` prepare fired that early has no manager to load with.
        if store.isFeverAdAvailable, ads.isAvailable {
            adCharging
        } else {
            chargingPanel(title: Text(String(localized: "dot.fever.title")).dotText(.caption, color: DotPalette.paper))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: String(localized: "dot.fever.charging.accessibility"), percent))
        }
    }

    private func chargingPanel<Title: View>(title: Title) -> some View {
        HStack(spacing: 6) {
            DotImage("dot_ui_fever", scale: 1)
            VStack(alignment: .leading, spacing: 2) {
                title
                DotProgressBar(value: store.feverCharge, tint: .gold).frame(width: 84)
            }
        }
        .dotPanel(.dark, padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 12))
    }

    /// The AD label takes the title's line, so the panel keeps the height of the plain one.
    private var adCharging: some View {
        let isReady = ads.isReady(.fever)
        return TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let hop = isPulsing && isReady && !reduceMotion
                && Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 2 == 0
            Button(action: onTap) {
                chargingPanel(title: Group {
                    if isReady {
                        DotAdLabel(text: String(localized: "dot.ad.fever.charge"))
                    } else {
                        Text(String(localized: "dot.ad.loading"))
                    }
                }
                .dotText(.caption, color: DotPalette.goldLight))
            }
            .buttonStyle(.plain)
            .disabled(!isReady)
            .offset(y: hop ? -DotTheme.px : 0)
        }
        .accessibilityLabel(DotAdText.accessibility(
            String(format: String(localized: "dot.fever.charging.accessibility"), percent)))
        .onAppear { ads.prepare(.fever) }
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
