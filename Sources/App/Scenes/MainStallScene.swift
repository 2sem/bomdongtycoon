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

    /// The shop plot's west side wall — the first piece of the new,
    /// pre-rendered-art shop construction (replacing the disabled, old
    /// procedurally-tiled `shopWallLayer` above once enough pieces exist).
    /// A single static node, not a "layer": it fits itself to
    /// `GroundLayer.grid` once and never needs relaying out.
    private let shopWallLeft = ShopWallLeftNode(fittingTo: GroundLayer.grid)

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

        // The shop plot's West vertex — grid.point(col: 0, row: 0) is the
        // shop tile's own center, offset left by half the grid's tile
        // width lands on its West corner, where this wall's back-bottom
        // corner belongs (see ShopWallLeftNode's anchorPoint).
        shopWallLeft.position = CGPoint(
            x: GroundLayer.grid.point(col: 0, row: 0).x - GroundLayer.grid.tileWidth / 2,
            y: GroundLayer.grid.point(col: 0, row: 0).y
        )
        shopWallLeft.zPosition = 10
        addChild(shopWallLeft)

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
