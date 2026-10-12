import SpriteKit

/// The pojangmacha stall's north-east-facing panel: same edge/slot as
/// `ShopWallRightNode` (North->East edge, anchored at the tile's North
/// vertex, shared with `StallWallBackNode`) — tier 0's stand-in for that
/// wall, shown instead of it while `ShopNode.applyStallTier` has the
/// stall enclosure active. Plain curtain — no window, unlike
/// `ShopWallRightNode`'s own art.
///
/// Rendered by the same clean rig `StallWallBackNode`/`StallWallLeftNode`
/// use, so its numbers come straight off that render's measurement
/// table, used as printed. Trimmed 198x273; main face
/// top-left(1.33,5.19), top-right(190.33,121.68),
/// bottom-left(1.33,154.41) — the tile-vertex anchor —
/// bottom-right(190.33,270.91).
final class StallCurtainRightNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "stall_curtain_right")

    private static let nativeSize = CGSize(width: 198, height: 273)

    /// Depth vector (top-left -> top-right), matching the tile's own
    /// North->East edge.
    private static let nativeDepthVector = CGVector(dx: 189.0, dy: 116.5)

    /// Bottom-left corner (1.33, 154.41) — where this wall meets
    /// `StallWallBackNode` at the tile's own North vertex — as a fraction
    /// of `nativeSize`, already bottom-up (as printed).
    private static let backBottomAnchor = CGPoint(x: 0.00672, y: 0.43440)

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
        fatalError("init(coder:) is not supported for StallCurtainRightNode")
    }
}
