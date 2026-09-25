import SpriteKit

/// The pojangmacha stall's west-facing side panel: same edge/slot as
/// `ShopWallLeftNode` (West->South edge, anchored at the tile's West
/// vertex) — tier 0's stand-in for that wall, shown instead of it while
/// `ShopNode.applyStallTier` has the stall enclosure active.
///
/// Rendered by the same rig, at the same footprint, as `ShopWallLeftNode`
/// itself — trimmed 205x276, main face top-left(2,8.69),
/// top-right(191,125.19), bottom-left(2,157.92) — the tile-vertex anchor
/// — bottom-right(191,274.41) — so this wall's own numbers are identical
/// to that node's, just a different texture. Used as printed rather than
/// re-derived, per this render's measurement table.
final class StallWallLeftNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "stall_wall_left")

    private static let nativeSize = CGSize(width: 205, height: 276)

    /// Depth vector (top-left -> top-right), matching the tile's own
    /// West->South edge.
    private static let nativeDepthVector = CGVector(dx: 189.0, dy: 116.49)

    /// Bottom-left corner (2.0, 157.92) — where this wall meets
    /// `StallWallBackNode` at the tile's own West vertex — as a fraction
    /// of `nativeSize`, already bottom-up (as printed).
    private static let backBottomAnchor = CGPoint(x: 0.00976, y: 0.42783)

    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let halfWidth = grid.tileWidth / 2
        let halfHeight = grid.tileHeight / 2
        let scaleX = halfWidth / abs(nativeDepthVector.dx)
        let scaleY = halfHeight / abs(nativeDepthVector.dy)
        return CGSize(width: nativeSize.width * scaleX, height: nativeSize.height * scaleY)
    }

    init(fittingTo grid: IsoGrid) {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize(fittingTo: grid))
        anchorPoint = Self.backBottomAnchor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for StallWallLeftNode")
    }
}
