import SpriteKit

final class CoinBubbleNode: SKNode {

    let amount: Double

    init(amount: Double) {
        self.amount = amount
        super.init()

        // Coin circle
        let circle = SKShapeNode(circleOfRadius: 30)
        circle.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1)
        circle.strokeColor = SKColor(red: 0.85, green: 0.60, blue: 0.0, alpha: 1)
        circle.lineWidth = 2.5
        addChild(circle)

        // Shine highlight
        let shine = SKShapeNode(circleOfRadius: 10)
        shine.fillColor = SKColor.white.withAlphaComponent(0.45)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 9, y: 11)
        addChild(shine)

        // ₩ label — gold, clearly money
        let icon = SKLabelNode(text: "₩")
        icon.fontName = "AppleSDGothicNeo-Bold"
        icon.fontSize = 20
        icon.fontColor = SKColor(red: 0.55, green: 0.28, blue: 0.0, alpha: 1)
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: 4)
        addChild(icon)

        // Amount label
        let amountLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        amountLabel.text = "+\(Int(amount))"
        amountLabel.fontSize = 11
        amountLabel.fontColor = SKColor(red: 0.5, green: 0.28, blue: 0.0, alpha: 1)
        amountLabel.verticalAlignmentMode = .center
        amountLabel.position = CGPoint(x: 0, y: -16)
        addChild(amountLabel)

        // Float animation
        run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 10, duration: 0.65),
            SKAction.moveBy(x: 0, y: -10, duration: 0.65),
        ])))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func pop() {
        removeAllActions()
        run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.6, duration: 0.12),
                SKAction.fadeOut(withDuration: 0.18),
            ]),
            SKAction.removeFromParent(),
        ]))
    }
}
