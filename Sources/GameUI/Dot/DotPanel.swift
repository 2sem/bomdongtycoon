import SwiftUI

public enum DotPanelStyle {
    case light, dark

    var sourceName: String { self == .light ? "dot_ui_panel" : "dot_ui_panel_dark" }
    public var textColor: Color { self == .light ? DotPalette.ink : DotPalette.paper }
}

public extension View {
    /// Wraps the view in a 9-slice pixel panel. The art border is 3 px; `padding` is the inside gap.
    func dotPanel(_ style: DotPanelStyle = .light, padding: EdgeInsets = DotTheme.panelPadding) -> some View {
        self.padding(padding)
            .background { DotNineSlice(name: style.sourceName) }
    }
}

extension DotTheme {
    public static let panelPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
}

/// A panel as a container, for the common "titled card" case.
public struct DotPanel<Content: View>: View {
    let style: DotPanelStyle
    let content: Content

    public init(_ style: DotPanelStyle = .light, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    public var body: some View {
        content
            .foregroundStyle(style.textColor)
            .dotPanel(style)
    }
}
