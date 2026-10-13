import SwiftUI
import GameCore

/// "기록": this run, lifetime totals and, after a first spring, the legacy. Read-only.
public struct StatsSheet: View {
    @EnvironmentObject var store: GameStore
    @Binding public var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private var progress: PlayerProgress { store.progress }
    private var hasLegacy: Bool { progress.prestigeCount > 0 }
    private var hasNoRecord: Bool { progress.totalServed == 0 && progress.totalFailed == 0 }

    public var body: some View {
        NavigationStack {
            List {
                if hasLegacy { Section { header } }
                runSection
                lifetimeSection
                if hasLegacy { legacySection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "stats.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "닫기")) { isPresented = false }
                }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        let n = progress.prestigeCount
        let multiplier = PrestigeSystem.multiplierText(prestigeCount: n)
        let plain = PrestigeSystem.multiplierNumber(PrestigeSystem.legacyMultiplier(prestigeCount: n))
        return Text(String(format: String(localized: "stats.header"), multiplier, n))
            .font(.headline)
            .monospacedDigit()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: String(localized: "stats.header.accessibility"), plain, n))
    }

    private var runSection: some View {
        Section(String(localized: "stats.section.run")) {
            row("stats.run.duration", Self.durationText(progress.runPlaySeconds))
            row("stats.run.earned", CoinFormat.string(progress.runEarned))
            row("stats.run.served", Self.count(progress.runServed))
        }
    }

    private var lifetimeSection: some View {
        Section {
            row("stats.earned", CoinFormat.string(progress.totalEarned))
            row("stats.served", Self.count(progress.totalServed))
            row("stats.failed", Self.count(progress.totalFailed))
            row("stats.successRate", StatsFormat.successRate(served: progress.totalServed, failed: progress.totalFailed) ?? Self.dash)
            row("stats.bestRating", hasNoRecord && progress.bestRating == 0
                ? Self.dash : String(format: "★%.1f", progress.highestRating))
            row("stats.playTime", Self.durationText(progress.totalPlaySeconds))
        } header: {
            Text(String(localized: "stats.section.lifetime"))
        } footer: {
            if hasNoRecord { Text(String(localized: "stats.empty")) }
        }
    }

    private var legacySection: some View {
        Section(String(localized: "stats.section.legacy")) {
            row("stats.prestigeCount", Self.count(progress.prestigeCount))
            row("stats.fastestRun", progress.fastestRunSeconds.map(Self.durationText) ?? Self.dash)
        }
    }

    /// One VoiceOver element per row: "누적 수익, 1,530,200".
    private func row(_ key: String.LocalizationValue, _ value: String) -> some View {
        let title = String(localized: key)
        return LabeledContent {
            Text(value).monospacedDigit()
        } label: {
            Text(title)
        }
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
