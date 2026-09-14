import SpriteKit
import SwiftUI

/// A 3×3 block of shop tiles with the four wall pieces run along its whole
/// perimeter — three segments a side, to look at the wall set as a *set*:
/// a single wall per side (the shop's old 1×1 footprint) hides the two
/// things that actually go wrong once the shop grows and segments sit
/// next to each other (seams between neighbours on the same side, and
/// draw order at shared corners) — see `ShopNode`'s own doc comment for
/// how those are handled now.
///
/// This originally built its own 3×3 layout by hand (the geometry
/// `ShopNode.buildGround`/`buildWalls` are lifted from) before the shop's
/// footprint became configurable; now that `ShopNode` does that generally,
/// this preview just builds one at the legacy shop cell's own position
/// and a square 3×3 size, rather than duplicating the layout a second
/// time.
private final class ShopWallsPreviewScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor

        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)

        let grid = GroundLayer.grid

        // originX: 2, originY: 7 are map-array-index coordinates — the
        // legacy single shop cell's own position in `GroundLayer.map`
        // (row 7, col 2) — which `GroundLayer.gridCoordinate(rowIndex:
        // colIndex:)` resolves to `IsoGrid` (0, 0), the same anchor this
        // preview has always used. width/height: 3 keeps the square 3×3
        // shape the seam/draw-order checks above need, independent of
        // whatever the real shop's own current size is (3×3 today).
        // openings: [] — this preview's whole point is the full,
        // unbroken wall ring (see the seam/draw-order checks above), not
        // the live shop's east-side gap (`ShopNode.defaultOpenings`).
        let shop = ShopNode(originX: 2, originY: 7, width: 3, height: 3, openings: [], fittingTo: grid)
        addChild(shop)

        // Frame the block: its center cell, lifted so the walls' height sits
        // in view rather than running off the top.
        let center = grid.point(col: 1, row: 1)
        camera.position = CGPoint(x: center.x, y: center.y + grid.tileHeight)
    }
}

#Preview("Shop Walls 3×3") {
    let scene = ShopWallsPreviewScene(size: CGSize(width: 400, height: 700))
    scene.scaleMode = .resizeFill
    return SpriteView(scene: scene)
        .frame(width: 400, height: 700)
        .ignoresSafeArea()
}
