import SpriteKit

/// Sky fill and world multiply tint for a point in the 4-minute day loop.
/// Keys sit at the start of each phase, so a new game opens on a full morning and each phase
/// blends into the next over its own quarter of the loop.
struct DayLook {
    let sky: SKColor
    let tint: SKColor

    private static let keys: [(sky: UInt32, tint: UInt32)] = [
        (0xffe2b8, 0xfff2dc),   // morning
        (0xa9e1f6, 0xffffff),   // noon
        (0xf6a878, 0xffc9a8),   // dusk
        (0x262a52, 0x8d93c9),   // night
    ]

    /// `progress` is `DayCycle.progress`, 0..<1.
    static func at(progress: Double) -> DayLook {
        let position = progress * 4
        let base = position.rounded(.down)
        let f = CGFloat(position - base)
        let eased = f * f * (3 - 2 * f)
        let i = ((Int(base) % 4) + 4) % 4
        let a = keys[i]
        let b = keys[(i + 1) % 4]
        return DayLook(sky: SKColor(hex: a.sky).mixed(with: SKColor(hex: b.sky), eased),
                       tint: SKColor(hex: a.tint).mixed(with: SKColor(hex: b.tint), eased))
    }

    /// 0 in daylight, 1 deep in the night; drives the stars.
    static func starAlpha(progress p: Double) -> CGFloat {
        guard p >= 0.68 else { return 0 }
        return CGFloat(min(1, (p - 0.68) / 0.1) * min(1, (1 - p) / 0.1))
    }

    /// Sun arc parameter 0...1 across daylight, nil while it is below the horizon.
    static func sunArc(progress p: Double) -> CGFloat? {
        let t = (p - 0.02) / 0.62
        return (0...1).contains(t) ? CGFloat(t) : nil
    }

    static func moonArc(progress p: Double) -> CGFloat? {
        let shifted = p < 0.3 ? p + 1 : p
        let t = (shifted - 0.62) / 0.4
        return (0...1).contains(t) ? CGFloat(t) : nil
    }
}
