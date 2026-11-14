import SwiftUI

/// A small square counter badge (unclaimed missions, mostly): red face, ink outline, notched corners.
public struct DotBadge: View {
    let text: String

    public init(_ count: Int) { text = count > 9 ? "9+" : "\(count)" }

    public var body: some View {
        let px = DotTheme.px
        Text(text)
            .dotText(.caption, color: DotPalette.paper)
            .padding(.horizontal, 2 * px)
            .frame(minWidth: 9 * px, minHeight: 9 * px)
            .background(DotPalette.red)
            .overlay { Rectangle().strokeBorder(DotPalette.ink, lineWidth: px) }
            .clipShape(DotNotch())
            .accessibilityHidden(true)
    }
}

/// Rectangle with its four corner pixels removed.
struct DotNotch: Shape {
    func path(in rect: CGRect) -> Path {
        let c = DotTheme.px
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}
