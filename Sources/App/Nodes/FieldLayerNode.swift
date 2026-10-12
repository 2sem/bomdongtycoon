import SpriteKit
import GameCore

/// The crop plots on `GroundLayer`'s field tiles, one per `farm.plots`
/// entry, plus one `plot_add` cell while the farm can still expand, and
/// the farm worker standing at each plot that has one.
///
/// Plots fill a 3-wide block from its front row (`frontRow`, next to the
/// walkway row -1 that `GroundLayer` leaves free) northward, left to
/// right. `FarmSystem.maxPlots` slots fit in rows -2...-5, inside the
/// field tiles (rows -6...-2).
///
/// Content is state-driven: `apply(farm:canAddPlot:)` is called every
/// frame and only touches a node whose stage or pose actually changed.
final class FieldLayer: SKNode {

    // `ShopWallLayer`/`KitchenLayer` (not yet ported, not added to the
    // scene) still read these to align with the old crop patch.
    static let columnCount = 3
    static let rowCount = 3
    static let startColumn = -1
    static let startRow = -(1 + rowCount)

    static func layoutMetrics(for size: CGSize) -> (startRow: Int, startColumn: Int) {
        (startRow, startColumn)
    }

    enum Hit: Equatable {
        case plot(Int)
        case addPlot
    }

    private static let frontRow = -2
    private static let slotColumns = 3

    /// How far (in cell units, toward the north corner) a worker stands
    /// from the cell centre: just past the bed's 0.42 half-extent, so the
    /// figure stands on the walkway beside the bed rather than in it.
    private static let workerOffset: CGFloat = 0.45

    /// Taps land on the raised crop, above the cell centre; sampling this
    /// fraction of a tile height lower keeps a tap on a tall `plot_ready`
    /// flag from resolving to the cell behind it.
    private static let hitBias: CGFloat = 0.15

    private struct SpriteSpec {
        let imageName: String
        let nativeSize: CGSize
        let anchor: CGPoint
    }

    // From the isorender measurement table (native 3x px, anchor from bottom).
    private static func plotSpec(_ content: SlotContent) -> SpriteSpec {
        switch content {
        case .plot(.empty):
            return SpriteSpec(imageName: "plot_empty", nativeSize: CGSize(width: 322, height: 218), anchor: CGPoint(x: 0.5, y: 0.45752))
        case .plot(.sprout):
            return SpriteSpec(imageName: "plot_sprout", nativeSize: CGSize(width: 322, height: 218), anchor: CGPoint(x: 0.5, y: 0.45752))
        case .plot(.growing):
            return SpriteSpec(imageName: "plot_growing", nativeSize: CGSize(width: 322, height: 222), anchor: CGPoint(x: 0.5, y: 0.44928))
        case .plot(.ready):
            return SpriteSpec(imageName: "plot_ready", nativeSize: CGSize(width: 322, height: 224), anchor: CGPoint(x: 0.5, y: 0.44527))
        case .add:
            return SpriteSpec(imageName: "plot_add", nativeSize: CGSize(width: 322, height: 208), anchor: CGPoint(x: 0.5, y: 0.47952))
        }
    }

    // Chibi farmer, art PR #120 table (same convention as plotSpec).
    private static func workerSpec(_ pose: WorkerPose) -> SpriteSpec {
        switch pose {
        case .idle:
            return SpriteSpec(imageName: "farmer_idle", nativeSize: CGSize(width: 105, height: 160), anchor: CGPoint(x: 0.5, y: 0.07462))
        case .working:
            return SpriteSpec(imageName: "farmer_working", nativeSize: CGSize(width: 117, height: 183), anchor: CGPoint(x: 0.55128, y: 0.19093))
        }
    }

    private enum SlotContent: Equatable {
        case plot(FarmPlot.Stage)
        case add
    }

    private enum WorkerPose: Equatable {
        case idle, working
    }

    /// A worker shows while the plot has one with energy left, working
    /// while a crop is growing and waiting otherwise (empty, or ready and
    /// about to be harvested).
    private static func workerPose(for plot: FarmPlot) -> WorkerPose? {
        guard plot.hasWorker, plot.workerEnergy > 0 else { return nil }
        return plot.isPlanted && !plot.isReady ? .working : .idle
    }

    private final class Slot {
        let plotNode = SKSpriteNode()
        let workerNode = SKSpriteNode()
        var content: SlotContent?
        var pose: WorkerPose?
    }

    private var slots: [Slot] = []
    private var plotCount = 0
    private var showsAddCell = false
    private let scale = ShopPropSpriteNode.isorenderScale(fittingTo: GroundLayer.grid)

    // MARK: - State

    func apply(farm: FarmState, canAddPlot: Bool) {
        plotCount = farm.plots.count
        showsAddCell = canAddPlot
        let slotCount = plotCount + (canAddPlot ? 1 : 0)
        while slots.count < slotCount { addSlot(index: slots.count) }

        for (index, slot) in slots.enumerated() {
            let content: SlotContent?
            var pose: WorkerPose?
            if index < plotCount {
                let plot = farm.plots[index]
                content = .plot(plot.stage)
                pose = Self.workerPose(for: plot)
            } else {
                content = index == plotCount && canAddPlot ? .add : nil
            }

            if content != slot.content {
                slot.content = content
                slot.plotNode.isHidden = content == nil
                if let content { configure(slot.plotNode, with: Self.plotSpec(content)) }
            }
            if pose != slot.pose {
                slot.pose = pose
                slot.workerNode.isHidden = pose == nil
                if let pose { configure(slot.workerNode, with: Self.workerSpec(pose)) }
            }
        }
    }

    private func configure(_ node: SKSpriteNode, with spec: SpriteSpec) {
        node.texture = SKTexture(imageNamed: spec.imageName)
        let width = spec.nativeSize.width * scale
        node.size = CGSize(width: width, height: width * spec.nativeSize.height / spec.nativeSize.width)
        node.anchorPoint = spec.anchor
    }

    private func addSlot(index: Int) {
        let slot = Slot()
        let cell = Self.cell(forSlot: index)
        let grid = GroundLayer.grid

        slot.plotNode.position = grid.point(col: cell.col, row: cell.row)
        slot.plotNode.zPosition = CGFloat(cell.col + cell.row)
        slot.plotNode.isHidden = true

        // Worker stands at the cell's north corner, drawn just above its
        // own bed. Half a step is less than the 1 that separates this cell
        // from the next in `col + row`, so it never sorts past a neighbour.
        slot.workerNode.position = grid.point(
            col: CGFloat(cell.col) - Self.workerOffset, row: CGFloat(cell.row) - Self.workerOffset)
        slot.workerNode.zPosition = slot.plotNode.zPosition + 0.5
        slot.workerNode.isHidden = true

        addChild(slot.plotNode)
        addChild(slot.workerNode)
        slots.append(slot)
    }

    private static func cell(forSlot index: Int) -> (col: Int, row: Int) {
        (startColumn + index % slotColumns, frontRow - index / slotColumns)
    }

    // MARK: - Hit testing

    /// The plot or add cell under `point` (in this layer's space), or
    /// `nil` for anything else — so a miss falls through to panning.
    func hit(at point: CGPoint) -> Hit? {
        let grid = GroundLayer.grid
        let x = point.x
        let y = point.y - Self.hitBias * grid.tileHeight
        let col = Int((x / grid.tileWidth - y / grid.tileHeight).rounded())
        let row = Int((-y / grid.tileHeight - x / grid.tileWidth).rounded())

        let column = col - Self.startColumn
        let depth = Self.frontRow - row
        guard (0..<Self.slotColumns).contains(column), depth >= 0 else { return nil }
        let index = depth * Self.slotColumns + column
        if index < plotCount { return .plot(index) }
        if index == plotCount && showsAddCell { return .addPlot }
        return nil
    }

    // MARK: - Feedback

    /// Brief squash on an accepted tap.
    func pulse(_ hit: Hit) {
        let index: Int
        switch hit {
        case .plot(let plotIndex): index = plotIndex
        case .addPlot: index = plotCount
        }
        guard slots.indices.contains(index) else { return }
        let squash = SKAction.sequence([
            .scale(to: 1.08, duration: 0.08),
            .scale(to: 1.0, duration: 0.12),
        ])
        slots[index].plotNode.run(squash, withKey: "pulse")
    }
}
