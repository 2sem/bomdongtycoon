import SpriteKit

/// The pojangmacha stall's south-east-facing panel: same edge/slot as
/// `ShopWallFrontNode` (South->East edge, anchored at the tile's South
/// vertex, shared with `StallWallLeftNode`) — tier 0's stand-in for that
/// wall, shown instead of it while `ShopNode.applyStallTier` has the
/// stall enclosure active.
///
/// No entrance gap baked into this art (unlike `ShopWallFrontNode`'s own
/// source, see that node's doc comment) — the entrance stays a
/// Swift-level omission via `ShopNode.defaultOpenings`, same as every
/// other side.
///
/// Rendered by the same clean rig the other three stall panels use, so
/// its numbers come straight off that render's measurement table, used
/// as printed. Trimmed 198x272; main face top-left(7.0,121.19),
/// top-right(196.0,4.69), bottom-left(7.0,270.41) — the tile-vertex
/// anchor — bottom-right(196.0,153.92).
final class StallCurtainFrontNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "stall_curtain_front")

    private static let nativeSize = CGSize(width: 198, height: 272)

    /// Depth vector (top-left -> top-right), matching the tile's own
    /// South->East edge; the y-component is negative (this edge points
    /// right-and-up, unlike the other three) — only the magnitude feeds
    /// `spriteSize`, direction is carried by `backBottomAnchor`.
    private static let nativeDepthVector = CGVector(dx: 189.0, dy: -116.49)

    /// Bottom-left corner (7.0, 270.41) — where this wall meets
    /// `StallWallLeftNode` at the tile's own South vertex — as a fraction
    /// of `nativeSize`, already bottom-up (as printed).
    private static let backBottomAnchor = CGPoint(x: 0.03535, y: 0.00585)

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
        fatalError("init(coder:) is not supported for StallCurtainFrontNode")
    }
}
