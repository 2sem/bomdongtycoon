import SpriteKit

/// The shop plot's north-west-facing wall: sits along the shop tile's own
/// North→West diamond edge, extruded upward. Shares its front-bottom
/// corner with `ShopWallLeftNode` (both anchor at the tile's West vertex),
/// so the two walls meet cleanly there.
///
/// Like `ShopWallLeftNode`, this has no say in the grid — it fits its
/// footprint to whatever `IsoGrid` it's handed at init.
final class ShopWallBackNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "wall_shop_back")

    /// This is a from-scratch replacement for an earlier version of this
    /// wall (see git history for the original, which needed an
    /// empirically-recalibrated anchor to close a visible gap against
    /// `ShopWallLeftNode`). New source art, plain corner posts on both
    /// ends and a cap/base beam, already alpha-keyed and already
    /// vertical-edged (no homography correction needed). Native bbox
    /// 551×689. Corners (this image's own coordinates, off the alpha
    /// silhouette's convex hull): back-top(488,0) — the far/North-side
    /// post's cap, highest point in the image; front-top(11,275) — where
    /// the near/West-side post's own vertical edge meets the sloped cap
    /// beam; back-bottom(546,421) — where the far post's vertical edge
    /// meets the sloped base beam, no flare/rounding issue on this side;
    /// front-bottom(43,688) — the near post's own foot, same kind of
    /// flare `ShopWallRightNode`'s post has (silhouette rounds a few px
    /// past its true structural base), raw measurement here pending
    /// verification against `ShopWallLeftNode` with a debug marker.
    private static let nativeSize = CGSize(width: 551, height: 689)

    /// Depth vector (back-top → front-top): how far the art's own main
    /// face runs in each direction, matching the tile's North→West edge.
    /// Both components negative (this wall's art runs the opposite
    /// horizontal direction from the left wall's) — `spriteSize
    /// (fittingTo:)` uses magnitudes, so the sign doesn't matter there;
    /// it's `anchorPoint` that actually encodes the direction.
    private static let nativeDepthVector = CGVector(dx: 11 - 488, dy: 275 - 0)

    /// The front-bottom corner — where this wall meets `ShopWallLeftNode`
    /// at the tile's own West vertex — as a fraction of `nativeSize`.
    /// Raw measurement off the art (see `nativeSize`'s doc comment);
    /// verified pixel-tight against `ShopWallLeftNode` with a debug
    /// marker on the first attempt this time, no recalibration needed
    /// (unlike the prior version of this wall).
    private static let frontBottomAnchor = CGPoint(x: 43.0 / 551.0, y: 1 - 688.0 / 689.0)

    /// Same non-uniform-fit approach as `ShopWallLeftNode` — see that
    /// type's doc comment. This new art's own height-to-depth ratio
    /// tracks the other three walls closely enough (measured ~58pt
    /// visible height vs. `ShopWallLeftNode`'s 49.75pt reference, in the
    /// same ballpark as `ShopWallFrontNode`'s 56.31pt) that no
    /// `heightAdjustment` hack is needed, unlike the prior version of
    /// this wall.
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let halfWidth = grid.tileWidth / 2
        let halfHeight = grid.tileHeight / 2
        let scaleX = halfWidth / abs(nativeDepthVector.dx)
        let scaleY = halfHeight / abs(nativeDepthVector.dy)
        return CGSize(width: nativeSize.width * scaleX, height: nativeSize.height * scaleY)
    }

    init(fittingTo grid: IsoGrid) {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize(fittingTo: grid))
        anchorPoint = Self.frontBottomAnchor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopWallBackNode")
    }
}
