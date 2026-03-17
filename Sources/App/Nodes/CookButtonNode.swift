import SpriteKit
import GameCore

final class CookButtonNode: SKNode {

    private let bg          = SKShapeNode()
    private let emojisLabel = SKLabelNode()
    private let countLabel  = SKLabelNode()

    override init() {
        super.init()

        let w: CGFloat = 110
        let h: CGFloat = 50
        bg.path = CGPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h),
                         cornerWidth: 14, cornerHeight: 14, transform: nil)
        bg.fillColor   = SKColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1)
        bg.strokeColor = SKColor(red: 0.10, green: 0.38, blue: 0.18, alpha: 1)
        bg.lineWidth   = 2
        addChild(bg)

        emojisLabel.fontSize = 16
        emojisLabel.verticalAlignmentMode  = .center
        emojisLabel.horizontalAlignmentMode = .center
        emojisLabel.position = CGPoint(x: 0, y: 10)
        addChild(emojisLabel)

        countLabel.fontName = "AppleSDGothicNeo-Bold"
        countLabel.fontSize = 12
        countLabel.fontColor = SKColor(white: 1.0, alpha: 0.90)
        countLabel.verticalAlignmentMode  = .center
        countLabel.horizontalAlignmentMode = .center
        countLabel.position = CGPoint(x: 0, y: -12)
        addChild(countLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Update button for menus that need manual cooking (no dedicated cook assigned).
    /// Pass an empty array to hide the button entirely.
    func update(manualMenuEmojis: [String], canCook: Bool) {
        isHidden = manualMenuEmojis.isEmpty
        guard !manualMenuEmojis.isEmpty else { return }
        emojisLabel.text = manualMenuEmojis.joined()
        countLabel.text  = "수동 조리 ×1"
        alpha = canCook ? 1.0 : 0.45
    }
}
