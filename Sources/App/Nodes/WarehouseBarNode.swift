import SpriteKit
import GameCore

// Two-cell warehouse display: [warehouse cell] [expand cell]
// Matches farm cell visual language (62×62pt, same corner radius, same spacing)
final class WarehouseNode: SKNode {

    // MARK: - Layout
    private static let cellSize   = CGSize(width: 62, height: 62)
    private static let radius:  CGFloat = 10
    private static let barW:    CGFloat = 52
    private static let barH:    CGFloat = 6
    private static let spacing: CGFloat = 68   // matches farmSpacingX

    // MARK: - Colors
    private static let normalBg   = SKColor(red: 0.24, green: 0.16, blue: 0.06, alpha: 1)
    private static let fullBg     = SKColor(red: 0.48, green: 0.18, blue: 0.04, alpha: 1)
    private static let normalBorder = SKColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 1)
    private static let fullBorder   = SKColor(red: 0.90, green: 0.45, blue: 0.10, alpha: 1)
    private static let barBgColor = SKColor(white: 0, alpha: 0.30)
    private static let barFillColor = SKColor(red: 0.28, green: 0.72, blue: 0.95, alpha: 1)

    // MARK: - Warehouse cell nodes
    private let cellBg        = SKShapeNode(rectOf: cellSize, cornerRadius: radius)
    private let iconLabel     = SKLabelNode()
    private let stockLabel    = SKLabelNode()
    private let fillBarBg     = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 3)
    private let fillBarFill   = SKShapeNode()
    private let warningCircle = SKShapeNode(circleOfRadius: 9)
    private let warningLabel  = SKLabelNode()

    // MARK: - Expand cell nodes
    private let expandBg      = SKShapeNode(rectOf: cellSize, cornerRadius: radius)
    private let expandTitle   = SKLabelNode()
    private let expandIcon    = SKLabelNode()
    private let expandCost    = SKLabelNode()

    // MARK: - State
    private var wasFull = false
    private var lastCanAfford = false

    // Expose for hit-testing in MainStallScene
    var warehouseCellContains: ((CGPoint) -> Bool) { { [weak self] pt in self?.cellBg.contains(pt) ?? false } }

    override init() {
        super.init()
        buildWarehouseCell()
        buildExpandCell()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildWarehouseCell() {
        // Background
        cellBg.fillColor   = Self.normalBg
        cellBg.strokeColor = Self.normalBorder
        cellBg.lineWidth   = 2
        cellBg.position    = CGPoint(x: -Self.spacing / 2, y: 0)
        addChild(cellBg)

        // Warehouse icon — small, top of cell
        iconLabel.text     = "📦"
        iconLabel.fontSize = 18
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -Self.spacing / 2, y: 20)
        addChild(iconLabel)

        // Fill bar background — bottom of cell
        fillBarBg.fillColor   = Self.barBgColor
        fillBarBg.strokeColor = .clear
        fillBarBg.position    = CGPoint(x: -Self.spacing / 2, y: -22)
        addChild(fillBarBg)

        // Fill bar fill (anchored at left edge of bar)
        fillBarFill.fillColor   = Self.barFillColor
        fillBarFill.strokeColor = .clear
        fillBarFill.position    = CGPoint(x: -Self.spacing / 2 - Self.barW / 2, y: -22)
        addChild(fillBarFill)

        // Stock label "×N"
        // Stock count — hero text in the center of the cell
        stockLabel.fontName = "AppleSDGothicNeo-Bold"
        stockLabel.fontSize = 18
        stockLabel.fontColor = .white
        stockLabel.verticalAlignmentMode   = .center
        stockLabel.horizontalAlignmentMode = .center
        stockLabel.position = CGPoint(x: -Self.spacing / 2, y: -2)
        addChild(stockLabel)

        // Warning circle (hidden initially)
        warningCircle.fillColor   = SKColor(red: 0.95, green: 0.40, blue: 0.05, alpha: 1)
        warningCircle.strokeColor = .clear
        warningCircle.position    = CGPoint(x: -Self.spacing / 2 + 22, y: 22)
        warningCircle.isHidden    = true
        addChild(warningCircle)

        // Warning "!" label
        warningLabel.text     = "!"
        warningLabel.fontName = "AppleSDGothicNeo-Bold"
        warningLabel.fontSize = 13
        warningLabel.fontColor = .white
        warningLabel.verticalAlignmentMode   = .center
        warningLabel.horizontalAlignmentMode = .center
        warningLabel.position = warningCircle.position
        warningLabel.isHidden = true
        addChild(warningLabel)
    }

    private func buildExpandCell() {
        expandBg.fillColor   = SKColor(red: 0.24, green: 0.16, blue: 0.06, alpha: 1)
        expandBg.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        expandBg.lineWidth   = 2
        expandBg.position    = CGPoint(x: Self.spacing / 2, y: 0)
        addChild(expandBg)

        expandTitle.text     = "창고 추가"
        expandTitle.fontName = "AppleSDGothicNeo-Bold"
        expandTitle.fontSize = 11
        expandTitle.verticalAlignmentMode = .center
        expandTitle.position = CGPoint(x: Self.spacing / 2, y: 18)
        addChild(expandTitle)

        expandIcon.text     = "+"
        expandIcon.fontName = "AppleSDGothicNeo-Bold"
        expandIcon.fontSize = 22
        expandIcon.verticalAlignmentMode   = .center
        expandIcon.horizontalAlignmentMode = .center
        expandIcon.position = CGPoint(x: Self.spacing / 2, y: 2)
        addChild(expandIcon)

        expandCost.fontName = "AppleSDGothicNeo-Bold"
        expandCost.fontSize = 13
        expandCost.verticalAlignmentMode   = .center
        expandCost.horizontalAlignmentMode = .center
        expandCost.position = CGPoint(x: Self.spacing / 2, y: -16)
        addChild(expandCost)
    }

    // MARK: - Update

    func update(warehouse: Int, capacity: Int, expandCostValue: Double?, canAfford: Bool) {
        let isFull = warehouse >= capacity

        // Fill bar
        let pct = capacity > 0 ? CGFloat(warehouse) / CGFloat(capacity) : 0
        let fillW = max(0, pct * Self.barW)
        fillBarFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -Self.barH / 2, width: max(fillW, 0), height: Self.barH),
            cornerWidth: 3, cornerHeight: 3, transform: nil
        )

        // Stock label
        stockLabel.text = "×\(warehouse)"
        if isFull {
            stockLabel.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1)
        } else {
            stockLabel.fontColor = .white
        }

        // Full ↔ normal transition
        if isFull && !wasFull {
            // Animate to full state
            cellBg.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.15, duration: 0.10),
                    SKAction.colorize(with: Self.fullBg, colorBlendFactor: 1, duration: 0.10),
                ]),
                SKAction.scale(to: 1.0, duration: 0.12),
            ]))
            cellBg.strokeColor = Self.fullBorder
            cellBg.lineWidth   = 2.5

            warningCircle.isHidden = false
            warningLabel.isHidden  = false
            warningCircle.alpha    = 0
            warningCircle.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.12),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.25, duration: 0.45),
                    SKAction.scale(to: 1.0,  duration: 0.45),
                ])),
            ]))
        } else if !isFull && wasFull {
            // Animate back to normal
            cellBg.removeAllActions()
            cellBg.run(SKAction.colorize(with: Self.normalBg, colorBlendFactor: 1, duration: 0.20))
            cellBg.strokeColor = Self.normalBorder
            cellBg.lineWidth   = 2

            warningCircle.removeAllActions()
            warningCircle.setScale(1.0)
            warningCircle.isHidden = true
            warningLabel.isHidden  = true
        }
        wasFull = isFull

        // Expand cell
        if let cost = expandCostValue {
            expandBg.isHidden    = false
            expandTitle.isHidden = false
            expandIcon.isHidden  = false
            expandCost.isHidden  = false
            expandCost.text      = "₩\(Int(cost))"

            let color: SKColor = canAfford
                ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
                : SKColor(white: 1.0, alpha: 0.40)
            expandBg.strokeColor = canAfford
                ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.6)
                : SKColor(white: 1.0, alpha: 0.25)
            expandTitle.fontColor = color
            expandIcon.fontColor  = color
            expandCost.fontColor  = color
            if canAfford && !lastCanAfford {
                expandIcon.run(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.15),
                    SKAction.scale(to: 1.0,  duration: 0.15),
                ]))
            }
            lastCanAfford = canAfford
        } else {
            expandBg.isHidden    = true
            expandTitle.isHidden = true
            expandIcon.isHidden  = true
            expandCost.isHidden  = true
        }
    }

    // MARK: - Hit testing

    func warehouseCellContains(_ point: CGPoint) -> Bool {
        cellBg.contains(point)
    }

    func expandCellContains(_ point: CGPoint) -> Bool {
        guard !expandBg.isHidden else { return false }
        return expandBg.contains(point)
    }
}
