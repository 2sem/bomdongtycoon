import SpriteKit
import UIKit
import GameCore

/// The three first-time actions the pointer teaches. Done-flags live in UserDefaults, not the save,
/// so a prestige or a restored save never replays them.
enum FirstRunHint: String, CaseIterable {
    case harvest, plant, cook

    private var key: String { "dot.hint.done.\(rawValue)" }
    var isDone: Bool { UserDefaults.standard.bool(forKey: key) }
    func markDone() { UserDefaults.standard.set(true, forKey: key) }

    /// DEBUG `-dotResetHints` replays them on a seeded save.
    static func resetForDebug() {
        for hint in allCases { UserDefaults.standard.removeObject(forKey: hint.key) }
    }
}

/// A small procedural pixel arrow that bobs over what to tap next; static under Reduce Motion.
@MainActor
final class HintArrowNode: SKNode {

    private static let rows = [
        ".#######.",
        "#ggggggg#",
        "#ggggggg#",
        ".#ggggg#.",
        "..#ggg#..",
        "...#g#...",
        "....#....",
    ]

    private static let texture: SKTexture = {
        let ink = UIColor(red: 0x2b / 255, green: 0x1b / 255, blue: 0x2e / 255, alpha: 1)
        let gold = UIColor(red: 0xf4 / 255, green: 0xb9 / 255, blue: 0x3a / 255, alpha: 1)
        let size = CGSize(width: 9, height: rows.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() where c != "." {
                    (c == "#" ? ink : gold).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    private let bob = SKNode()

    override init() {
        super.init()
        let sprite = SKSpriteNode(texture: Self.texture)
        sprite.size = Self.texture.size()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        bob.addChild(sprite)
        addChild(bob)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// `tip` is where the arrow's point lands, in root space; nil hides it.
    func show(tip: CGPoint?, animated: Bool) {
        guard let tip else {
            isHidden = true
            bob.removeAllActions()
            return
        }
        isHidden = false
        position = CGPoint(x: tip.x.rounded(.down) + 0.5, y: tip.y.rounded())
        if animated {
            guard bob.action(forKey: "bob") == nil else { return }
            bob.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.3), .wait(forDuration: 0.15),
                                              .moveBy(x: 0, y: -2, duration: 0.3), .wait(forDuration: 0.15)])),
                    withKey: "bob")
        } else {
            bob.removeAllActions()
            bob.position = .zero
        }
    }
}
