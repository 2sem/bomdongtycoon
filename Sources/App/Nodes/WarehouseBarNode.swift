import SpriteKit
import GameCore

// Dynamic warehouse row: [slot 0] [slot 1] ... [창고 추가]
// One slot cell per WarehouseSystem.expansionStep capacity (10 each).
// Grows like the farm row when the player purchases capacity upgrades.
final class WarehouseNode: SKNode {

    // MARK: - Layout constants
    private static let cellSize = CGSize(width: 62, height: 62)
    private static let radius:  CGFloat = 10
    private static let barW:    CGFloat = 52
    private static let barH:    CGFloat = 6
    private static let spacing: CGFloat = 68

    // MARK: - Colors
    private static let normalBg     = SKColor(red: 0.24, green: 0.16, blue: 0.06, alpha: 1)
    private static let fullBg       = SKColor(red: 0.48, green: 0.18, blue: 0.04, alpha: 1)
    private static let normalBorder = SKColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 1)
    private static let fullBorder   = SKColor(red: 0.90, green: 0.45, blue: 0.10, alpha: 1)
    private static let barBgColor   = SKColor(white: 0, alpha: 0.30)
    private static let barFillColor = SKColor(red: 0.28, green: 0.72, blue: 0.95, alpha: 1)

    // MARK: - Slot node containers
    // Each element is a plain SKNode whose children are the cell's visual nodes.
    // Keyed sub-nodes are stored by tag in userData.
    private var slotNodes: [SKNode] = []
    private var expandNode = SKNode()   // always kept; repositioned each rebuild

    // MARK: - Dirty tracking
    private var lastSlotCount   = 0
    private var lastCanAfford   = false
    private var lastWarehouse   = -1
    private var lastWasFull     = false

    override init() {
        super.init()
        buildExpandNode()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Update (called every sync cycle)

    func update(warehouse: Int, capacity: Int, expandCostValue: Double?, canAfford: Bool) {
        let step      = WarehouseSystem.expansionStep
        let slotCount = max(1, capacity / step)
        let isFull    = warehouse >= capacity

        // Rebuild slot cells when count changes
        if slotCount != lastSlotCount {
            rebuildSlots(count: slotCount)
            lastSlotCount = slotCount
        }

        // Update each slot's fill and stock label
        for i in 0..<slotNodes.count {
            let slotStock     = min(max(warehouse - i * step, 0), step)
            let isLastSlot    = i == slotNodes.count - 1
            updateSlot(slotNodes[i],
                       stock: slotStock,
                       capacity: step,
                       showWarning: isLastSlot && isFull,
                       wasFullBefore: isLastSlot && lastWasFull)
        }
        lastWasFull = isFull

        // Update expand cell
        updateExpandNode(cost: expandCostValue, canAfford: canAfford)
    }

    // MARK: - Rebuild slots

    private func rebuildSlots(count: Int) {
        slotNodes.forEach { $0.removeFromParent() }
        slotNodes.removeAll()
        expandNode.removeFromParent()

        let originX = -CGFloat(count) * Self.spacing / 2

        for i in 0..<count {
            let slot = makeSlotNode()
            slot.position = CGPoint(x: originX + CGFloat(i) * Self.spacing, y: 0)
            addChild(slot)
            slotNodes.append(slot)
        }

        // Expand cell sits right after the last slot
        expandNode.position = CGPoint(x: originX + CGFloat(count) * Self.spacing, y: 0)
        addChild(expandNode)

        lastWasFull   = false   // reset animation state on rebuild
        lastWarehouse = -1
    }

    private func makeSlotNode() -> SKNode {
        let node = SKNode()

        let bg = SKShapeNode(rectOf: Self.cellSize, cornerRadius: Self.radius)
        bg.fillColor   = Self.normalBg
        bg.strokeColor = Self.normalBorder
        bg.lineWidth   = 2
        bg.name        = "bg"
        node.addChild(bg)

        let icon = SKLabelNode(text: "📦")
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        icon.position = CGPoint(x: 0, y: 20)
        icon.name = "icon"
        node.addChild(icon)

        let stock = SKLabelNode()
        stock.fontName = "AppleSDGothicNeo-Bold"
        stock.fontSize = 18
        stock.fontColor = .white
        stock.verticalAlignmentMode   = .center
        stock.horizontalAlignmentMode = .center
        stock.position = CGPoint(x: 0, y: -2)
        stock.name = "stock"
        node.addChild(stock)

        let barBg = SKShapeNode(rectOf: CGSize(width: Self.barW, height: Self.barH), cornerRadius: 3)
        barBg.fillColor   = Self.barBgColor
        barBg.strokeColor = .clear
        barBg.position    = CGPoint(x: 0, y: -22)
        barBg.name        = "barBg"
        node.addChild(barBg)

        let barFill = SKShapeNode()
        barFill.fillColor   = Self.barFillColor
        barFill.strokeColor = .clear
        barFill.position    = CGPoint(x: -Self.barW / 2, y: -22)
        barFill.name        = "barFill"
        node.addChild(barFill)

        let warnCircle = SKShapeNode(circleOfRadius: 9)
        warnCircle.fillColor   = SKColor(red: 0.95, green: 0.40, blue: 0.05, alpha: 1)
        warnCircle.strokeColor = .clear
        warnCircle.position    = CGPoint(x: 22, y: 22)
        warnCircle.isHidden    = true
        warnCircle.name        = "warnCircle"
        node.addChild(warnCircle)

        let warnLabel = SKLabelNode(text: "!")
        warnLabel.fontName = "AppleSDGothicNeo-Bold"
        warnLabel.fontSize = 13
        warnLabel.fontColor = .white
        warnLabel.verticalAlignmentMode   = .center
        warnLabel.horizontalAlignmentMode = .center
        warnLabel.position  = CGPoint(x: 22, y: 22)
        warnLabel.isHidden  = true
        warnLabel.name      = "warnLabel"
        node.addChild(warnLabel)

        return node
    }

    // MARK: - Update slot

    private func updateSlot(_ node: SKNode, stock: Int, capacity: Int,
                             showWarning: Bool, wasFullBefore: Bool) {
        guard let bg        = node.childNode(withName: "bg")        as? SKShapeNode,
              let stockLbl  = node.childNode(withName: "stock")     as? SKLabelNode,
              let barFill   = node.childNode(withName: "barFill")   as? SKShapeNode,
              let warnCircle = node.childNode(withName: "warnCircle") as? SKShapeNode,
              let warnLabel  = node.childNode(withName: "warnLabel")  as? SKLabelNode
        else { return }

        // Stock label
        stockLbl.text = "×\(stock)"
        stockLbl.fontColor = showWarning
            ? SKColor(red: 1.0, green: 0.85, blue: 0.40, alpha: 1)
            : .white

        // Fill bar
        let pct   = capacity > 0 ? CGFloat(stock) / CGFloat(capacity) : 0
        let fillW = max(0, pct * Self.barW)
        barFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -Self.barH / 2, width: fillW, height: Self.barH),
            cornerWidth: 3, cornerHeight: 3, transform: nil
        )

        // Warning badge transition
        if showWarning && !wasFullBefore {
            bg.run(SKAction.sequence([
                SKAction.group([
                    SKAction.scale(to: 1.15, duration: 0.10),
                    SKAction.colorize(with: Self.fullBg, colorBlendFactor: 1, duration: 0.10),
                ]),
                SKAction.scale(to: 1.0, duration: 0.12),
            ]))
            bg.strokeColor = Self.fullBorder
            bg.lineWidth   = 2.5

            warnCircle.isHidden = false
            warnLabel.isHidden  = false
            warnCircle.alpha    = 0
            warnCircle.run(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.12),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.25, duration: 0.45),
                    SKAction.scale(to: 1.0,  duration: 0.45),
                ])),
            ]))
        } else if !showWarning && wasFullBefore {
            bg.removeAllActions()
            bg.run(SKAction.colorize(with: Self.normalBg, colorBlendFactor: 1, duration: 0.20))
            bg.strokeColor = Self.normalBorder
            bg.lineWidth   = 2

            warnCircle.removeAllActions()
            warnCircle.setScale(1.0)
            warnCircle.isHidden = true
            warnLabel.isHidden  = true
        }
    }

    // MARK: - Expand node

    private func buildExpandNode() {
        let bg = SKShapeNode(rectOf: Self.cellSize, cornerRadius: Self.radius)
        bg.fillColor   = Self.normalBg
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        bg.lineWidth   = 2
        bg.name        = "expandBg"
        expandNode.addChild(bg)

        let title = SKLabelNode(text: "창고 추가")
        title.fontName = "AppleSDGothicNeo-Bold"
        title.fontSize = 11
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 18)
        title.name = "expandTitle"
        expandNode.addChild(title)

        let plus = SKLabelNode(text: "+")
        plus.fontName = "AppleSDGothicNeo-Bold"
        plus.fontSize = 22
        plus.verticalAlignmentMode   = .center
        plus.horizontalAlignmentMode = .center
        plus.position = CGPoint(x: 0, y: 2)
        plus.name = "expandPlus"
        expandNode.addChild(plus)

        let cost = SKLabelNode()
        cost.fontName = "AppleSDGothicNeo-Bold"
        cost.fontSize = 13
        cost.verticalAlignmentMode   = .center
        cost.horizontalAlignmentMode = .center
        cost.position = CGPoint(x: 0, y: -16)
        cost.name = "expandCost"
        expandNode.addChild(cost)
    }

    private func updateExpandNode(cost expandCost: Double?, canAfford: Bool) {
        guard let bg    = expandNode.childNode(withName: "expandBg")    as? SKShapeNode,
              let title = expandNode.childNode(withName: "expandTitle") as? SKLabelNode,
              let plus  = expandNode.childNode(withName: "expandPlus")  as? SKLabelNode,
              let cost  = expandNode.childNode(withName: "expandCost")  as? SKLabelNode
        else { return }

        if let expandCost {
            expandNode.isHidden = false
            cost.text = "₩\(Int(expandCost))"
            let color: SKColor = canAfford
                ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
                : SKColor(white: 1.0, alpha: 0.40)
            bg.strokeColor = canAfford
                ? SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 0.6)
                : SKColor(white: 1.0, alpha: 0.25)
            [title, plus, cost].forEach { $0.fontColor = color }
            if canAfford && !lastCanAfford {
                plus.run(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.15),
                    SKAction.scale(to: 1.0,  duration: 0.15),
                ]))
            }
        } else {
            expandNode.isHidden = true
        }
        lastCanAfford = canAfford
    }

    // MARK: - Hit testing

    func expandCellContains(_ point: CGPoint) -> Bool {
        guard !expandNode.isHidden else { return false }
        let local = expandNode.convert(point, from: self)
        return expandNode.childNode(withName: "expandBg")?.contains(local) ?? false
    }
}
