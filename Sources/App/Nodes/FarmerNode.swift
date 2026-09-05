import SpriteKit

/// A decorative farmer figure standing beside the field crop patch.
/// Purely visual for now — not wired to any farm/staff hire state.
final class FarmerNode: SKSpriteNode {

    init() {
        let texture = SKTexture(imageNamed: "staff_farmer")
        super.init(texture: texture, color: .clear, size: texture.size())

        // Source art is a square canvas; scale it to read as a standing figure roughly
        // three tile-heights tall against the shallow isometric ground tiles, preserving
        // the source image's own aspect ratio.
        let desiredHeight = GroundTile.height * 3
        let aspect = texture.size().width / texture.size().height
        size = CGSize(width: desiredHeight * aspect, height: desiredHeight)

        // Anchor at the sprite's feet so `position` in layout(for:) lands on the tile
        // surface rather than the sprite's visual center.
        anchorPoint = CGPoint(x: 0.5, y: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(for sceneSize: CGSize) {
        // Mirror FieldLayer's row/column band computation exactly so the farmer lands
        // beside the same patch of crops rather than drifting independently as the
        // scene resizes. See FieldLayerNode.swift for the reasoning behind this formula.
        let visibleRows = Int(ceil(sceneSize.height / GroundTile.height))
        let startRow = max(0, (visibleRows - FieldLayer.rowCount) / 2)

        let middleRowIndex = startRow + FieldLayer.rowCount / 2
        let representativeSkew = GroundTile.skew * CGFloat(middleRowIndex)
        let fieldWidth = CGFloat(FieldLayer.columnCount) * GroundTile.width
        let rightMargin = GroundTile.width
        let desiredLeftX = sceneSize.width - rightMargin - fieldWidth
        let fieldStartColumn = Int((desiredLeftX - representativeSkew) / GroundTile.width)

        // Stand one tile west of the field patch, on its front row, so the farmer reads
        // as tending the crops rather than floating apart from them.
        let rowOffset = 0
        let rowIndex = startRow + rowOffset
        let column = fieldStartColumn - 1

        // Same placement formula as GroundLayer/FieldLayer.
        let tileOriginX = CGFloat(column) * GroundTile.width + GroundTile.skew * CGFloat(rowIndex)
        let tileOriginY = CGFloat(rowIndex) * GroundTile.height

        position = CGPoint(
            x: tileOriginX + GroundTile.width / 2 + GroundTile.skew / 2,
            y: tileOriginY + GroundTile.height / 2
        )

        // Match FieldLayer's local zPosition convention (a small positive offset scaled
        // by its own rowCount) so the farmer depth-sorts correctly among the crop rows
        // instead of unconditionally in front of or behind all of them. FarmerNode and
        // FieldLayer's plots share the same base zPosition (set in MainStallScene), so
        // using FieldLayer.rowCount here keeps both node trees on the same local scale.
        zPosition = CGFloat(FieldLayer.rowCount - rowOffset)
    }
}
