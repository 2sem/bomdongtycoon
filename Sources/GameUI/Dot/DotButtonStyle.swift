import SwiftUI

/// The green pixel button. `compact` draws a shorter face but keeps the 44 pt hit area.
public struct DotButtonStyle: ButtonStyle {
    let compact: Bool

    public init(compact: Bool = false) { self.compact = compact }

    public func makeBody(configuration: Configuration) -> some View {
        DotButtonBody(configuration: configuration, compact: compact)
    }
}

public extension ButtonStyle where Self == DotButtonStyle {
    static var dot: DotButtonStyle { DotButtonStyle() }
    static var dotCompact: DotButtonStyle { DotButtonStyle(compact: true) }
}

private struct DotButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let compact: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dotPlaySound) private var play

    private var artName: String {
        if !isEnabled { return "dot_ui_button_disabled" }
        return configuration.isPressed ? "dot_ui_button_pressed" : "dot_ui_button"
    }

    var body: some View {
        let px = DotTheme.px
        configuration.label
            .dotText(.bold, color: isEnabled ? DotPalette.paper : DotPalette.greyDark, shadow: isEnabled)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6 * px)
            // The art's lit face sits 1 px above centre, and 2 px lower while pressed.
            .offset(y: configuration.isPressed ? px : -px)
            .frame(minHeight: 44)
            .background {
                DotNineSlice(name: artName)
                    .padding(.vertical, compact ? 6 : 0)
            }
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed, isEnabled { play(.tap) }
            }
    }
}

/// A flat, panel-style button for secondary actions (cream face, presses down by one pixel).
public struct DotQuietButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dotText(.bold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6 * DotTheme.px)
            .frame(minHeight: 44)
            .background { DotNineSlice(name: "dot_ui_panel").padding(.vertical, 6) }
            .offset(y: configuration.isPressed ? DotTheme.px : 0)
            .contentShape(Rectangle())
    }
}

public extension ButtonStyle where Self == DotQuietButtonStyle {
    static var dotQuiet: DotQuietButtonStyle { DotQuietButtonStyle() }
}
