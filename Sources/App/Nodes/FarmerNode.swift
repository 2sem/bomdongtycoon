import SpriteKit

/// One decorative farmer figure standing behind each column of the field crop patch,
/// as if tending that column. Purely visual for now — not wired to any farm/staff hire state.
final class FarmerLayer: SKNode {

    private static let textureName = "staff_farmer"

    func layout(for sceneSize: CGSize) {
        removeAllChildren()

        // Mirror FieldLayer's row/column band computation exactly so each farmer lands
        // behind the same patch of crops rather than drifting independently as the scene
        // resizes. See FieldLayerNode.swift for the reasoning behind this formula.
        let visibleRows = Int(ceil(sceneSize.height / GroundTile.height))
        let startRow = max(0, (visibleRows - FieldLayer.rowCount) / 2)

        let middleRowIndex = startRow + FieldLayer.rowCount / 2
        let representativeSkew = GroundTile.skew * CGFloat(middleRowIndex)
        let fieldWidth = CGFloat(FieldLayer.columnCount) * GroundTile.width
        let rightMargin = GroundTile.width
        let desiredLeftX = sceneSize.width - rightMargin - fieldWidth
        let fieldStartColumn = Int((desiredLeftX - representativeSkew) / GroundTile.width)

        // GroundLayer/FieldLayer place a larger rowIndex higher on screen (further from the
        // viewer, toward the back of the isometric grid). FieldLayer's crop rows occupy
        // rowOffset 0..<rowCount (rowIndex startRow...startRow+rowCount-1), so standing one
        // row further back than the field's furthest crop row means rowOffset == rowCount.
        let farmerRowOffset = FieldLayer.rowCount
        let rowIndex = startRow + farmerRowOffset

        // Source art is a square canvas; scale it to read as a standing figure roughly
        // three tile-heights tall against the shallow isometric ground tiles, preserving
        // the source image's own aspect ratio.
        let texture = SKTexture(imageNamed: Self.textureName)
        let aspect = texture.size().width / texture.size().height
        let desiredHeight = GroundTile.height * 3
        let farmerSize = CGSize(width: desiredHeight * aspect, height: desiredHeight)

        for columnOffset in 0..<FieldLayer.columnCount {
            let column = fieldStartColumn + columnOffset

            let farmer = SKSpriteNode(texture: texture)
            farmer.size = farmerSize

            // Anchor at the sprite's feet so `position` lands on the tile surface rather
            // than the sprite's visual center.
            farmer.anchorPoint = CGPoint(x: 0.5, y: 0)

            // Same placement formula as GroundLayer/FieldLayer, offset to the tile's center.
            let tileOriginX = CGFloat(column) * GroundTile.width + GroundTile.skew * CGFloat(rowIndex)
            let tileOriginY = CGFloat(rowIndex) * GroundTile.height

            farmer.position = CGPoint(
                x: tileOriginX + GroundTile.width / 2 + GroundTile.skew / 2,
                y: tileOriginY + GroundTile.height / 2
            )

            // Match FieldLayer's local zPosition convention (rowCount - rowOffset) so the
            // farmer, standing one row behind the field's back row, always resolves to a
            // lower local zPosition than every crop row's plots (which range from
            // rowCount - (rowCount - 1) = 1 up to rowCount for rowOffset 0..<rowCount) and
            // therefore draws behind them rather than covering the plots it's tending.
            // FarmerLayer and FieldLayer share the same base zPosition (set in
            // MainStallScene), so this local offset compares directly against FieldLayer's.
            farmer.zPosition = CGFloat(FieldLayer.rowCount - farmerRowOffset)

            addChild(farmer)
        }
    }
}
