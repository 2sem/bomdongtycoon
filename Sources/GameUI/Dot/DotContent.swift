import Foundation
import GameCore

/// Game content (menu, shop and staff names, descriptions) lives in `GameCore` as Korean source
/// text. The catalog holds an English entry keyed by that exact Korean string, so a runtime
/// lookup translates it without touching the economy code.
enum DotContent {
    static func loc(_ source: String) -> String {
        String(localized: String.LocalizationValue(source))
    }

    /// "판매가 ×2.5 · 보관 30개", built from the numbers so it localizes cleanly.
    static func effect(for upgrade: UpgradeDefinition) -> String {
        var parts: [String] = []
        if upgrade.priceMultiplier != 1 {
            parts.append(String(format: String(localized: "dot.effect.price"),
                                String(format: "%.1f", upgrade.priceMultiplier)))
        }
        if upgrade.maxStock > 0 {
            parts.append(String(format: String(localized: "dot.effect.stock"), upgrade.maxStock))
        }
        return parts.joined(separator: " · ")
    }

    static func effect(for location: LocationDefinition) -> String {
        String(format: String(localized: "dot.effect.sales"), Int(location.saleMultiplier))
    }

    /// The emoji the model strings still carry never render in the pixel font.
    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "💰 ", with: "")
            .replacingOccurrences(of: "🥬 ", with: "")
            .replacingOccurrences(of: "🔓 ", with: "")
            .replacingOccurrences(of: "🔒 ", with: "")
    }
}
