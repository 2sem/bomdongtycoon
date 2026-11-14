import SpriteKit
import UIKit

/// Text drawn with the bundled pixel font so each glyph pixel is exactly one art pixel.
/// The label lives in the scaled world but is counter-scaled, so SpriteKit rasterises it at the
/// final point size instead of stretching a small bitmap.
@MainActor
final class PixelLabel: SKNode {

    enum Style {
        /// Galmuri9, 10 px em.
        case small
        /// Galmuri11-Bold, 12 px em.
        case bold

        var fontName: String { self == .small ? "Galmuri9-Regular" : "Galmuri11-Bold" }
        var em: CGFloat { self == .small ? 10 : 12 }
    }

    enum Alignment { case left, center, right }

    private let main = SKLabelNode()
    private let shadow = SKLabelNode()
    private let artScale: CGFloat
    private let alignment: Alignment

    var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            main.text = text
            shadow.text = text
            realign()
        }
    }

    init(style: Style, scale: CGFloat, color: SKColor = SKColor(hex: 0xfffaf0),
         shadowColor: SKColor? = SKColor(hex: 0x2b1b2e), alignment: Alignment = .center) {
        artScale = scale
        self.alignment = alignment
        super.init()
        setScale(1 / scale)
        for label in [shadow, main] {
            label.fontName = style.fontName
            label.fontSize = style.em * scale
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .baseline
        }
        main.fontColor = color
        shadow.fontColor = shadowColor ?? .clear
        shadow.position = CGPoint(x: scale, y: -scale)
        shadow.isHidden = shadowColor == nil
        addChild(shadow)
        addChild(main)
        main.zPosition = 0.1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var color: SKColor {
        get { main.fontColor ?? .white }
        set { main.fontColor = newValue }
    }

    /// Whole art pixels, so the origin never lands between two device pixels.
    private func realign() {
        let width = (main.frame.width / artScale).rounded()
        let shift: CGFloat
        switch alignment {
        case .left:   shift = 0
        case .center: shift = -(width / 2).rounded(.down)
        case .right:  shift = -width
        }
        main.position.x = shift * artScale
        shadow.position.x = (shift + 1) * artScale
    }
}
