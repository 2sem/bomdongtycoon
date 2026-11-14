import SpriteKit
import UIKit

/// Text drawn with the bundled pixel fonts. The string is rasterised once into a bitmap at 1 art
/// pixel per bitmap pixel, without anti-aliasing, and shown with nearest-neighbour filtering, so
/// glyph pixels land exactly on art pixels at whatever scale the world is drawn.
@MainActor
final class PixelLabel: SKNode {

    enum Style {
        /// Galmuri7, 8 px em: stock counts and other numerals that sit on a 12 px counter front.
        case tiny
        /// Galmuri9, 10 px em.
        case small
        /// Galmuri11-Bold, 12 px em.
        case bold

        var fontName: String {
            switch self {
            case .tiny: "Galmuri7-Regular"
            case .small: "Galmuri9-Regular"
            case .bold: "Galmuri11-Bold"
            }
        }
        var em: CGFloat {
            switch self {
            case .tiny: 8
            case .small: 10
            case .bold: 12
            }
        }
    }

    enum Alignment { case left, center, right }

    private let sprite = SKSpriteNode()
    private let style: Style
    private let alignment: Alignment
    private let shadowColor: SKColor?

    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            render()
        }
    }

    var color: SKColor {
        didSet { render() }
    }

    /// `scale` is accepted for call-site compatibility; the bitmap is 1:1 with art pixels.
    init(style: Style, scale: CGFloat = 1, color: SKColor = SKColor(hex: 0xfffaf0),
         shadowColor: SKColor? = SKColor(hex: 0x2b1b2e), alignment: Alignment = .center) {
        self.style = style
        self.alignment = alignment
        self.color = color
        self.shadowColor = shadowColor
        super.init()
        sprite.anchorPoint = .zero
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func render() {
        guard !text.isEmpty, let font = UIFont(name: style.fontName, size: style.em) else {
            sprite.texture = nil
            return
        }
        let size = (text as NSString).size(withAttributes: [.font: font])
        let width = Int(ceil(size.width)) + 1
        let height = Int(ceil(font.lineHeight)) + 1
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            ctx.cgContext.setShouldAntialias(false)
            ctx.cgContext.setShouldSmoothFonts(false)
            if let shadowColor {
                (text as NSString).draw(at: CGPoint(x: 1, y: 1),
                                        withAttributes: [.font: font, .foregroundColor: shadowColor])
            }
            (text as NSString).draw(at: .zero, withAttributes: [.font: font, .foregroundColor: color])
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        sprite.texture = texture
        sprite.size = CGSize(width: width, height: height)

        // The node origin is the baseline's left end (art px); the baseline is `ascender` below the bitmap top.
        let drop = (font.ascender).rounded()
        let shift: CGFloat
        switch alignment {
        case .left:   shift = 0
        case .center: shift = -(CGFloat(width - 1) / 2).rounded(.down)
        case .right:  shift = -CGFloat(width - 1)
        }
        sprite.position = CGPoint(x: shift, y: -(CGFloat(height) - drop))
    }
}
