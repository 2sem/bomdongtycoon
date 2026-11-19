import Foundation

/// Display-only 1...5 star count in half-star steps for a single customer. It is derived from the same wait time the
/// shop rating uses and never feeds back into the rating, saves or balance.
public enum CustomerStars {

    /// Same cutoff as `GameStore.recordServed`, so "5 stars" means exactly "counted as a fast serve".
    public static let fastServeSeconds: TimeInterval = 3.0

    public static func stars(waited: TimeInterval, patience: TimeInterval, isGourmet: Bool, served: Bool) -> Double {
        guard served else { return 1 }
        let base: Double
        if waited < fastServeSeconds {
            base = 5
        } else if waited < patience * 0.4 {
            base = 4.5
        } else if waited < patience * 0.6 {
            base = 4
        } else if waited < patience * 0.8 {
            base = 3.5
        } else {
            base = 3
        }
        return min(5, base + (isGourmet ? 1 : 0))
    }

    /// "4", "4.5": whole stars carry no decimal.
    public static func label(_ stars: Double) -> String {
        stars == stars.rounded() ? String(Int(stars)) : String(format: "%.1f", stars)
    }
}
