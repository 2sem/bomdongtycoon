import SpriteKit;

final class CustomerNode: SKNode {

    override init() {
        super.init();
        let sprite = SKLabelNode(text: "🧑");
        sprite.fontSize = 28;
        sprite.verticalAlignmentMode = .center;
        addChild(sprite);
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported"); }

    func walkTo(x: CGFloat, completion: @escaping () -> Void) {
        run(SKAction.moveTo(x: x, duration: 2.5), completion: completion);
    }
}
