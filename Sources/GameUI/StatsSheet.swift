import SwiftUI
import GameCore

/// "기록": this run, lifetime totals and, after a first spring, the legacy. Read-only, plus the sound switch.
public struct StatsSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool
    /// Same key as `DotSound.enabledKey` in the app target.
    @AppStorage("settings.soundEnabled") private var isSoundOn = true

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private var progress: PlayerProgress { store.progress }
    private var hasLegacy: Bool { progress.prestigeCount > 0 }
    private var hasNoRecord: Bool { progress.totalServed == 0 && progress.totalFailed == 0 }

    public var body: some View {
        DotSheet(title: String(localized: "stats.title"), onClose: { isPresented = false }) {
            DotScroll {
                if hasLegacy { header }
                runSection
                lifetimeSection
                if hasLegacy { legacySection }
                settingsSection
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        let n = progress.prestigeCount
        let multiplier = PrestigeSystem.multiplierText(prestigeCount: n)
        let plain = PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: n))
        return HStack(spacing: 8) {
            DotImage("dot_ui_star", scale: 2)
            Text(String(format: String(localized: "stats.header"), multiplier, n))
                .dotText(.bold)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .dotPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "stats.header.accessibility"), plain, n))
    }

    private var runSection: some View {
        group(String(localized: "stats.section.run")) {
            row("stats.run.duration", Self.durationText(progress.runPlaySeconds))
            row("stats.run.earned", CoinFormat.string(progress.runEarned))
            row("stats.run.served", Self.count(progress.runServed))
        }
    }

    private var lifetimeSection: some View {
        group(String(localized: "stats.section.lifetime"), footer: hasNoRecord ? String(localized: "stats.empty") : nil) {
            row("stats.earned", CoinFormat.string(progress.totalEarned))
            row("stats.served", Self.count(progress.totalServed))
            row("stats.failed", Self.count(progress.totalFailed))
            row("stats.successRate", StatsFormat.successRate(served: progress.totalServed, failed: progress.totalFailed) ?? Self.dash)
            row("stats.bestRating", hasNoRecord && progress.bestRating == 0
                ? Self.dash : String(format: "★%.1f", progress.highestRating))
            row("dot.stats.gourmets", Self.count(progress.totalGourmetServed))
            row("dot.stats.golden", Self.count(progress.totalGoldenHarvested))
            row("dot.stats.fevers", Self.count(progress.totalFevers))
            row("dot.stats.tips", Self.count(progress.totalTipsCollected))
            row("dot.stats.renovation", Self.count(store.stall.renovationLevel))
            row("stats.playTime", Self.durationText(progress.totalPlaySeconds))
        }
    }

    private var legacySection: some View {
        group(String(localized: "stats.section.legacy")) {
            row("stats.prestigeCount", Self.count(progress.prestigeCount))
            row("stats.fastestRun", progress.fastestRunSeconds.map(Self.durationText) ?? Self.dash)
        }
    }

    private var settingsSection: some View {
        group(String(localized: "dot.settings.title")) {
            Button { isSoundOn.toggle() } label: {
                HStack(spacing: 8) {
                    DotImage(isSoundOn ? "dot_ui_sound_on" : "dot_ui_sound_off", scale: 2)
                    Text(String(localized: "dot.settings.sound")).dotText(.body)
                    Spacer(minLength: 0)
                    Text(isSoundOn ? String(localized: "dot.settings.on") : String(localized: "dot.settings.off"))
                        .dotText(.bold, color: isSoundOn ? DotPalette.leafDark : DotPalette.redDark)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isSoundOn ? String(localized: "dot.settings.on") : String(localized: "dot.settings.off"))
            .accessibilityAddTraits(.isToggle)
        }
    }

    // MARK: Pieces

    private func group<Content: View>(_ title: String, footer: String? = nil,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DotSectionHeader(title)
            VStack(spacing: 0, content: content)
                .dotPanel()
            if let footer { DotFootnote(footer) }
        }
    }

    /// One VoiceOver element per row: "누적 수익, 1,530,200".
    private func row(_ key: String.LocalizationValue, _ value: String) -> some View {
        let title = String(localized: key)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).dotText(.body).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Text(value).dotText(.bold).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(value)")
    }

    // MARK: Text

    static let dash = "–"

    static func count(_ value: Int) -> String { CoinFormat.string(Double(value)) }

    static func durationText(_ seconds: TimeInterval) -> String {
        StatsFormat.duration(seconds: seconds) ?? String(localized: "stats.lessThanMinute")
    }
}
