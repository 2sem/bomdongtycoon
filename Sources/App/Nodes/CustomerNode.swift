import SpriteKit

final class CustomerNode: SKNode {

    // MARK: - Constants

    private static let customerEmojis = [
        "🧑", "👩", "👨", "🧓", "👴", "👵",
        "🧑‍🍳", "👩‍💼", "👨‍💼", "🧑‍🎤", "👩‍🎓", "👨‍🎓",
        "🧒", "👧", "👦"
    ]

    private static let happyEmojis = ["🕺", "💃", "🙆‍♀️", "🙆‍♂️", "🤸‍♀️", "🤸‍♂️", "🥳", "😄", "🤩"]
    private static let sadEmojis   = ["😭", "😤", "😠", "🤦‍♀️", "🤦‍♂️", "🙅‍♀️", "🙅‍♂️", "😞", "🤬", "😡"]

    // MARK: - Properties

    /// The menu item this customer is craving.
    let wantedMenu: String

    private let thoughtBubble = SKNode()
    private let bubbleCircle:  SKShapeNode
    private let menuLabel    = SKLabelNode()
    private let reactionLabel = SKLabelNode()

    // MARK: - Init

    init(availableMenus: [String]) {
        wantedMenu   = availableMenus.randomElement() ?? "🥬"
        bubbleCircle = SKShapeNode(circleOfRadius: 18)
        super.init()
        zPosition = 5   // walk in front of stall (z=1) and counter items (z=2)
        buildBody()
        buildThoughtBubble()
        buildReactionLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Building

    private func buildBody() {
        let body = SKLabelNode(text: Self.customerEmojis.randomElement()!)
        body.fontSize = 28
        body.verticalAlignmentMode = .center
        addChild(body)
    }

    private func buildThoughtBubble() {
        // Trailing thought dots (small → big, bottom → top)
        let dots: [(CGFloat, CGFloat, CGFloat)] = [(-1, 14, 2.0), (1, 21, 3.0), (3, 28, 4.5)]
        for (x, y, r) in dots {
            let dot = SKShapeNode(circleOfRadius: r)
            dot.fillColor = .white
            dot.strokeColor = SKColor(white: 0.85, alpha: 1)
            dot.lineWidth = 0.5
            dot.position = CGPoint(x: x, y: y)
            thoughtBubble.addChild(dot)
        }

        // Main bubble circle
        bubbleCircle.fillColor = SKColor.white.withAlphaComponent(0.92)
        bubbleCircle.strokeColor = SKColor(red: 0.65, green: 0.85, blue: 0.65, alpha: 1)
        bubbleCircle.lineWidth = 1.5
        bubbleCircle.position = CGPoint(x: 2, y: 48)
        thoughtBubble.addChild(bubbleCircle)

        // Menu emoji inside bubble
        menuLabel.text = wantedMenu
        menuLabel.fontSize = 18
        menuLabel.verticalAlignmentMode = .center
        menuLabel.position = CGPoint(x: 2, y: 48)
        thoughtBubble.addChild(menuLabel)

        addChild(thoughtBubble)

        // Gentle bob
        thoughtBubble.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 0.55),
            SKAction.moveBy(x: 0, y: -3, duration: 0.55),
        ])))
    }

    private func buildReactionLabel() {
        reactionLabel.fontSize = 22
        reactionLabel.verticalAlignmentMode = .center
        reactionLabel.position = CGPoint(x: 0, y: 52)
        reactionLabel.alpha = 0
        addChild(reactionLabel)
    }

    // MARK: - Public API

    func walkTo(x: CGFloat, completion: @escaping () -> Void) {
        let duration = Double.random(in: 2.0...3.5)
        run(SKAction.moveTo(x: x, duration: duration), completion: completion)
    }

    func showReaction(happy: Bool) {
        // Stop bubble bob
        thoughtBubble.removeAllActions()

        // Burst bubble: gold for happy, red for sad
        let burstColor: SKColor = happy
            ? SKColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)
            : SKColor(red: 0.90, green: 0.20, blue: 0.15, alpha: 1)

        bubbleCircle.fillColor = burstColor
        thoughtBubble.run(SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.10),
            SKAction.fadeOut(withDuration: 0.20),
        ]))

        // Pop reaction emoji up from the bubble position
        let emoji = happy
            ? Self.happyEmojis.randomElement()!
            : Self.sadEmojis.randomElement()!

        reactionLabel.text  = emoji
        reactionLabel.alpha = 1
        reactionLabel.setScale(0.4)

        reactionLabel.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: 0.12),
                SKAction.moveBy(x: 0, y: 8, duration: 0.12),
            ]),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.wait(forDuration: 0.5),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 22, duration: 0.55),
                SKAction.fadeOut(withDuration: 0.55),
            ]),
        ]))
    }
}
