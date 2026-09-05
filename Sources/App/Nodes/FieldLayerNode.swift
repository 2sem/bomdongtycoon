import SpriteKit

/// A decorative patch of crop plots placed on top of the `GroundLayer` tile grid.
/// Purely visual for now — not wired to any gameplay/farm state.
final class FieldLayer: SKNode {

    // Not private: FarmerLayer mirrors this row/column band so each farmer lands
    // behind this same patch of crops and depth-sorts against the same row scale.
    static let columnCount = 4
    static let rowCount = 3

    private static let cropTextureNames = [
        "crop_sprout",
        "crop_growing",
        "produce_cabbage"
    ]

    /// Crop art is authored as large square icons (512x512); scale each down to roughly
    /// fill a tile's footprint so plots read as small plants rather than dominating the grid.
    private static let cropSize = CGSize(width: GroundTile.width * 0.8, height: GroundTile.width * 0.8)

    /// Computes the vertically-centered row band and right-anchored starting column for
    /// this field's footprint, given the scene size. Exposed as `static` so sibling layers
    /// that need to sit relative to the field (farmers, the shop building, etc.) can reuse
    /// this exact placement math instead of duplicating it.
    static func layoutMetrics(for size: CGSize) -> (startRow: Int, startColumn: Int) {
        // Vertically center the field within the visible row range.
        let visibleRows = Int(ceil(size.height / GroundTile.height))
        let startRow = max(0, (visibleRows - rowCount) / 2)

        // GroundLayer's tile x-position accumulates `skew * rowIndex`, so a fixed column
        // index drifts rightward on screen as rowIndex grows (this is what makes the mesh
        // interlock into a continuous diagonal grid — see GroundTileNode.swift). To keep
        // the field anchored to the right portion of the screen regardless of which row
        // band it lands on, compute the starting column against the skew contribution of
        // the field's middle row rather than assuming column 0 is screen x 0.
        let middleRowIndex = startRow + rowCount / 2
        let representativeSkew = GroundTile.skew * CGFloat(middleRowIndex)
        let fieldWidth = CGFloat(columnCount) * GroundTile.width
        let rightMargin = GroundTile.width
        let desiredLeftX = size.width - rightMargin - fieldWidth
        let startColumn = Int((desiredLeftX - representativeSkew) / GroundTile.width)

        return (startRow, startColumn)
    }

    func layout(for size: CGSize) {
        removeAllChildren()

        let (startRow, startColumn) = Self.layoutMetrics(for: size)

        var cropIndex = 0
        for rowOffset in 0..<Self.rowCount {
            let rowIndex = startRow + rowOffset
            for columnOffset in 0..<Self.columnCount {
                let column = startColumn + columnOffset

                let plot = SKSpriteNode(imageNamed: Self.cropTextureNames[cropIndex % Self.cropTextureNames.count])
                plot.size = Self.cropSize
                cropIndex += 1

                // Same placement formula as GroundLayer, offset to the tile's center.
                let tileOriginX = CGFloat(column) * GroundTile.width + GroundTile.skew * CGFloat(rowIndex)
                let tileOriginY = CGFloat(rowIndex) * GroundTile.height

                plot.position = CGPoint(
                    x: tileOriginX + GroundTile.width / 2 + GroundTile.skew / 2,
                    y: tileOriginY + GroundTile.height / 2
                )

                // GroundLayer places row `rowIndex` at world y = rowIndex * height with no
                // inversion, and the scene uses SpriteKit's default y-up axis (no anchorPoint
                // override in GameSceneView). So a larger rowIndex sits higher on screen (further
                // from the viewer, toward the back of the isometric grid) while a smaller
                // rowIndex sits lower on screen (toward the camera, in front). Depth-sort so the
                // front rows draw on top of the back rows.
                //
                // Note: SKNode zPosition accumulates through the node tree (a child's effective
                // depth is its parent's zPosition plus its own), so this must stay a small
                // *local* offset relative to `rowOffset` — using the raw (potentially large)
                // absolute `rowIndex` here would push plots in high rows below FieldLayer's own
                // zPosition and back behind GroundLayer's tiles.
                plot.zPosition = CGFloat(Self.rowCount - rowOffset)

                addChild(plot)
            }
        }
    }
}
