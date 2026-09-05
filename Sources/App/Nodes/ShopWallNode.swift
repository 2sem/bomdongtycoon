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
    private static let sideWallTextureName = "shop_wall_side_wood"

    // Same column width as FieldLayer so the shop's footprint aligns directly under the
    // field, column-for-column, instead of drifting sideways.
    private static let columnCount = FieldLayer.columnCount
    private static let rowCount = FieldLayer.rowCount

    // At least one empty tile row between the shop's back wall and the field's front edge.
    private static let gapRows = 1

    // Building walls read taller than the farmer figure (GroundTile.height * 3) so the
    // shell feels architectural rather than person-scaled.
    private static let wallHeight = GroundTile.height * 3.5
    private static let sideWallWidth = GroundTile.width * 0.4

    // Small repeated wall-panel unit sizes, mirroring GroundTile's "many small tiles"
    // construction instead of one stretched image. Sized on the order of GroundTile.width
    // so an individual panel reads at a believable plank/block scale next to the crops and
    // farmers already on screen. The back wall's plank panels are slightly taller than wide
    // (vertical-grain plank look); the side walls use square blocks to match their narrow
    // stacked-block texture and thin footprint.
    private static let backWallTileSize = CGSize(width: GroundTile.width / 2, height: GroundTile.width / 2 * 1.25)
    private static let sideWallTileSize = CGSize(width: sideWallWidth, height: sideWallWidth)

    func layout(for size: CGSize) {
        removeAllChildren()

        // Anchor to the field's own columns, then place the shop's footprint immediately
        // south of (in front of) the field with a visible row gap, mirroring how
        // FarmerLayer reuses this same formula instead of duplicating it.
        let (fieldStartRow, fieldStartColumn) = FieldLayer.layoutMetrics(for: size)
        let shopStartColumn = fieldStartColumn
        let shopStartRow = fieldStartRow - Self.gapRows - Self.rowCount

        let backTexture = SKTexture(imageNamed: Self.backWallTextureName)
        let sideTexture = SKTexture(imageNamed: Self.sideWallTextureName)

        addChild(makeBackWall(texture: backTexture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, fieldStartRow: fieldStartRow))
        let sideWalls = makeSideWalls(texture: sideTexture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, fieldStartRow: fieldStartRow)
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
    private static func zPosition(forRowIndex rowIndex: Int, fieldStartRow: Int) -> CGFloat {
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

        // Same bottom-center anchor convention the previous single stretched sprite used,
        // so `position` lands on the row's tile line rather than the face's visual center.
        wall.position = CGPoint(
            x: leftOriginX + CGFloat(Self.columnCount) * GroundTile.width / 2 + GroundTile.skew / 2,
            y: originY + GroundTile.height / 2
        )

        wall.zPosition = Self.zPosition(forRowIndex: backRowIndex, fieldStartRow: fieldStartRow)

        return wall
    }

    /// West/east walls each span the footprint's row depth (front row to the footprint's
    /// own back row, NOT the extra row the back wall stands on) along their respective
    /// column edge. Each face is a grid of small repeated tile sprites (see
    /// `makeTiledWallFace`) standing on the tile grid — same "flat face, no skew" placement
    /// convention as before (see FarmerLayer), just built from many small panels instead of
    /// one stretched sprite.
    private func makeSideWalls(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, fieldStartRow: Int) -> (west: SKNode, east: SKNode) {
        let frontRowIndex = shopStartRow
        let footprintBackRowIndex = shopStartRow + Self.rowCount - 1

        // Tile-center vertical offset (+ height / 2), matching FieldLayer/FarmerLayer's
        // per-tile centering convention.
        let frontY = CGFloat(frontRowIndex) * GroundTile.height + GroundTile.height / 2
        let backY = CGFloat(footprintBackRowIndex) * GroundTile.height + GroundTile.height / 2
        let depthHeight = backY - frontY

        let size = CGSize(width: Self.sideWallWidth, height: depthHeight + Self.wallHeight)

        let westColumn = shopStartColumn
        let westFrontX = CGFloat(westColumn) * GroundTile.width + GroundTile.skew * CGFloat(frontRowIndex)
        let westBackX = CGFloat(westColumn) * GroundTile.width + GroundTile.skew * CGFloat(footprintBackRowIndex)

        let eastColumn = shopStartColumn + Self.columnCount
        let eastFrontX = CGFloat(eastColumn) * GroundTile.width + GroundTile.skew * CGFloat(frontRowIndex)
        let eastBackX = CGFloat(eastColumn) * GroundTile.width + GroundTile.skew * CGFloat(footprintBackRowIndex)

        // Side walls lead with the front row, so they resolve to a higher zPosition than
        // the back wall (which stands at rowOffset == rowCount, one row further back) and
        // than every field row/farmer, matching the "front draws over back" convention.
        let zPosition = Self.zPosition(forRowIndex: frontRowIndex, fieldStartRow: fieldStartRow)

        let west = Self.makeTiledWallFace(texture: texture, size: size, desiredTileSize: Self.sideWallTileSize)
        west.position = CGPoint(x: (westFrontX + westBackX) / 2, y: frontY)
        west.zPosition = zPosition

        let east = Self.makeTiledWallFace(texture: texture, size: size, desiredTileSize: Self.sideWallTileSize)
        east.position = CGPoint(x: (eastFrontX + eastBackX) / 2, y: frontY)
        east.zPosition = zPosition

        return (west, east)
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
