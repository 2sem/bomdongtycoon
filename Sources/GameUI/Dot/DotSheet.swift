import SwiftUI

/// Chrome shared by every sheet: plum title bar with a close button over a sand board that the
/// content lays cream panels on.
public struct DotSheet<Content: View>: View {
    let title: String
    let onClose: () -> Void
    let content: Content

    public init(title: String, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DotPalette.sand)
        }
        .background(DotPalette.plum)
        .dotSheetPresentation()
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(title)
                .dotText(.title, color: DotPalette.paper, shadow: true)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: onClose) { Text(String(localized: "닫기")) }
                .buttonStyle(.dotCompact)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 2)
        .background(alignment: .bottom) {
            // Two-pixel ink rule with a mauve highlight above it.
            VStack(spacing: 0) {
                DotPalette.mauve.frame(height: DotTheme.px)
                DotPalette.ink.frame(height: DotTheme.px)
            }
        }
    }
}

public extension View {
    func dotSheetPresentation() -> some View {
        self.presentationCornerRadius(0)
            .presentationDragIndicator(.hidden)
            .presentationBackground(DotPalette.plum)
    }
}

// MARK: - Section helpers

/// Section title on the sand board: bold ink text with a pixel rule.
public struct DotSectionHeader: View {
    let title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dotText(.bold, color: DotPalette.soilDark)
                .accessibilityAddTraits(.isHeader)
            DotPalette.soilLight.frame(height: DotTheme.px)
        }
        .padding(.top, 6)
    }
}

/// Footnote under a section.
public struct DotFootnote: View {
    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .dotText(.caption, color: DotPalette.soilDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Scrolling stack for sheet bodies.
public struct DotScroll<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) { content }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }
}
