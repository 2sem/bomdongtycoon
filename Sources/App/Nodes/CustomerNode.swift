import SpriteKit

final class CustomerNode: SKNode {

    private static let customerEmojis = [
        "🧑", "👩", "👨", "🧓", "👴", "👵",
        "🧑‍🍳", "👩‍💼", "👨‍💼", "🧑‍🎤", "👩‍🎓", "👨‍🎓",
        "🧒", "👧", "👦"
    ]

    private static let desireEmojis = ["💕", "🥬", "💚", "🌿", "🤩"]

    private static let happyEmojis  = ["🕺", "💃", "🙆‍♀️", "🙆‍♂️", "🤸‍♀️", "🤸‍♂️", "🥳"]
    private static let sadEmojis    = ["🤦‍♀️", "🤦‍♂️", "🙅‍♀️", "🙅‍♂️", "😭"]

    private let emotionLabel = SKLabelNode()

    override init() {
        super.init()

        // Customer body
        let body = SKLabelNode(text: Self.customerEmojis.randomElement()!)
        body.fontSize = 28
        body.verticalAlignmentMode = .center
        body.name = "body"
        addChild(body)

        // Emotion bubble — always visible above head
        emotionLabel.text = Self.desireEmojis.randomElement()!
        emotionLabel.fontSize = 16
        emotionLabel.verticalAlignmentMode = .center
        emotionLabel.position = CGPoint(x: 0, y: 36)
        addChild(emotionLabel)

        // Gentle bob on the emotion only
        emotionLabel.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 4, duration: 0.5),
            SKAction.moveBy(x: 0, y: -4, duration: 0.5),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func walkTo(x: CGFloat, completion: @escaping () -> Void) {
        let duration = Double.random(in: 2.0...3.5)
        run(SKAction.moveTo(x: x, duration: duration), completion: completion)
    }

    func showReaction(happy: Bool) {
        let emoji = happy
            ? Self.happyEmojis.randomElement()!
            : Self.sadEmojis.randomElement()!

        emotionLabel.removeAllActions()
        emotionLabel.run(SKAction.sequence([
            SKAction.group([
                SKAction.sequence([
                    SKAction.scale(to: 1.6, duration: 0.12),
                    SKAction.scale(to: 1.0, duration: 0.1),
                ]),
                SKAction.run { [weak self] in self?.emotionLabel.text = emoji },
            ]),
            // Float upward and fade after a moment
            SKAction.wait(forDuration: 0.4),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 18, duration: 0.7),
                SKAction.sequence([
                    SKAction.wait(forDuration: 0.3),
                    SKAction.fadeOut(withDuration: 0.4),
                ]),
            ]),
        ]))
    }
}
