import SpriteKit

/// A roofless 3-wall shell (back + west + east) representing the shop building shell.
/// Sits on the same tile-grid "shelf" as `FieldLayer`, immediately west of it, with a
/// visible gap in between. Deliberately has no front (south) wall and no roof/ceiling so
/// the interior stays visible from the camera — counter/kitchen/staff come in later PRs.
///
/// Purely visual for now — not wired to any gameplay/farm/shop state.
final class ShopWallLayer: SKNode {

    private static let textureName = "shop_wall_wood"

    // Same row depth as FieldLayer so the shop reads as sitting on the same "shelf" as
    // the field, just further along the row band.
    //
    // NOTE on viewport fit: FieldLayer's right-anchored margin + width alone already
    // consumes most of a portrait phone screen's width, so at this column count the
    // shop's west wall (and part of the back wall) render off the left edge of the
    // current viewport — the east wall and the gap before the field stay on screen. This
    // mirrors the existing precedent where the field's own back-right crop already clips
    // at the screen's right edge. The design brief's "fit on one screen" goal targets the
    // *final* 8-element composition (once customers/counter/kitchen exist too) and is
    // expected to need a dedicated camera/scale pass then, not at each intermediate PR.
    private static let columnCount = 5
    private static let rowCount = FieldLayer.rowCount

    // At least one empty tile column between the shop's east wall and the field's west edge.
    private static let gapColumns = 1

    // Building walls read taller than the farmer figure (GroundTile.height * 3) so the
    // shell feels architectural rather than person-scaled.
    private static let wallHeight = GroundTile.height * 3.5
    private static let sideWallWidth = GroundTile.width * 0.4

    func layout(for size: CGSize) {
        removeAllChildren()

        // Anchor to the same row band FieldLayer uses, then place the shop's footprint
        // immediately west of the field with a visible gap, mirroring how FarmerLayer
        // reuses this same formula instead of duplicating it.
        let (fieldStartRow, fieldStartColumn) = FieldLayer.layoutMetrics(for: size)
        let shopStartRow = fieldStartRow
        let shopStartColumn = fieldStartColumn - Self.gapColumns - Self.columnCount

        let texture = SKTexture(imageNamed: Self.textureName)

        // The footprint occupies rowOffset 0..<rowCount (rowIndex shopStartRow...
        // shopStartRow + rowCount - 1). As with GroundLayer/FieldLayer, a larger rowIndex
        // sits higher on screen (further back). zPosition is depth-sorted with a small
        // LOCAL offset — relative to ShopWallLayer's own base zPosition set by the scene —
        // so the further-back back wall draws behind the side walls, which lead with the
        // shop's front (south) row closest to the camera.
        let localZSpan = CGFloat(Self.rowCount + 1)

        addChild(makeBackWall(texture: texture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, localZSpan: localZSpan))
        let sideWalls = makeSideWalls(texture: texture, shopStartRow: shopStartRow, shopStartColumn: shopStartColumn, localZSpan: localZSpan)
        addChild(sideWalls.west)
        addChild(sideWalls.east)
    }

    /// One wide sprite spanning the shop's full column width, standing one row further
    /// back than the footprint's own back row — mirroring how FarmerLayer stands one row
    /// behind FieldLayer's back row (`rowOffset = rowCount`).
    private func makeBackWall(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, localZSpan: CGFloat) -> SKSpriteNode {
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

        // Furthest-back piece of the shell: lowest local zPosition so it draws behind
        // the side walls (and, via ShopWallLayer's shared base zPosition with
        // fieldLayer/farmerLayer, still above the ground plane).
        wall.zPosition = localZSpan - CGFloat(backRowOffset)

        return wall
    }

    /// West/east walls each span the footprint's row depth (front row to the footprint's
    /// own back row, NOT the extra row the back wall stands on) along their respective
    /// column edge. Kept as a single flat rectangular sprite per the codebase's existing
    /// "flat sprite standing on the tile grid" convention (see FarmerLayer) rather than
    /// true skewed geometry.
    private func makeSideWalls(texture: SKTexture, shopStartRow: Int, shopStartColumn: Int, localZSpan: CGFloat) -> (west: SKSpriteNode, east: SKSpriteNode) {
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

        // Side walls lead with the front row, so they resolve to a higher local
        // zPosition than the back wall (which stands at rowOffset == rowCount) and than
        // every footprint crop/tile row, matching the "front draws over back" convention.
        let zPosition = localZSpan

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
