import SpriteKit

/// The shop's back-most footprint row, right in front of the back wall — currently holds the
/// prep table (see `KitchenTableNode`) and a bowl sitting on top of it (see `KitchenEmptyBowlNode`).
/// Cook and further cooking props aren't wired up yet, and none of this is wired to any
/// gameplay/staff-hire state.
final class KitchenLayer: SKNode {

    // The tabletop is divided into a fixed row of equal-width tile slots so each item placed
    // on it gets its own dedicated area to sit in — mirroring how GroundTile/FieldLayer divide
    // the floor into a grid of cells rather than treating it as one continuous surface — instead
    // of packing items edge to edge or centering them all on the same point.
    private static let tileSlotCount = 3

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
        // each centered within their own tile slot's horizontal span, so a slot is reserved
        // for an item regardless of that item's own width.
        let itemY = table.position.y + KitchenTableNode.depth * 0.5
        let slotWidth = KitchenTableNode.width / CGFloat(Self.tileSlotCount)
        let tableLeftX = centerX - KitchenTableNode.width / 2

        func slotCenterX(_ slotIndex: Int) -> CGFloat {
            tableLeftX + slotWidth * (CGFloat(slotIndex) + 0.5)
        }

        // Added after the table so it draws in front of the tabletop's own faces, reading as
        // sitting on top of it. Placed in the leftmost tile slot.
        let bowl = KitchenEmptyBowlNode()
        bowl.position = CGPoint(x: slotCenterX(0), y: itemY)
        bowl.zPosition = rowZPosition
        addChild(bowl)
    }
}
