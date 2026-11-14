import SpriteKit
import GameCore

/// Farm band: a 5-column grid of 24x24 plots at x = 12 + 24c, y = 12 + 36r (band-local), the
/// add-plot sign in the cell after the last plot, and one worker per plot standing behind its bed.
///
/// The 36 px row pitch is the 72 px band minus two 24 px cells, spent on a gap: a worker's head
/// and torso (sprite rows 2-18) must clear the soil without covering the row above's bed.
/// Per-row z keeps a row's worker behind its own bed but in front of the row above.
@MainActor
final class FarmNode: BandNode {

    enum Hit: Equatable {
        case plot(Int)
        case addPlot
    }

    private static let columns = 5
    private static let originY = 12
    private static let rowPitch = 36
    /// Where the worker's feet stand relative to the cell top: 4 px into the bed, so the legs
    /// (sprite rows 19-23) are hidden and only head and torso show.
    private static let workerFeet = 7
    /// A tap anywhere in the row's strip, gap and worker included, counts as the plot.
    private static let hitMargin = 6

    @MainActor
    private final class PlotView {
        let sprite = dotSprite("dot_farm_plot_empty")
        let barBack = SKSpriteNode(color: SKColor(hex: 0x2b1b2e), size: CGSize(width: 16, height: 4))
        let barFill = SKSpriteNode(color: SKColor(hex: 0xa0d85c), size: CGSize(width: 1, height: 2))
        let worker = StaffFigure(zzzOffset: CGPoint(x: 6, y: 13))
        var key = ""
        var workerKey = ""
    }

    private let layout: DotWorldLayout
    private var views: [PlotView] = []
    private let addSign = dotSprite("dot_farm_plot_locked")
    private let plotLayer = SKNode()
    private var lastCount = -1

    init(layout: DotWorldLayout) {
        self.layout = layout
        super.init(top: layout.farmTop)
        zPosition = 400
        addChild(plotLayer)
        addSign.isHidden = true
        plotLayer.addChild(addSign)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private static func cellOrigin(_ i: Int) -> CGPoint {
        CGPoint(x: CGFloat(12 + 24 * (i % columns)), y: CGFloat(originY + rowPitch * (i / columns)))
    }

    func plotCenter(_ i: Int) -> CGPoint {
        let o = Self.cellOrigin(i)
        return rootPoint(o.x + 12, o.y + 12)
    }

    /// Where the first-run pointer's tip lands: just above the bed's left half, clear of the worker.
    func hintTip(_ i: Int) -> CGPoint {
        let o = Self.cellOrigin(i)
        return rootPoint(o.x + 8, o.y + 2)
    }

    func hit(local p: CGPoint, plotCount: Int, canAdd: Bool) -> Hit? {
        let col = Int(floor((p.x - 12) / 24))
        let row = Int(floor((p.y - CGFloat(Self.originY - Self.hitMargin)) / CGFloat(Self.rowPitch)))
        guard (0..<Self.columns).contains(col), row >= 0 else { return nil }
        let index = row * Self.columns + col
        if index < plotCount { return .plot(index) }
        if index == plotCount, canAdd { return .addPlot }
        return nil
    }

    /// Head height of plot `i`'s worker, for the heart that rises when they are woken.
    func workerHead(_ i: Int) -> CGPoint {
        let o = Self.cellOrigin(i)
        return rootPoint(o.x + 16, o.y - 12)
    }

    func bumpWorker(plot i: Int, reduceMotion: Bool) {
        guard views.indices.contains(i) else { return }
        FXLayer.squash(views[i].worker, reduceMotion: reduceMotion)
    }

    func bump(plot i: Int, reduceMotion: Bool) {
        guard views.indices.contains(i) else { return }
        FXLayer.squash(views[i].sprite, reduceMotion: reduceMotion)
    }

    func shake(plot i: Int, reduceMotion: Bool) {
        guard views.indices.contains(i) else { return }
        FXLayer.shake(views[i].sprite, reduceMotion: reduceMotion)
    }

    func apply(farm: FarmState, canAddPlot: Bool, pulseRipe: Bool = false, reduceMotion: Bool) {
        let count = farm.plots.count
        if count != lastCount { rebuild(count: count) }
        for (i, plot) in farm.plots.enumerated() {
            let view = views[i]
            let (key, growth) = Self.key(for: plot)
            if key != view.key {
                view.key = key
                setArt(view.sprite, key: key, reduceMotion: reduceMotion)
            }
            let showBar = plot.isPlanted && !plot.isReady
            view.barBack.isHidden = !showBar
            view.barFill.isHidden = !showBar
            if showBar {
                let px = max(1, Int(growth * 14))
                if Int(view.barFill.size.width) != px { view.barFill.size = CGSize(width: CGFloat(px), height: 2) }
            }

            setPulse(view.sprite, active: pulseRipe && plot.isReady, reduceMotion: reduceMotion)

            let kind = Self.workerKind(plot.workerType)
            let tired = plot.workerEnergy < ShopStaffPresence.lowEnergyThreshold
            let pose: StaffFigure.Pose = plot.isPlanted && !tired ? .work : (tired ? .tired : .idle)
            view.worker.configure(kind: kind, pose: pose, isTired: tired && kind != nil,
                                  bobs: !reduceMotion, fast: false)
        }

        addSign.isHidden = !canAddPlot
        if canAddPlot {
            let o = Self.cellOrigin(count)
            addSign.position = feetPoint(o.x + 12, o.y + 23)
            addSign.zPosition = Self.z(count, 1)
        }
    }

    private static func z(_ index: Int, _ layer: CGFloat) -> CGFloat { CGFloat(index / columns) * 10 + layer }

    private func rebuild(count: Int) {
        for view in views { view.sprite.removeFromParent(); view.barBack.removeFromParent(); view.worker.removeFromParent() }
        views.removeAll()
        lastCount = count
        for i in 0..<count {
            let view = PlotView()
            let o = Self.cellOrigin(i)
            view.sprite.position = feetPoint(o.x + 12, o.y + 23)
            view.barBack.anchorPoint = CGPoint(x: 0, y: 1)
            view.barBack.position = artPoint(o.x + 4, o.y + 17)
            view.barBack.zPosition = Self.z(i, 2)
            view.barFill.anchorPoint = CGPoint(x: 0, y: 1)
            view.barFill.position = CGPoint(x: 1, y: -1)
            view.barBack.addChild(view.barFill)
            view.sprite.zPosition = Self.z(i, 1)
            view.worker.position = feetPoint(o.x + 16, o.y + CGFloat(Self.workerFeet))
            view.worker.zPosition = Self.z(i, 0)
            plotLayer.addChild(view.sprite)
            plotLayer.addChild(view.barBack)
            plotLayer.addChild(view.worker)
            views.append(view)
        }
    }

    private static func key(for plot: FarmPlot) -> (String, Double) {
        switch plot.stage {
        case .empty:   return ("empty", 0)
        case .sprout:  return (plot.growth < 0.12 ? "seeded" : "sprout", plot.growth / 0.35)
        case .growing: return ("growing", plot.growth)
        case .ready:   return (plot.isGolden ? "golden" : "ready", 1)
        }
    }

    private static func workerKind(_ type: FarmWorkerType) -> String? {
        switch type {
        case .none:        nil
        case .alba:        "alba"
        case .farmer:      "farmer"
        case .veteranAlba: "veteran_alba"
        }
    }

    /// Ripe plots glow gently when the player is out of cabbages to cook, so they know what to tap.
    private func setPulse(_ sprite: SKSpriteNode, active: Bool, reduceMotion: Bool) {
        guard active else {
            sprite.removeAction(forKey: "pulse")
            sprite.colorBlendFactor = 0
            return
        }
        sprite.color = .white
        guard !reduceMotion else { sprite.colorBlendFactor = 0.2; return }
        guard sprite.action(forKey: "pulse") == nil else { return }
        sprite.run(.repeatForever(.sequence([.colorize(withColorBlendFactor: 0.35, duration: 0.5),
                                             .colorize(withColorBlendFactor: 0, duration: 0.5)])), withKey: "pulse")
    }

    private func setArt(_ sprite: SKSpriteNode, key: String, reduceMotion: Bool) {
        sprite.removeAction(forKey: "loop")
        switch key {
        case "ready", "golden":
            let frames = DotTexture.frames("dot_farm_plot_\(key)", count: 2)
            sprite.texture = frames[0]
            guard !reduceMotion else { return }
            let per = key == "golden" ? 0.35 : 0.6
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: per, resize: false, restore: false)),
                       withKey: "loop")
        default:
            sprite.texture = DotTexture.named("dot_farm_plot_\(key)")
        }
    }
}
