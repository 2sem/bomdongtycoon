import SpriteKit;

final class CoinBubbleNode: SKNode {

    let amount: Double;

    init(amount: Double) {
        self.amount = amount;
        super.init();

        let circle = SKShapeNode(circleOfRadius: 28);
        circle.fillColor = .systemYellow;
        circle.strokeColor = .orange;
        circle.lineWidth = 2;
        addChild(circle);

        let label = SKLabelNode(text: "💰");
        label.fontSize = 20;
        label.verticalAlignmentMode = .center;
        addChild(label);

        let float = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 0, y: 10, duration: 0.7),
                SKAction.moveBy(x: 0, y: -10, duration: 0.7),
            ])
        );
        run(float);
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported"); }

    func pop() {
        removeAllActions();
        run(SKAction.sequence([
            SKAction.scale(to: 1.5, duration: 0.1),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent(),
        ]));
    }
}
