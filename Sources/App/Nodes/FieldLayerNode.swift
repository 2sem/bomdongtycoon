import SpriteKit

/// A patch of crop plots standing on `GroundLayer`'s field-tile ground,
/// north of (behind) the grass placeholder tile.
///
/// KNOWN LIMITATION, deliberately left as-is for now: on `IsoGrid`,
/// `screenX = (col - row) × tileWidth / 2` — so retreating "north" by
/// decrementing `row` alone (what this patch does, holding `startColumn`
/// fixed across every row) moves diagonally on screen, not straight up.
/// That's correct/expected isometric geometry (the diamond's own edge
/// direction), not a bug — but combined with this patch being several
/// rows deep, it means the full patch's on-screen bounding box currently
/// overflows a single static phone viewport in both x and y. Fixing that
/// needs a real camera/pan (2D — the diagonal retreat direction means a
/// vertical-only scroll wouldn't actually track it), which doesn't exist
/// yet; this patch's own placement math is otherwise correct and doesn't
/// need to change once that camera exists.
///
/// Purely visual for now — not wired to any gameplay/farm state.
final class FieldLayer: SKNode {

    // Not private: FarmerLayer stands one row further north than this
    // patch's own back row, and needs these to line up.
    static let columnCount = 3
    static let rowCount = 3

    /// This patch's fixed `(col, row)` position on `GroundLayer.grid`.
    /// Unlike the old shear-grid version, this isn't computed from the
    /// scene's size — `GroundLayer`'s own patch is itself a small fixed
    /// shape (see `GroundLayerNode.swift`), not something that grows to
    /// fill the viewport, so this patch's place within it is just as
    /// fixed. `startRow` is negative (north) of `GroundLayer`'s grass
    /// placeholder at row 0: row -1 is the field-tile "walkway" row
    /// (`GroundLayer`'s own ring), so the crop patch's back-most row
    /// leaves that row free and starts at -2, running further north for
    /// `rowCount` rows.
    static let startColumn = -1
    static let startRow = -(1 + rowCount)

    /// Compatibility shim for `ShopWallLayer`/`KitchenLayer` (still on the
    /// old shear-grid system, not yet ported — their art isn't ready for
    /// the new isometric style). They call this expecting the old
    /// screen-size-dependent signature; `size` is ignored since this
    /// patch's position is a fixed constant now, not computed from it.
    /// Remove once those two are ported onto `IsoGrid` and can read
    /// `startRow`/`startColumn` directly like `FarmerLayer` does.
    static func layoutMetrics(for size: CGSize) -> (startRow: Int, startColumn: Int) {
        (startRow, startColumn)
    }

    private static let cropTextureNames = [
        "crop_sprout",
        "crop_growing",
        "produce_cabbage"
    ]

    /// Crop art is authored as large square icons (512x512); scale each
    /// down against the shared grid's own tile width so plots read as
    /// small plants on the tile rather than dominating it — mirrors the
    /// old `GroundTile.width * 0.8` ratio, just against the new grid's
    /// (much larger) tile width.
    private static let cropSize: CGSize = {
        let side = GroundLayer.grid.tileWidth * 0.5
        return CGSize(width: side, height: side)
    }()

    func layout(for size: CGSize) {
        removeAllChildren()

        let originOffset = GroundLayer.originOffset(for: size)

        var cropIndex = 0
        for rowOffset in 0..<Self.rowCount {
            let row = Self.startRow + rowOffset
            for columnOffset in 0..<Self.columnCount {
                let col = Self.startColumn + columnOffset

                let plot = SKSpriteNode(imageNamed: Self.cropTextureNames[cropIndex % Self.cropTextureNames.count])
                plot.size = Self.cropSize
                cropIndex += 1

                let point = GroundLayer.grid.point(col: col, row: row)
                // Anchor at the sprite's own bottom-center (default
                // anchorPoint 0.5, 0.5 shifted down by half height) so it
                // reads as standing on the tile surface rather than
                // floating centered on it.
                plot.anchorPoint = CGPoint(x: 0.5, y: 0)
                plot.position = CGPoint(x: point.x + originOffset.x, y: point.y + originOffset.y)

                // Same back-to-front convention GroundLayer's own tiles
                // use, so crops sort correctly against each other (and,
                // sharing the same base zPosition set in MainStallScene,
                // stay safely above every ground tile regardless of row).
                plot.zPosition = CGFloat(col + row)

                addChild(plot)
            }
        }
    }
}
