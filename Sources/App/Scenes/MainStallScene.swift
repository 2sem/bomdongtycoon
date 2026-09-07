import SpriteKit
import GameCore
import UIKit

extension Notification.Name {
    static let openStaffSheet = Notification.Name("openStaffSheet")
    static let openJobSheet = Notification.Name("openJobSheet")
}

final class MainStallScene: SKScene {

    weak var store: GameStore?

    private static let maxDelta: TimeInterval = 1.0 / 3.0
    private var lastUpdateTime: TimeInterval = 0
    private let groundLayer = GroundLayer()
    private let fieldLayer = FieldLayer()
    private let farmerLayer = FarmerLayer()
    private let shopWallLayer = ShopWallLayer()
    private let kitchenLayer = KitchenLayer()

    /// The shop plot is a 3×3 block of tiles (see `GroundLayer`'s own
    /// `map`), not a single tile — an experiment in growing the shop
    /// beyond its original 1×1 footprint. Each side of the block is 3
    /// tile-edges long, so each wall piece is 3 *chained* copies of the
    /// original single-tile node, not one node stretched 3×: each wall
    /// asset's own plank/post art is drawn at a fixed real-world scale
    /// (matched to a single tile's own half-diagonal edge), so stretching
    /// one copy across 3 tile-edges would distort the wood grain 3× wider
    /// than it should look. Chaining works because consecutive tiles
    /// along a diamond's own edge share a vertex — one tile's far corner
    /// is the next tile's near corner — the same way the box's own 4
    /// corners are shared between adjacent *sides* today, just repeated
    /// one level down, across tiles on the *same* side.
    ///
    /// A single static array per side, not a "layer": each element fits
    /// itself to `GroundLayer.grid` once (same as the original single
    /// wall did) and never needs relaying out. `didMove(to:)` positions
    /// each element at its own tile's own shared vertex — see the vertex
    /// helper functions there.
    private let shopWallLeftSegments = (0..<3).map { _ in ShopWallLeftNode(fittingTo: GroundLayer.grid) }

    /// The shop plot's north-west wall segments — each meets the
    /// corresponding `shopWallLeftSegments` element at a shared West
    /// vertex, same as the original single-tile box.
    private let shopWallBackSegments = (0..<3).map { _ in ShopWallBackNode(fittingTo: GroundLayer.grid) }

    /// The shop plot's south-east wall segments — each meets the
    /// corresponding `shopWallLeftSegments` element at a shared South
    /// vertex.
    private let shopWallFrontSegments = (0..<3).map { _ in ShopWallFrontNode(fittingTo: GroundLayer.grid) }

    /// The shop plot's north-east wall segments — each meets the
    /// corresponding `shopWallBackSegments` element at a shared North
    /// vertex, closing the box's fourth side.
    private let shopWallRightSegments = (0..<3).map { _ in ShopWallRightNode(fittingTo: GroundLayer.grid) }

    /// Pans the world; `GroundLayer.worldBounds` clamps how far (see
    /// `clampCameraPosition()`) — "the map data" (`GroundLayer.map` plus
    /// its margin) is what actually limits the scrollable area, not the
    /// device screen.
    private let cameraNode = SKCameraNode()

    /// Set on `touchesBegan`, cleared on `touchesEnded`/`touchesCancelled`
    /// — `nil` means no active drag, so `touchesMoved` has nothing to
    /// diff against yet (the first move after a touch begins establishes
    /// the baseline rather than jumping the camera).
    private var lastPanLocation: CGPoint?

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor

        camera = cameraNode
        addChild(cameraNode)
        // Start framed on the farm/shop plot, same as before panning
        // existed — GroundLayer.layout() no longer centers content itself
        // (see its doc comment), so the camera is what does this now.
        cameraNode.position = GroundLayer.mapCentroid

        // GroundLayer/FieldLayer/FarmerLayer all draw once, in fixed world
        // space — no `size` argument anymore, and no need to call again on
        // resize (only the camera's clamp bounds depend on screen size,
        // handled in didChangeSize below).
        addChild(groundLayer)
        groundLayer.layout()

        // FieldLayer/FarmerLayer are ported onto GroundLayer's IsoGrid (see
        // FieldLayerNode.swift/FarmerNode.swift) and restored here.
        // ShopWallLayer/KitchenLayer stay disabled — their art hasn't been
        // redone for the new isometric style yet, so adding them now would
        // sit a placeholder building next to the new watercolor ground.
        fieldLayer.zPosition = 10
        addChild(fieldLayer)
        fieldLayer.layout()

        // Same base zPosition as fieldLayer so FarmerLayer's local row-based zPosition
        // (see FarmerLayer.layout) compares directly against FieldLayer's plot zPositions.
        farmerLayer.zPosition = 10
        addChild(farmerLayer)
        farmerLayer.layout()

        // shopWallLayer.zPosition = 10
        // addChild(shopWallLayer)
        // shopWallLayer.layout(for: frame.size)
        //
        // kitchenLayer.zPosition = 10
        // addChild(kitchenLayer)
        // kitchenLayer.layout(for: frame.size)

        // Per-tile vertex helpers — same offsets the original single-tile
        // box used (grid.point(col:row:) plus half a tile's own width or
        // height toward the relevant side), just parametrized over which
        // tile now, since the 3×3 block needs one shared vertex per
        // chained wall segment rather than one shared vertex per side.
        func westVertex(col: Int, row: Int) -> CGPoint {
            let center = GroundLayer.grid.point(col: col, row: row)
            return CGPoint(x: center.x - GroundLayer.grid.tileWidth / 2, y: center.y)
        }
        func southVertex(col: Int, row: Int) -> CGPoint {
            let center = GroundLayer.grid.point(col: col, row: row)
            return CGPoint(x: center.x, y: center.y - GroundLayer.grid.tileHeight / 2)
        }
        func northVertex(col: Int, row: Int) -> CGPoint {
            let center = GroundLayer.grid.point(col: col, row: row)
            return CGPoint(x: center.x, y: center.y + GroundLayer.grid.tileHeight / 2)
        }

        // shopWallBackSegments (North->West edge) draw at the lowest
        // zPosition of all four sides: they're the farthest-back side of
        // the block (both its own ends — West here, North where it meets
        // shopWallRightSegments — are shared with sides nearer the
        // camera), so where bounding boxes overlap at either shared
        // corner, the nearer side's art correctly draws on top instead of
        // burying it — same reasoning the original single-tile box used,
        // now applied per side rather than per wall.
        //
        // Tiles (-1,-1), (-1,0), (-1,1) — the West column of the 3×3
        // block — each contribute one North->West edge segment, chained
        // North to South: tile(-1,-1)'s own West vertex is tile(-1,0)'s
        // own North vertex, and so on down to tile(-1,1)'s West vertex,
        // which is the block's own West vertex (see below).
        let backTiles = [(-1, -1), (-1, 0), (-1, 1)]
        for (segment, (col, row)) in zip(shopWallBackSegments, backTiles) {
            segment.position = westVertex(col: col, row: row)
            segment.zPosition = 7
            addChild(segment)
        }

        // Tiles (-1,1), (0,1), (1,1) — the South row of the 3×3 block —
        // each contribute one West->South edge segment, chained West to
        // East: tile(-1,1)'s own West vertex is the block's own West
        // vertex (shared with shopWallBackSegments' own last element,
        // above), and tile(-1,1)'s South vertex is tile(0,1)'s own West
        // vertex, and so on to tile(1,1)'s South vertex — the block's own
        // South vertex, shared with shopWallFrontSegments below.
        let leftTiles = [(-1, 1), (0, 1), (1, 1)]
        for (segment, (col, row)) in zip(shopWallLeftSegments, leftTiles) {
            segment.position = westVertex(col: col, row: row)
            segment.zPosition = 10
            addChild(segment)
        }

        // Tiles (1,1), (1,0), (1,-1) — the East row of the 3×3 block —
        // each contribute one South->East edge segment, chained South to
        // North: tile(1,1)'s own South vertex is the block's own South
        // vertex (shared with shopWallLeftSegments' own last element,
        // above), and tile(1,1)'s East vertex is tile(1,0)'s own South
        // vertex, and so on to tile(1,-1)'s East vertex — the block's own
        // East vertex, shared with shopWallRightSegments below.
        let frontTiles = [(1, 1), (1, 0), (1, -1)]
        for (segment, (col, row)) in zip(shopWallFrontSegments, frontTiles) {
            segment.position = southVertex(col: col, row: row)
            segment.zPosition = 11
            addChild(segment)
        }

        // Tiles (-1,-1), (0,-1), (1,-1) — the North column of the 3×3
        // block — each contribute one North->East edge segment, chained
        // West to East: tile(-1,-1)'s own North vertex is the block's own
        // North vertex (shared with shopWallBackSegments' own first
        // element, above), and tile(-1,-1)'s East vertex is tile(0,-1)'s
        // own North vertex, and so on to tile(1,-1)'s East vertex — the
        // block's own East vertex, shared with shopWallFrontSegments'
        // own last element.
        let rightTiles = [(-1, -1), (0, -1), (1, -1)]
        for (segment, (col, row)) in zip(shopWallRightSegments, rightTiles) {
            segment.position = northVertex(col: col, row: row)
            segment.zPosition = 8
            addChild(segment)
        }

        clampCameraPosition()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Ground/field/farmer content itself doesn't depend on screen
        // size anymore — only how far the camera is allowed to pan does
        // (a bigger viewport needs tighter clamping, since more of the
        // world is visible at once around the camera's own position).
        clampCameraPosition()
    }

    /// Keeps `cameraNode` within `GroundLayer.worldBounds`, inset by half
    /// the current viewport on each axis — so the camera can approach the
    /// ground's edge but never scroll far enough to reveal empty space
    /// beyond the last tile. If the ground is narrower/shorter than the
    /// viewport on some axis (a small map on a big screen), that axis
    /// collapses to the ground's own center instead of an invalid range.
    private func clampCameraPosition() {
        cameraNode.position = GroundLayer.clampedCameraPosition(cameraNode.position, viewportSize: size)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = touches.first?.location(in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let last = lastPanLocation else { return }
        let location = touch.location(in: self)
        // Dragging the finger right/up should reveal ground to the
        // left/below (the content follows the finger, standard map-drag
        // feel), so the camera moves *opposite* the drag delta.
        cameraNode.position = CGPoint(
            x: cameraNode.position.x - (location.x - last.x),
            y: cameraNode.position.y - (location.y - last.y)
        )
        clampCameraPosition()
        lastPanLocation = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = nil
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let delta = min(rawDelta, Self.maxDelta)
        lastUpdateTime = currentTime

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            store.tick(deltaTime: delta)
        }
    }
}
