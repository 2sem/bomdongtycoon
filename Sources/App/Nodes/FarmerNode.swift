import SpriteKit

/// One decorative farmer figure standing behind each column of `FieldLayer`'s
/// crop patch, as if tending that column. Purely visual for now — not wired
/// to any farm/staff hire state.
final class FarmerLayer: SKNode {

    private static let textureName = "staff_farmer"

    /// One row further north than `FieldLayer`'s own back-most crop row —
    /// mirrors the old "stand one row behind the field's back row" rule,
    /// just against fixed `IsoGrid` coordinates instead of a dynamically
    /// computed one.
    private static let row = FieldLayer.startRow - 1

    func layout(for sceneSize: CGSize) {
        removeAllChildren()

        let originOffset = GroundLayer.originOffset(for: sceneSize)

        // Source art is a square bust-style icon (512x512), not a tall
        // standing figure — the old `GroundTile.height * 3` sizing was
        // tuned against the old 32pt-tall tile and doesn't carry over as
        // a simple ratio to the new, much larger tile. Size it as a
        // fraction of the grid's own column spacing instead, small enough
        // that adjacent farmers (one per column) don't overlap each other.
        let texture = SKTexture(imageNamed: Self.textureName)
        let aspect = texture.size().width / texture.size().height
        let desiredWidth = GroundLayer.grid.tileWidth * 0.7
        let farmerSize = CGSize(width: desiredWidth, height: desiredWidth / aspect)

        for columnOffset in 0..<FieldLayer.columnCount {
            let col = FieldLayer.startColumn + columnOffset

            let farmer = SKSpriteNode(texture: texture)
            farmer.size = farmerSize

            // Anchor at the sprite's feet so `position` lands on the tile
            // surface rather than the sprite's visual center.
            farmer.anchorPoint = CGPoint(x: 0.5, y: 0)

            let point = GroundLayer.grid.point(col: col, row: Self.row)
            farmer.position = CGPoint(x: point.x + originOffset.x, y: point.y + originOffset.y)

            // Same back-to-front convention as every other layer sharing
            // this grid, so the farmer sorts correctly against its own
            // row (it stands behind the crops it's tending, at a smaller
            // col + row than any of them, so it draws first/behind).
            farmer.zPosition = CGFloat(col + Self.row)

            addChild(farmer)
        }
    }
}
