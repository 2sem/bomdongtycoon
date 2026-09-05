import SpriteKit

/// The shop's back-most footprint row, right in front of the back wall — currently holds the
/// prep table (see `KitchenTableNode`) and a bowl sitting on top of it (see `KitchenEmptyBowlNode`).
/// Cook and further cooking props aren't wired up yet, and none of this is wired to any
/// gameplay/staff-hire state.
final class KitchenLayer: SKNode {

    // Items on the table are arranged in a left-to-right row starting near the tabletop's own
    // left edge, rather than each being independently centered on it — this reads as items
    // laid out across a work surface, and keeps them from overlapping as more props are added.
    private static let itemLeftMargin = GroundTile.width * 0.12
    private static let itemGap = GroundTile.width * 0.08

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

        // Items sit at half the tabletop's depth (vertically centered on the surface) and are
        // laid out left-to-right starting `itemLeftMargin` in from the tabletop's own left
        // edge, advancing the cursor by each item's width plus `itemGap` as more are added.
        let itemY = table.position.y + KitchenTableNode.depth * 0.5
        var itemCursorX = centerX - KitchenTableNode.width / 2 + Self.itemLeftMargin

        // Added after the table so it draws in front of the tabletop's own faces, reading as
        // sitting on top of it.
        let bowl = KitchenEmptyBowlNode()
        bowl.position = CGPoint(x: itemCursorX + KitchenEmptyBowlNode.width / 2, y: itemY)
        bowl.zPosition = rowZPosition
        addChild(bowl)
        itemCursorX += KitchenEmptyBowlNode.width + Self.itemGap
    }
}
