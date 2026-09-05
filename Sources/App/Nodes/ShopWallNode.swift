import SpriteKit

/// A roofless 3-wall shell (back + west + east) representing the shop building shell.
/// Sits directly in front of `FieldLayer` — i.e. toward the camera, at a smaller row
/// index than the field's own footprint — aligned to the same columns as the field, with
/// a small visible gap between the shop's back wall and the field's front edge. This
/// matches the front-to-back composition order "customers -> shop -> field": the field is
/// the furthest-back element and the shop stands stacked in front of it along the row
/// (depth) axis, not offset sideways along the column axis. Deliberately has no front
/// (south) wall and no roof/ceiling so the interior stays visible from the camera —
/// counter/kitchen/staff come in later PRs.
///
/// Purely visual for now — not wired to any gameplay/farm/shop state.
final class ShopWallLayer: SKNode {

    private static let backWallTextureName = "shop_wall_wood"

    // Same column width as FieldLayer so the shop's footprint aligns directly under the
    // field, column-for-column, instead of drifting sideways. Not private: CounterLayer
    // (and other future interior layers) reuse these to size themselves against the shop's
    // own footprint instead of duplicating the constants.
    static let columnCount = FieldLayer.columnCount
    static let rowCount = FieldLayer.rowCount

    // At least one empty tile row between the shop's back wall and the field's front edge.
    private static let gapRows = 1

    // Building walls read taller than the farmer figure (GroundTile.height * 3) so the
    // shell feels architectural rather than person-scaled.
    private static let wallHeight = GroundTile.height * 3.5

    // Small repeated wall-panel unit size for the back wall, mirroring GroundTile's "many
    // small tiles" construction instead of one stretched image. Sized on the order of
    // GroundTile.width so an individual panel reads at a believable plank scale next to the
    // crops and farmers already on screen (vertical-grain plank look: slightly taller than
    // wide). The side walls no longer use a desired-tile-size grid — their tile unit is one
    // parallelogram course per row-to-row step, subdivided only along wall height (see
    // `sideWallCourseCount`), since their width/depth unit is fixed by the ground's own skew.
    private static let backWallTileSize = CGSize(width: GroundTile.width / 2, height: GroundTile.width / 2 * 1.25)

    // Number of stacked parallelogram "courses" per side-wall row segment, matching the
    // vertical tile density the back wall's own plank panels read at (wallHeight /
    // backWallTileSize.height is roughly 4-5; 3 keeps side-wall courses a bit chunkier/taller
    // than back-wall planks, which still reads fine given the side wall's narrower face).
    private static let sideWallCourseCount = 3

    /// Computes the shop shell's own footprint origin (front row, west column), anchored to
    /// `FieldLayer`'s columns with a visible row gap in front of the field's own footprint.
    /// Exposed as `static` so sibling layers that need to sit inside the shop (the counter,
    /// the cashier, the kitchen/cook in later PRs) can reuse this exact placement math
    /// instead of duplicating it — mirroring how `FieldLayer.layoutMetrics` is itself reused
    /// here.
    static func layoutMetrics(for size: CGSize) -> (startRow: Int, startColumn: Int) {
        let (fieldStartRow, fieldStartColumn) = FieldLayer.layoutMetrics(for: size)
        let shopStartColumn = fieldStartColumn
        let shopStartRow = fieldStartRow - Self.gapRows - Self.rowCount
        return (shopStartRow, shopStartColumn)
    }

    func layout(for size: CGSize) {
        removeAllChildren()

        // Anchor to the field's own columns, then place the shop's footprint immediately
        // south of (in front of) the field with a visible row gap, mirroring how
        // FarmerLayer reuses this same formula instead of duplicating it.
        let (fieldStartRow, _) = FieldLayer.layoutMetrics(for: size)
        let (shopStartRow, shopStartColumn) = Self.layoutMetrics(for: size)

        // Side walls deliberately reuse the back wall's vertical-grain plank texture rather
        // than a dedicated horizontal-grain one: SKShapeNode's fillTexture shears along with
        // the shape's own geometry, and on these tall, heavily-slanted parallelogram
        // segments a horizontal-grain/block texture's strong horizontal lines shear into an
        // ugly diagonal zigzag/chevron. Vertical grain lines stay close to vertical under
        // this same shear, so they read correctly on the tilted side walls.
        let backTexture = SKTexture(imageNamed: Self.backWallTextureName)

        addChild(makeBackWall(texture: backTexture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, fieldStartRow: fieldStartRow))
        let sideWalls = makeSideWalls(texture: backTexture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, fieldStartRow: fieldStartRow)
        addChild(sideWalls.west)
        addChild(sideWalls.east)
    }

    /// Shares FieldLayer/FarmerLayer's zPosition convention rather than a span scoped only
    /// to the shop's own rows: `FieldLayer.rowCount - (rowIndex - fieldStartRow)`. This is
    /// the same formula FieldLayer applies to its own rows (rowIndex - fieldStartRow ==
    /// rowOffset) and FarmerLayer applies to the row behind the field, so every layer that
    /// shares ShopWallLayer's base zPosition (10, set in MainStallScene) sorts correctly
    /// against FieldLayer's plots — a row index smaller than the field's (closer to the
    /// camera, as the shop's rows are) resolves to a HIGHER value than any field row, so
    /// the shop's walls always draw in front of (occlude) the field where their tall
    /// sprites visually overlap it, instead of being scoped independently and coincidentally
    /// tying or losing against the field's own local zPositions.
    static func zPosition(forRowIndex rowIndex: Int, fieldStartRow: Int) -> CGFloat {
        CGFloat(FieldLayer.rowCount + fieldStartRow - rowIndex)
    }

    /// A grid of small repeated wall-panel sprites spanning the shop's full column width,
    /// standing one row further back than the footprint's own back row — mirroring how
    /// FarmerLayer stands one row behind FieldLayer's back row (`rowOffset = rowCount`).
    /// With the shop now placed in front of the field, this back-wall row lands exactly
    /// `gapRows` rows before the field's own front row, giving a small but clear visible gap.
    ///
    /// Built the same way `GroundLayer` builds the floor — many small repeated tile units
    /// rather than one image stretched across the whole face — so the wall reads as
    /// "constructed" with visible panel seams instead of a single smooth stretched panel.
    private func makeBackWall(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, fieldStartRow: Int) -> SKNode {
        let backRowOffset = Self.rowCount
        let backRowIndex = shopStartRow + backRowOffset

        let leftOriginX = CGFloat(shopStartColumn) * GroundTile.width + GroundTile.skew * CGFloat(backRowIndex)
        let originY = CGFloat(backRowIndex) * GroundTile.height

        let size = CGSize(width: CGFloat(Self.columnCount) * GroundTile.width, height: Self.wallHeight)
        let wall = Self.makeTiledWallFace(texture: texture, size: size, desiredTileSize: Self.backWallTileSize)

        // Bottom-center anchor: `position.x` must land at the horizontal midpoint between
        // the west and east side walls' exact terminal corner points (leftOriginX and
        // leftOriginX + columnCount*width), and `position.y` must land exactly at those
        // walls' terminal row's ground line (originY) — not offset by half a tile in either
        // axis, which previously left a diagonal gap at both corners where the back wall met
        // each side wall.
        wall.position = CGPoint(
            x: leftOriginX + CGFloat(Self.columnCount) * GroundTile.width / 2,
            y: originY
        )

        wall.zPosition = Self.zPosition(forRowIndex: backRowIndex, fieldStartRow: fieldStartRow)

        return wall
    }

    /// West/east walls each span the footprint's row depth (front row through the row where
    /// the back wall stands) along their respective column edge. On this isometric-look
    /// grid, moving from row `r` to row `r+1` shifts a ground point by exactly
    /// `(GroundTile.skew, GroundTile.height)` — a fixed diagonal step, not straight up — the
    /// same relationship that makes `GroundTile.path` a parallelogram instead of a rectangle
    /// so consecutive ground tiles share an edge exactly. A side wall needs the same
    /// property: each row-to-row step is built as one TILTED PARALLELOGRAM segment (two
    /// vertical edges for wall height, two slanted edges matching the ground's skew for
    /// depth), so segment `r`'s far edge coincides exactly with segment `r+1`'s near edge,
    /// closing every seam. Each segment is itself subdivided into a few stacked parallelogram
    /// "courses" so the wall still reads as built from small tiled units, matching the back
    /// wall's construction, instead of one smooth tilted panel.
    private func makeSideWalls(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, fieldStartRow: Int) -> (west: SKNode, east: SKNode) {
        let frontRowIndex = shopStartRow
        let footprintBackRowIndex = shopStartRow + Self.rowCount - 1

        let westColumn = shopStartColumn
        let eastColumn = shopStartColumn + Self.columnCount

        let west = SKNode()
        let east = SKNode()

        // One segment per row-to-row step, from the front row through the footprint's back
        // row inclusive — rowCount segments total, so the wall's far end lands exactly at
        // `shopStartRow + rowCount`, the same row the back wall stands on, closing the corner
        // with no gap.
        for rowIndex in frontRowIndex..<(footprintBackRowIndex + 1) {
            let rowZPosition = Self.zPosition(forRowIndex: rowIndex, fieldStartRow: fieldStartRow)

            // The segment's local origin (0,0) IS this row's exact ground-line point — no
            // center-anchor offset needed, unlike the old rectangular-panel approach.
            let westX = CGFloat(westColumn) * GroundTile.width + GroundTile.skew * CGFloat(rowIndex)
            let westY = CGFloat(rowIndex) * GroundTile.height
            let westSegment = Self.makeTiltedWallSegment(texture: texture, courseCount: Self.sideWallCourseCount)
            westSegment.position = CGPoint(x: westX, y: westY)
            westSegment.zPosition = rowZPosition
            west.addChild(westSegment)

            let eastX = CGFloat(eastColumn) * GroundTile.width + GroundTile.skew * CGFloat(rowIndex)
            let eastY = CGFloat(rowIndex) * GroundTile.height
            let eastSegment = Self.makeTiltedWallSegment(texture: texture, courseCount: Self.sideWallCourseCount)
            eastSegment.position = CGPoint(x: eastX, y: eastY)
            eastSegment.zPosition = rowZPosition
            east.addChild(eastSegment)
        }

        return (west, east)
    }

    /// A single row-to-row parallelogram wall segment's outline: vertices `(0,0)` (bottom,
    /// this row's ground point), `(GroundTile.skew, GroundTile.height)` (bottom, next row's
    /// ground point), `(GroundTile.skew, GroundTile.height + segmentHeight)` (top, next row),
    /// `(0, segmentHeight)` (top, this row). The bottom and top edges both carry the ground's
    /// `(skew, height)` diagonal step while the left/right edges stay perfectly vertical
    /// (`segmentHeight` tall, no skew) — mirroring `GroundTile.path`'s parallelogram
    /// construction, extruded upward by wall height instead of flat on the ground.
    private static func wallSegmentPath(segmentHeight: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: GroundTile.skew, y: GroundTile.height))
        path.addLine(to: CGPoint(x: GroundTile.skew, y: GroundTile.height + segmentHeight))
        path.addLine(to: CGPoint(x: 0, y: segmentHeight))
        path.closeSubpath()
        return path
    }

    /// Stacks `courseCount` small tilted-parallelogram "courses" vertically to fill
    /// `wallHeight`, each an `SKShapeNode` built from `wallSegmentPath`, textured and
    /// stroked the same way `makeTiledWallFace`'s rectangular tiles are. Unlike
    /// `makeTiledWallFace`, this only subdivides along the height axis — the depth axis
    /// (the row-to-row step) is already the smallest unit this wall is built at, one
    /// segment per row.
    private static func makeTiltedWallSegment(texture: SKTexture, courseCount: Int) -> SKNode {
        let container = SKNode()

        let segmentHeight = Self.wallHeight / CGFloat(courseCount)
        let coursePath = wallSegmentPath(segmentHeight: segmentHeight)

        for course in 0..<courseCount {
            let tile = SKShapeNode(path: coursePath)
            tile.fillTexture = texture
            tile.fillColor = .white
            tile.strokeColor = GroundTile.strokeColor
            tile.lineWidth = 1
            tile.position = CGPoint(x: 0, y: CGFloat(course) * segmentHeight)
            container.addChild(tile)
        }

        return container
    }

    /// Builds a flat rectangular wall face out of a grid of small repeated tile sprites
    /// instead of one image stretched across the whole face — mirroring how `GroundLayer`
    /// builds the floor from many small `GroundTile` units rather than a single stretched
    /// texture, so the wall reads as "constructed" with visible panel seams.
    ///
    /// Each tile is an `SKShapeNode` with `fillTexture`/`fillColor = .white` plus a stroked
    /// border, the exact same drawing recipe `GroundLayer` uses per `GroundTile` — without a
    /// stroke, the plank texture repeats seamlessly across tile boundaries and the seams the
    /// user asked for (matching the ground's visible grid lines) don't actually show up.
    ///
    /// The returned container uses the same bottom-center anchor convention a single
    /// `SKSpriteNode` with `anchorPoint = (0.5, 0)` would have used (local x spans
    /// `-size.width/2 ... size.width/2`, local y spans `0 ... size.height`), so callers can
    /// position/zPosition it exactly as they did the old single-sprite wall. Tile counts are
    /// rounded to the nearest whole tile per axis and the tile size is stretched slightly to
    /// fill the face exactly, so panels tile edge-to-edge with no gap or overshoot.
    private static func makeTiledWallFace(texture: SKTexture, size: CGSize, desiredTileSize: CGSize) -> SKNode {
        let container = SKNode()

        let columns = max(1, Int((size.width / desiredTileSize.width).rounded()))
        let rows = max(1, Int((size.height / desiredTileSize.height).rounded()))
        let tileWidth = size.width / CGFloat(columns)
        let tileHeight = size.height / CGFloat(rows)
        let tileRect = CGRect(x: -tileWidth / 2, y: 0, width: tileWidth, height: tileHeight)

        for row in 0..<rows {
            for column in 0..<columns {
                let tile = SKShapeNode(rect: tileRect)
                tile.fillTexture = texture
                tile.fillColor = .white
                tile.strokeColor = GroundTile.strokeColor
                tile.lineWidth = 1
                tile.position = CGPoint(
                    x: (CGFloat(column) + 0.5) * tileWidth - size.width / 2,
                    y: CGFloat(row) * tileHeight
                )
                container.addChild(tile)
            }
        }

        return container
    }
}
