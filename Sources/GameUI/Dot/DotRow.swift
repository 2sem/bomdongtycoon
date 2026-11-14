import SwiftUI

/// Cost on a button: coin sprite plus amount.
struct DotCostLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            DotImage("dot_ui_coin", scale: 1)
            Text(text)
        }
    }
}

/// Tag chip: flat colour face with an ink outline (current location, tiers).
struct DotTag: View {
    let text: String
    var fill: Color = DotPalette.leaf
    var textColor: Color = DotPalette.paper

    var body: some View {
        Text(text)
            .dotText(.caption, color: textColor, shadow: textColor == DotPalette.paper)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(fill)
            .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: DotTheme.px) }
    }
}

/// A caption line led by a 16 pt sprite (unlock hints, locks).
struct DotHint: View {
    let icon: String
    let text: String
    var color: Color = DotPalette.textSecondary

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            DotImage(icon, scale: 1)
            Text(text).dotText(.caption, color: color).fixedSize(horizontal: false, vertical: true)
        }
    }
}
