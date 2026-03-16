import SpriteKit

final class CustomerNode: SKNode {

    private static let emojis = [
        "🧑", "👩", "👨", "🧓", "👴", "👵",
        "🧑‍🍳", "👩‍💼", "👨‍💼", "🧑‍🎤", "👩‍🎓", "👨‍🎓",
        "🧒", "👧", "👦"
    ]

    override init() {
        super.init()
        let emoji = Self.emojis.randomElement()!
        let sprite = SKLabelNode(text: emoji)
        sprite.fontSize = 28
        sprite.verticalAlignmentMode = .center
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func walkTo(x: CGFloat, completion: @escaping () -> Void) {
        let duration = Double.random(in: 2.0...3.5)
        run(SKAction.moveTo(x: x, duration: duration), completion: completion)
    }

    func showReaction(_ emoji: String) {
        let label = SKLabelNode(text: emoji)
        label.fontSize = 24
        label.position = CGPoint(x: 0, y: 44)
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 22, duration: 0.9),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.55),
                    SKAction.fadeOut(withDuration: 0.35),
                ]),
            ]),
            SKAction.removeFromParent(),
        ]))
    }
}
