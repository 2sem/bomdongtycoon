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
}
