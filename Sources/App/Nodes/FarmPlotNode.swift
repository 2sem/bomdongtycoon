import SpriteKit
import GameCore

final class FarmPlotNode: SKNode {

    private let bg: SKShapeNode
    private let stageLabel = SKLabelNode()
    private let progressFill: SKShapeNode
    private let workerLabel = SKLabelNode()

    private static let stageEmoji: [FarmPlot.Stage: String] = [
        .empty: "🪨", .sprout: "🌱", .growing: "🌿", .ready: "🥬"
    ]

    private static let readyColor   = SKColor(red: 0.22, green: 0.60, blue: 0.22, alpha: 1)
    private static let soilColor    = SKColor(red: 0.50, green: 0.34, blue: 0.14, alpha: 1)
    private static let barBgColor   = SKColor(white: 0.2, alpha: 0.5)
    private static let barFillColor = SKColor(red: 0.3, green: 0.82, blue: 0.3, alpha: 1)

    override init() {
        bg = SKShapeNode(rectOf: CGSize(width: 52, height: 52), cornerRadius: 8)
        let barBg = SKShapeNode(rectOf: CGSize(width: 44, height: 5), cornerRadius: 2)
        progressFill = SKShapeNode()
        super.init()

        bg.fillColor = Self.soilColor
        bg.strokeColor = SKColor(red: 0.32, green: 0.20, blue: 0.06, alpha: 1)
        bg.lineWidth = 2
        addChild(bg)

        stageLabel.fontSize = 26
        stageLabel.verticalAlignmentMode = .center
        stageLabel.position = CGPoint(x: 0, y: 5)
        addChild(stageLabel)

        barBg.fillColor = Self.barBgColor
        barBg.strokeColor = .clear
        barBg.position = CGPoint(x: 0, y: -17)
        addChild(barBg)

        progressFill.fillColor = Self.barFillColor
        progressFill.strokeColor = .clear
        progressFill.position = CGPoint(x: -22, y: -17)
        addChild(progressFill)

        workerLabel.fontSize = 13
        workerLabel.position = CGPoint(x: 17, y: 18)
        addChild(workerLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var wasReady = false

    func update(plot: FarmPlot) {
        stageLabel.text = Self.stageEmoji[plot.stage]

        if plot.isReady && !wasReady {
            // Transition to ready: green bg + pulse
            bg.fillColor = Self.readyColor
            stageLabel.removeAllActions()
            stageLabel.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.20, duration: 0.45),
                SKAction.scale(to: 1.0,  duration: 0.45),
            ])))
        } else if !plot.isReady && wasReady {
            bg.fillColor = Self.soilColor
            stageLabel.removeAllActions()
            stageLabel.setScale(1.0)
        }
        wasReady = plot.isReady

        // Progress bar
        let w = CGFloat(min(plot.growth, 1.0)) * 44
        progressFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -2, width: max(w, 0), height: 5),
            cornerWidth: 2, cornerHeight: 2, transform: nil
        )

        workerLabel.text = plot.hasWorker ? "👷" : ""
    }

    func animateHarvest() {
        run(SKAction.sequence([
            SKAction.scale(to: 1.35, duration: 0.08),
            SKAction.scale(to: 1.0,  duration: 0.10),
        ]))
    }
}
