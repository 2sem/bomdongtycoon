import SpriteKit

/// The shop's back-most footprint row, right in front of the back wall — currently holds just
/// the prep table (see `KitchenTableNode` for how it's built). Cook and cooking props aren't
/// wired up yet, and none of this is wired to any gameplay/staff-hire state.
final class KitchenLayer: SKNode {
    func layout(for size: CGSize) {
        removeAllChildren()

        let (shopStartRow, shopStartColumn) = ShopWallLayer.layoutMetrics(for: size)
        let (fieldStartRow, _) = FieldLayer.layoutMetrics(for: size)

        // The back-most of the shop's 3 footprint rows — directly in front of the back wall.
        let kitchenRowIndex = shopStartRow + ShopWallLayer.rowCount - 1
        let rowZPosition = ShopWallLayer.zPosition(forRowIndex: kitchenRowIndex, fieldStartRow: fieldStartRow)

        // Geometric centroid of the shop's full column span at this row — the same
        // "average of the parallelogram's corners" formula GroundLayer/FieldLayer/FarmerLayer
        // use to center content within a single tile cell, generalized here to the shop's
        // whole column width so the table lands centered under the roofline.
        let rowOriginX = CGFloat(shopStartColumn) * GroundTile.width + GroundTile.skew * CGFloat(kitchenRowIndex)
        let centerX = rowOriginX + CGFloat(ShopWallLayer.columnCount) * GroundTile.width / 2 + GroundTile.skew / 2
        let centerY = CGFloat(kitchenRowIndex) * GroundTile.height + GroundTile.height / 2

        let table = KitchenTableNode()
        table.position = CGPoint(x: centerX, y: centerY)
        table.zPosition = rowZPosition
        addChild(table)
    }
}
