import SpriteKit
import SwiftUI

/// A 3×3 block of shop tiles with the four wall pieces run along its whole
/// perimeter — three segments a side instead of the single segment the real
/// shop uses at its current 1×1 footprint.
///
/// This exists to look at the wall set as a *set*: a single wall per side
/// hides the two things that actually go wrong when the shop grows, and both
/// only show up once segments sit next to each other.
///
/// 1. **Seams between neighbours on the same side.** Each wall is fitted to
///    one cell's half-diagonal edge, so three in a row should meet corner to
///    corner with no gap and no overlap. Any error in a wall's own measured
///    depth vector repeats and accumulates along the side.
/// 2. **Draw order at shared corners.** Walls all sit on one tile in
///    `MainStallScene`, which lets it hand-assign four z values (back 7,
///    right 8, left 10, front 11). Across nine cells that no longer works —
///    order has to come from the grid, which is what `zPosition(for:)`
///    below does.
///
/// The preview builds on `GroundLayer.grid`, not an isolated grid, because
/// seams are exactly what it is for: the tuning has to be the real one.
private final class ShopWallsPreviewScene: SKScene {

    /// Cells the shop covers, as `(col, row)` — a 3×3 block anchored at the
    /// real shop's own cell, `(0, 0)`.
    private static let span = 0..<3

    /// Painter's order within a cell. Walls share their cell with the ground
    /// tile and with each other, so each gets a slot above the tile: the two
    /// far walls (back, right) draw first so that where bounding boxes meet
    /// at a shared vertex, the wall nearer the camera wins — the same
    /// relationship `MainStallScene` encodes with its 7/8/10/11 constants.
    private enum Slot: CGFloat {
        case ground = 0
        case back = 1
        case right = 2
        case left = 3
        case front = 4
    }

    private static func zPosition(col: Int, row: Int, slot: Slot) -> CGFloat {
        CGFloat(col + row) * 10 + slot.rawValue
    }

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor

        let camera = SKCameraNode()
        self.camera = camera
        addChild(camera)

        let grid = GroundLayer.grid
        buildGround(on: grid)
        buildWalls(on: grid)

        // Frame the block: its center cell, lifted so the walls' height sits
        // in view rather than running off the top.
        let center = grid.point(col: 1, row: 1)
        camera.position = CGPoint(x: center.x, y: center.y + grid.tileHeight)
    }

    private func buildGround(on grid: IsoGrid) {
        for col in Self.span {
            for row in Self.span {
                let tile = ShopGroundTileNode(fittingTo: grid)
                tile.position = grid.point(col: col, row: row)
                tile.zPosition = Self.zPosition(col: col, row: row, slot: .ground)
                addChild(tile)
            }
        }
    }

    private func buildWalls(on grid: IsoGrid) {
        let first = Self.span.lowerBound
        let last = Self.span.upperBound - 1

        for index in Self.span {
            // South-west side: the West→South edge of every cell in the last
            // row. Anchors on that cell's own West vertex.
            let leftWall = ShopWallLeftNode(fittingTo: grid)
            leftWall.position = westVertex(col: index, row: last, on: grid)
            leftWall.zPosition = Self.zPosition(col: index, row: last, slot: .left)
            addChild(leftWall)

            // South-east side: the South→East edge of every cell in the last
            // column, anchored on that cell's South vertex.
            let frontWall = ShopWallFrontNode(fittingTo: grid)
            frontWall.position = southVertex(col: last, row: index, on: grid)
            frontWall.zPosition = Self.zPosition(col: last, row: index, slot: .front)
            addChild(frontWall)

            // North-west side: the North→West edge of every cell in the
            // first column, anchored on that cell's West vertex.
            let backWall = ShopWallBackNode(fittingTo: grid)
            backWall.position = westVertex(col: first, row: index, on: grid)
            backWall.zPosition = Self.zPosition(col: first, row: index, slot: .back)
            addChild(backWall)

            // North-east side: the North→East edge of every cell in the
            // first row, anchored on that cell's North vertex.
            let rightWall = ShopWallRightNode(fittingTo: grid)
            rightWall.position = northVertex(col: index, row: first, on: grid)
            rightWall.zPosition = Self.zPosition(col: index, row: first, slot: .right)
            addChild(rightWall)
        }
    }

    // A cell's own diamond vertices, in the same terms
    // `MainStallScene` uses for the single shop tile.

    private func westVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x - grid.tileWidth / 2, y: center.y)
    }

    private func southVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x, y: center.y - grid.tileHeight / 2)
    }

    private func northVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x, y: center.y + grid.tileHeight / 2)
    }
}

#Preview("Shop Walls 3×3") {
    let scene = ShopWallsPreviewScene(size: CGSize(width: 400, height: 700))
    scene.scaleMode = .resizeFill
    return SpriteView(scene: scene)
        .frame(width: 400, height: 700)
        .ignoresSafeArea()
}
