import SpriteKit
import UIKit

/// The 선물 상자 that drops into the yard: a gold box with a red ribbon, drawn from a pixel grid
/// until the artist delivers `dot_fx_gift_box` (14x13, gold box, red ribbon, ink outline).
@MainActor
final class GiftNode: SKNode {

    private static let rows = [
        "...###..###...",
        "..#rrr##rrr#..",
        "..#rrrrrrrr#..",
        "...##rrrr##...",
        "##############",
        "#lllllrrlllll#",
        "#gggggrrggggg#",
        "##############",
        "#gggggrrggggg#",
        "#gggggrrggggg#",
        "#ggGggrrggGgg#",
        "#GGGGGrrGGGGG#",
        "##############",
    ]

    private static let texture: SKTexture = {
        func color(_ hex: UInt32) -> UIColor {
            UIColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                    blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        }
        let palette: [Character: UIColor] = [
            "#": color(0x2b1b2e), "g": color(0xf4b93a), "G": color(0xc47a22),
            "l": color(0xffe680), "r": color(0xd94a40),
        ]
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: rows[0].count, height: rows.count)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() {
                    guard let fill = palette[c] else { continue }
                    fill.setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    private let bob = SKNode()
    private var isShown = false

    override init() {
        super.init()
        let shadow = dotSprite("dot_fx_shadow")
        shadow.alpha = 0.6
        addChild(shadow)
        let body = SKSpriteNode(texture: Self.texture)
        body.size = Self.texture.size()
        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.position = CGPoint(x: 0, y: 1)
        bob.addChild(body)
        addChild(bob)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Drops in from above with a bounce, then bobs one pixel; under Reduce Motion it just appears.
    func appear(reduceMotion: Bool) {
        guard !isShown else { return }
        isShown = true
        isHidden = false
        alpha = 1
        bob.removeAllActions()
        guard !reduceMotion else { bob.position = .zero; return }
        bob.position = CGPoint(x: 0, y: 48)
        let fall = SKAction.moveTo(y: 0, duration: 0.35)
        fall.timingMode = .easeIn
        let bounce = SKAction.sequence([.moveTo(y: 5, duration: 0.12), .moveTo(y: 0, duration: 0.12)])
        let hover = SKAction.repeatForever(.sequence([.moveTo(y: 2, duration: 0.45), .moveTo(y: 0, duration: 0.45)]))
        bob.run(.sequence([fall, bounce, hover]))
    }

    func disappear() {
        guard isShown else { return }
        isShown = false
        isHidden = true
        bob.removeAllActions()
    }

    /// The last seconds blink so a crate about to leave is noticed.
    func setRemaining(_ seconds: Double, reduceMotion: Bool) {
        guard isShown else { return }
        if seconds <= 6, !reduceMotion {
            alpha = Int(seconds * 4) % 2 == 0 ? 1 : 0.45
        } else {
            alpha = 1
        }
    }
}
