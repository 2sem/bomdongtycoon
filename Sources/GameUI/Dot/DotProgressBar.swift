import SwiftUI

/// Pixel bar: `dot_ui_bar_frame` with a fill snapped to whole art pixels.
public struct DotProgressBar: View {
    public enum Tint {
        case leaf, gold
        case flat(Color)
    }

    let value: Double
    let tint: Tint

    public init(value: Double, tint: Tint = .leaf) {
        self.value = min(1, max(0, value))
        self.tint = tint
    }

    public var body: some View {
        let px = DotTheme.px
        GeometryReader { geo in
            let inner = max(0, geo.size.width - 4 * px)
            let width = value > 0 ? max(2 * px, (inner * value / px).rounded(.down) * px) : 0
            ZStack(alignment: .leading) {
                DotNineSlice(name: "dot_ui_bar_frame", caps: 3)
                if width > 0 { fill.frame(width: width, height: 4 * px).padding(.leading, 2 * px) }
            }
        }
        .frame(height: 8 * px)
    }

    @ViewBuilder
    private var fill: some View {
        switch tint {
        case .leaf: DotNineSlice(name: "dot_ui_bar_fill", caps: 1)
        case .gold: DotNineSlice(name: "dot_ui_bar_fill_gold", caps: 1)
        case .flat(let color): Rectangle().fill(color)
        }
    }
}

/// Slim 4 px bar with a flat fill, for per-row energy.
public struct DotMiniBar: View {
    let value: Double
    let color: Color

    public init(value: Double, color: Color) {
        self.value = min(1, max(0, value))
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let px = DotTheme.px
            let inner = max(0, geo.size.width - 2 * px)
            ZStack(alignment: .leading) {
                DotPalette.ink
                DotPalette.plum.padding(px)
                color.frame(width: (inner * value / px).rounded(.down) * px).padding(px)
            }
        }
        .frame(height: 6 * DotTheme.px / 2 * 2)
    }
}
