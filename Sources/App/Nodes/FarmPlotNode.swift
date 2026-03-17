import SpriteKit
import GameCore

final class FarmPlotNode: SKNode {

    // MARK: - Layout constants
    static let size = CGSize(width: 62, height: 62)
    private static let barWidth:  CGFloat = 52
    private static let barHeight: CGFloat = 7

    // MARK: - Colours
    private static let soilColor    = SKColor(red: 0.46, green: 0.30, blue: 0.11, alpha: 1)
    private static let readyColor   = SKColor(red: 0.18, green: 0.58, blue: 0.18, alpha: 1)
    private static let barFillColor = SKColor(red: 0.28, green: 0.85, blue: 0.28, alpha: 1)
    private static let barBgColor   = SKColor(white: 0.0, alpha: 0.30)

    // MARK: - Nodes
    private let bg              = SKShapeNode(rectOf: size, cornerRadius: 10);
    private let stageLabel      = SKLabelNode();
    private let barBg           = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 3);
    private let barFill         = SKShapeNode();
    private let workerLabel     = SKLabelNode();
    private let workerEnergyBar = SKShapeNode();
    private let hintPlus        = SKLabelNode();
    private let hintCost        = SKLabelNode();

    // MARK: - Init

    override init() {
        super.init()

        // Background
        bg.fillColor   = Self.soilColor
        bg.strokeColor = SKColor(red: 0.28, green: 0.17, blue: 0.04, alpha: 1)
        bg.lineWidth   = 2
        addChild(bg)

        // Stage emoji
        stageLabel.fontSize = 30
        stageLabel.verticalAlignmentMode = .center
        stageLabel.position = CGPoint(x: 0, y: 6)
        addChild(stageLabel)

        // Progress bar background
        barBg.fillColor   = Self.barBgColor
        barBg.strokeColor = .clear
        barBg.position    = CGPoint(x: 0, y: -20)
        addChild(barBg)

        // Progress bar fill (positioned at left edge of barBg)
        barFill.fillColor   = Self.barFillColor
        barFill.strokeColor = .clear
        barFill.position    = CGPoint(x: -Self.barWidth / 2, y: -20)
        addChild(barFill)

        // Worker badge
        workerLabel.fontSize = 13;
        workerLabel.position = CGPoint(x: 20, y: 22);
        addChild(workerLabel);

        // Worker energy bar (20×3pt strip below worker badge)
        workerEnergyBar.strokeColor = .clear;
        workerEnergyBar.position = CGPoint(x: 20, y: 13);
        workerEnergyBar.isHidden = true;
        addChild(workerEnergyBar);

        // Empty-state hint: seed emoji above, cost below
        hintPlus.text      = "🌰"   // seed — clearly "plant here"
        hintPlus.fontSize  = 24
        hintPlus.verticalAlignmentMode = .center
        hintPlus.position  = CGPoint(x: 0, y: 8)
        addChild(hintPlus)

        hintCost.text      = "₩\(Int(FarmSystem.seedCost))"
        hintCost.fontName  = "AppleSDGothicNeo-Regular"
        hintCost.fontSize  = 11
        hintCost.fontColor = SKColor(white: 1.0, alpha: 0.50)
        hintCost.verticalAlignmentMode = .center
        hintCost.position  = CGPoint(x: 0, y: -10)
        addChild(hintCost)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - State

    private var wasReady    = false
    private var wasPlanted  = false

    func update(plot: FarmPlot, warehouseFull: Bool, assignedEmoji: String?, workerAvailable: Bool, workerEnergy: Double) {
        let isEmpty = !plot.isPlanted

        hintPlus.isHidden   = !isEmpty
        hintCost.isHidden   = !isEmpty
        stageLabel.isHidden =  isEmpty

        stageLabel.text = stageEmoji(for: plot.stage)

        if plot.isReady && !wasReady {
            bg.fillColor = Self.readyColor
            stageLabel.removeAllActions()
            stageLabel.run(SKAction.sequence([
                SKAction.scale(to: 1.4, duration: 0.10),
                SKAction.scale(to: 1.0, duration: 0.12),
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.12, duration: 0.5),
                    SKAction.scale(to: 1.0,  duration: 0.5),
                ])),
            ]))
        } else if !plot.isReady && wasReady {
            bg.fillColor = Self.soilColor
            stageLabel.removeAllActions()
            stageLabel.setScale(1.0)
        }

        if isEmpty && wasPlanted {
            bg.strokeColor = SKColor(white: 1.0, alpha: 0.30)
            bg.lineWidth   = 1.5
        } else if !isEmpty && !wasPlanted {
            bg.strokeColor = SKColor(red: 0.28, green: 0.17, blue: 0.04, alpha: 1)
            bg.lineWidth   = 2
        }

        // Dim ready plots when warehouse is full
        if plot.isReady && warehouseFull {
            alpha = 0.45
        } else {
            alpha = 1.0
        }

        wasReady   = plot.isReady
        wasPlanted = plot.isPlanted

        let showBar = plot.isPlanted && !plot.isReady
        barBg.isHidden   = !showBar
        barFill.isHidden = !showBar
        if showBar {
            let w = CGFloat(min(plot.growth, 1.0)) * Self.barWidth
            barFill.path = CGPath(
                roundedRect: CGRect(x: 0, y: -Self.barHeight / 2,
                                    width: max(w, 0), height: Self.barHeight),
                cornerWidth: 3, cornerHeight: 3, transform: nil
            )
        }

        // Worker badge: solid when assigned, dim hint when worker available
        if plot.hasWorker, let emoji = assignedEmoji {
            workerLabel.text  = emoji;
            workerLabel.alpha = 1.0;
        } else if workerAvailable {
            workerLabel.text  = "👷";
            workerLabel.alpha = 0.25;
        } else {
            workerLabel.text  = "";
            workerLabel.alpha = 1.0;
        }

        // Worker energy bar
        workerEnergyBar.isHidden = !plot.hasWorker;
        if plot.hasWorker {
            let fillW = CGFloat(20) * CGFloat(max(0, min(1, workerEnergy)));
            workerEnergyBar.path = CGPath(
                roundedRect: CGRect(x: -10, y: -1.5, width: max(fillW, 0), height: 3),
                cornerWidth: 1.5, cornerHeight: 1.5, transform: nil
            );
            if workerEnergy > 0.6 {
                workerEnergyBar.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1);
            } else if workerEnergy > 0.3 {
                workerEnergyBar.fillColor = SKColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1);
            } else {
                workerEnergyBar.fillColor = SKColor(red: 0.9, green: 0.25, blue: 0.2, alpha: 1);
            }
        }
    }

    func animateHarvest() {
        run(SKAction.sequence([
            SKAction.scale(to: 1.4, duration: 0.07),
            SKAction.scale(to: 1.0, duration: 0.10),
        ]))
    }

    // MARK: - Helpers

    private func stageEmoji(for stage: FarmPlot.Stage) -> String {
        switch stage {
        case .empty:   return ""
        case .sprout:  return "🌱"
        case .growing: return "🌿"
        case .ready:   return "🥬"
        }
    }
}
