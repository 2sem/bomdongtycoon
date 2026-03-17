import SpriteKit
import GameCore

final class WarehouseBarNode: SKNode {

    private let width: CGFloat
    private let height: CGFloat = 50

    private let bg          = SKSpriteNode()
    private let infoLabel   = SKLabelNode()
    private let expandBtn   = SKShapeNode()
    private let expandLabel = SKLabelNode()
    private let fullLabel   = SKLabelNode()

    private var expandButtonFrame: CGRect = .zero

    init(width: CGFloat) {
        self.width = width
        super.init()

        bg.color = SKColor(red: 0.20, green: 0.12, blue: 0.04, alpha: 1)
        bg.size  = CGSize(width: width, height: height)
        addChild(bg)

        infoLabel.fontName = "AppleSDGothicNeo-Bold"
        infoLabel.fontSize = 15
        infoLabel.fontColor = .white
        infoLabel.verticalAlignmentMode = .center
        infoLabel.horizontalAlignmentMode = .left
        infoLabel.position = CGPoint(x: -width / 2 + 14, y: 0)
        addChild(infoLabel)

        let btnW: CGFloat = 90
        let btnH: CGFloat = 30
        expandBtn.path = CGPath(roundedRect: CGRect(x: -btnW/2, y: -btnH/2, width: btnW, height: btnH),
                                cornerWidth: 15, cornerHeight: 15, transform: nil)
        expandBtn.fillColor   = SKColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
        expandBtn.strokeColor = SKColor(red: 0.10, green: 0.35, blue: 0.75, alpha: 1)
        expandBtn.lineWidth   = 1.5
        expandBtn.position    = CGPoint(x: width / 2 - 56, y: 0)
        addChild(expandBtn)
        expandButtonFrame = CGRect(x: expandBtn.position.x - btnW/2,
                                   y: -btnH/2,
                                   width: btnW, height: btnH)

        expandLabel.fontName = "AppleSDGothicNeo-Bold"
        expandLabel.fontSize = 12
        expandLabel.fontColor = .white
        expandLabel.verticalAlignmentMode = .center
        expandLabel.horizontalAlignmentMode = .center
        expandLabel.position = expandBtn.position
        addChild(expandLabel)

        fullLabel.fontName = "AppleSDGothicNeo-Bold"
        fullLabel.fontSize = 13
        fullLabel.fontColor = SKColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
        fullLabel.verticalAlignmentMode = .center
        fullLabel.horizontalAlignmentMode = .center
        fullLabel.isHidden = true
        addChild(fullLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(warehouse: Int, capacity: Int, expandCost: Double?, canAfford: Bool) {
        let isFull = warehouse >= capacity
        infoLabel.text = "🥬 창고 \(warehouse)/\(capacity)"

        if isFull {
            fullLabel.text = "⚠️ 가득 — 요리하세요!"
            fullLabel.isHidden = false
            fullLabel.position = CGPoint(x: width / 2 - 130, y: 0)
        } else {
            fullLabel.isHidden = true
        }

        if let cost = expandCost {
            expandBtn.isHidden   = false
            expandLabel.isHidden = false
            expandLabel.text     = "확장 ₩\(Int(cost))"
            expandBtn.fillColor  = canAfford
                ? SKColor(red: 0.20, green: 0.55, blue: 0.95, alpha: 1)
                : SKColor(red: 0.40, green: 0.40, blue: 0.40, alpha: 1)
        } else {
            expandBtn.isHidden   = true
            expandLabel.isHidden = true
        }
    }

    func expandButtonContains(_ point: CGPoint) -> Bool {
        expandButtonFrame.contains(point)
    }
}
