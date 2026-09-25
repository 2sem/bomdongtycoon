import SpriteKit

/// The pojangmacha stall's north-west-facing panel: same edge/slot as
/// `ShopWallBackNode` (North->West edge, anchored at the tile's West
/// vertex, shared with `StallWallLeftNode`) — tier 0's stand-in for that
/// wall, shown instead of it while `ShopNode.applyStallTier` has the
/// stall enclosure active.
///
/// Rendered by the same clean `tools/isorender/` rig `ShopWallLeftNode`
/// already uses (not hand-corrected the way `ShopWallBackNode`'s own art
/// is), so its numbers come straight off that render's measurement
/// table, used as printed. Trimmed 205x276; main face
/// top-left(202.34,8.68), top-right(13.34,125.18),
/// bottom-left(202.34,157.91) — the tile-vertex anchor —
/// bottom-right(13.34,274.4).
final class StallWallBackNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "stall_wall_back")

    private static let nativeSize = CGSize(width: 205, height: 276)

    /// Depth vector (top-left -> top-right), matching the tile's own
    /// North->West edge; only its magnitude feeds `spriteSize` — the
    /// direction is carried by `backBottomAnchor` instead, per
    /// `ShopWallBackNode`'s own doc comment.
    private static let nativeDepthVector = CGVector(dx: -189.0, dy: 116.49)

    /// Bottom-left corner (202.34, 157.91) — where this wall meets
    /// `StallWallLeftNode` at the tile's own West vertex — as a fraction
    /// of `nativeSize`, already bottom-up (as printed).
    private static let backBottomAnchor = CGPoint(x: 0.98702, y: 0.42786)

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
        fatalError("init(coder:) is not supported for StallWallBackNode")
    }
}
