import SwiftUI

/// Dimmed backdrop plus one centred pixel card, for the intro screens and the welcome-back popup.
struct DotOverlay<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            DotPalette.ink.opacity(0.62).ignoresSafeArea()
            content
                .frame(maxWidth: 340)
                .dotPanel(.light, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .padding(.horizontal, 16)
        }
        .transition(.opacity)
    }
}
