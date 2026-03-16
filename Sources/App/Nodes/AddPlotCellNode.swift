import SpriteKit

/// A farm-cell-sized node shown after the last plot.
/// Tapping it purchases the next plot expansion.
final class AddPlotCellNode: SKNode {

    private let bg: SKShapeNode
    private let plusLabel  = SKLabelNode()
    private let costLabel  = SKLabelNode()

    override init() {
        bg = SKShapeNode(rectOf: FarmPlotNode.size, cornerRadius: 10)
        super.init()

        bg.strokeColor = SKColor(white: 1.0, alpha: 0.35)
        bg.lineWidth = 2
        bg.fillColor = SKColor(white: 1.0, alpha: 0.10)
        addChild(bg)

        plusLabel.text = "+"
        plusLabel.fontName = "AppleSDGothicNeo-Bold"
        plusLabel.fontSize = 24
        plusLabel.verticalAlignmentMode = .center
        plusLabel.position = CGPoint(x: 0, y: 6)
        addChild(plusLabel)

        costLabel.fontName = "AppleSDGothicNeo-Regular"
        costLabel.fontSize = 10
        costLabel.verticalAlignmentMode = .center
        costLabel.position = CGPoint(x: 0, y: -12)
        addChild(costLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(cost: Double, canAfford: Bool) {
        let color: SKColor = canAfford
            ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
            : SKColor(white: 1.0, alpha: 0.40)
        plusLabel.fontColor = color
        costLabel.fontColor = color
        costLabel.text = "₩\(Int(cost))"
        bg.strokeColor = canAfford
            ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.6)
            : SKColor(white: 1.0, alpha: 0.25)
    }
}
