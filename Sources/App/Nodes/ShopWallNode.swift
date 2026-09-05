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

    /// One wide sprite spanning the shop's full column width, standing one row further
    /// back than the footprint's own back row — mirroring how FarmerLayer stands one row
    /// behind FieldLayer's back row (`rowOffset = rowCount`). With the shop now placed in
    /// front of the field, this back-wall row lands exactly `gapRows` rows before the
    /// field's own front row, giving a small but clear visible gap.
    private func makeBackWall(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, fieldStartRow: Int) -> SKSpriteNode {
        let backRowOffset = Self.rowCount
        let backRowIndex = shopStartRow + backRowOffset

        let leftOriginX = CGFloat(shopStartColumn) * GroundTile.width + GroundTile.skew * CGFloat(backRowIndex)
        let originY = CGFloat(backRowIndex) * GroundTile.height

        let wall = SKSpriteNode(texture: texture)
        wall.size = CGSize(width: CGFloat(Self.columnCount) * GroundTile.width, height: Self.wallHeight)

        // Anchor at the sprite's bottom-center so `position` lands on the row's tile line
        // rather than the sprite's visual center, same convention as FarmerLayer.
        wall.anchorPoint = CGPoint(x: 0.5, y: 0)
        wall.position = CGPoint(
            x: leftOriginX + CGFloat(Self.columnCount) * GroundTile.width / 2 + GroundTile.skew / 2,
            y: originY + GroundTile.height / 2
        )

        wall.zPosition = Self.zPosition(forRowIndex: backRowIndex, fieldStartRow: fieldStartRow)

        return wall
    }

    /// West/east walls each span the footprint's row depth (front row to the footprint's
    /// own back row, NOT the extra row the back wall stands on) along their respective
    /// column edge. Kept as a single flat rectangular sprite per the codebase's existing
    /// "flat sprite standing on the tile grid" convention (see FarmerLayer) rather than
    /// true skewed geometry.
    private func makeSideWalls(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, fieldStartRow: Int) -> (west: SKSpriteNode, east: SKSpriteNode) {
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

        let west = SKSpriteNode(texture: texture)
        west.size = size
        west.anchorPoint = CGPoint(x: 0.5, y: 0)
        west.position = CGPoint(x: (westFrontX + westBackX) / 2, y: frontY)
        west.zPosition = zPosition

        let east = SKSpriteNode(texture: texture)
        east.size = size
        east.anchorPoint = CGPoint(x: 0.5, y: 0)
        east.position = CGPoint(x: (eastFrontX + eastBackX) / 2, y: frontY)
        east.zPosition = zPosition

        return (west, east)
    }
}
