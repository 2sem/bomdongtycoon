import SwiftUI

/// The dark pixel plate used for every short notice that drops in from the top.
public struct DotToast: View {
    let text: String

    public init(text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .dotText(.bold, color: DotPalette.paper, shadow: true)
            .multilineTextAlignment(.center)
            .dotPanel(.dark, padding: EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            .accessibilityHidden(true) // announced separately on appearance
    }
}
