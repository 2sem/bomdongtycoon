import SpriteKit
import GameCore

/// One per unlocked menu — shows the menu emoji, auto-cook progress bar,
/// cook tier badge, and stock count. Tap to manually cook +1 item.
final class MenuCookSlotNode: SKNode {

    static let size = CGSize(width: 58, height: 64)

    private static let barW:    CGFloat = 46
    private static let barH:    CGFloat = 6
    private static let radius:  CGFloat = 10

    // sub-nodes
    private let bg         = SKShapeNode(rectOf: size, cornerRadius: radius)
    private let menuLabel  = SKLabelNode()
    private let stockLabel = SKLabelNode()
    private let barBg      = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 3)
    private let barFill    = SKShapeNode()
    private let tierBadge  = SKLabelNode()   // tiny tier emoji top-right

    // colors
    private static let bgIdle    = SKColor(red: 0.12, green: 0.40, blue: 0.18, alpha: 1)
    private static let bgActive  = SKColor(red: 0.16, green: 0.55, blue: 0.24, alpha: 1)
    private static let barBgCol  = SKColor(white: 0, alpha: 0.30)
    private static let barFill0  = SKColor(red: 0.40, green: 0.85, blue: 0.45, alpha: 1) // no cook
    private static let barFill1  = SKColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 1) // cook assigned

    override init() {
        super.init()

        // Background
        bg.fillColor   = Self.bgIdle
        bg.strokeColor = SKColor(white: 1, alpha: 0.20)
        bg.lineWidth   = 1.5
        addChild(bg)

        // Menu emoji
        menuLabel.fontSize = 26
        menuLabel.verticalAlignmentMode   = .center
        menuLabel.horizontalAlignmentMode = .center
        menuLabel.position = CGPoint(x: 0, y: 8)
        addChild(menuLabel)

        // Stock count  ×N
        stockLabel.fontName = "AppleSDGothicNeo-Bold"
        stockLabel.fontSize = 11
        stockLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        stockLabel.verticalAlignmentMode   = .center
        stockLabel.horizontalAlignmentMode = .center
        stockLabel.position = CGPoint(x: 0, y: -10)
        addChild(stockLabel)

        // Progress bar background
        barBg.fillColor   = Self.barBgCol
        barBg.strokeColor = .clear
        barBg.position    = CGPoint(x: 0, y: -24)
        addChild(barBg)

        // Progress bar fill (left-anchored)
        barFill.fillColor   = Self.barFill0
        barFill.strokeColor = .clear
        barFill.position    = CGPoint(x: -Self.barW / 2, y: -24)
        addChild(barFill)

        // Tier badge (top-right corner)
        tierBadge.fontSize = 11
        tierBadge.verticalAlignmentMode   = .center
        tierBadge.horizontalAlignmentMode = .center
        tierBadge.position = CGPoint(x: 21, y: 26)
        addChild(tierBadge)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setup(menuEmoji: String) {
        menuLabel.text = menuEmoji
    }

    func update(cookTier: Int, progress: Double, stock: Int, maxStock: Int) {
        let hasAutoCook = cookTier > 0

        // Background tint
        bg.fillColor = hasAutoCook ? Self.bgActive : Self.bgIdle

        // Stock label
        stockLabel.text = "×\(stock)"
        let isFull = stock >= maxStock
        stockLabel.fontColor = isFull
            ? SKColor(red: 1, green: 0.80, blue: 0.30, alpha: 1)
            : SKColor(white: 1, alpha: 0.85)

        // Progress bar
        let pct    = CGFloat(max(0, min(progress, 1)))
        let fillW  = pct * Self.barW
        barFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -Self.barH / 2, width: fillW, height: Self.barH),
            cornerWidth: 3, cornerHeight: 3, transform: nil
        )
        barFill.fillColor = hasAutoCook ? Self.barFill1 : Self.barFill0

        // Tier badge
        tierBadge.text    = hasAutoCook ? tierEmoji(cookTier) : ""
        tierBadge.isHidden = !hasAutoCook
    }

    /// Brief pop animation when the player manually cooks.
    func animateCook() {
        removeAction(forKey: "cookPop")
        run(SKAction.sequence([
            SKAction.scale(to: 1.18, duration: 0.07),
            SKAction.scale(to: 1.00, duration: 0.10),
        ]), withKey: "cookPop")
    }

    private func tierEmoji(_ tier: Int) -> String {
        switch tier {
        case 1: return "👨"
        case 2: return "👩"
        case 3: return "👨‍🍳"
        default: return ""
        }
    }
}
