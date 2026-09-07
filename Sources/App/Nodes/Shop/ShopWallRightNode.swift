import SpriteKit

/// The shop plot's north-east-facing wall (with a window): sits along the
/// shop tile's own North→East diamond edge, extruded upward. Shares its
/// back-bottom corner with `ShopWallBackNode`'s own far (unanchored) end
/// — both meet at the tile's North vertex. Its own far end (East) should
/// in turn line up with `ShopWallFrontNode`'s far end, closing the shop
/// box on all four sides — not independently anchored here, just expected
/// to fall out of both walls' own correct footprint-fit.
///
/// This is a from-scratch replacement for an earlier version of this
/// wall: that one's source art had a much taller height-to-depth ratio
/// than the other three walls, and no crop or scale trick fixed it
/// without either destroying content or introducing visible drift at
/// this wall's own junctions (see git history on the old, discarded
/// `shop-wall-right` branch). The user re-did the source art by hand
/// instead — already alpha-keyed, already vertical-edged (no homography
/// correction needed this time) — and its height-to-depth ratio now
/// matches the other three walls well enough to fit plainly, the same
/// way `ShopWallLeftNode` and `ShopWallFrontNode` do.
///
/// Like the other three walls, this has no say in the grid — it fits its
/// footprint to whatever `IsoGrid` it's handed at init.
final class ShopWallRightNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "wall_shop_right")

    /// Measured directly off the art's own alpha channel (already keyed
    /// and already vertical-edged — no homography correction needed).
    /// Native bbox 637×736. Corners (this image's own coordinates, off
    /// the alpha silhouette's convex hull): back-top(40,0),
    /// far-top(~630,305) — where the sloped top edge meets the far
    /// (right) edge, which stays vertical from there down to ~(636,718)
    /// before the post's foot flares out a few px past its true
    /// structural base (same flare `ShopWallBackNode`'s post has) down
    /// to (576,735) — and back-bottom(38,429), where the back (left)
    /// edge meets the sloped bottom edge.
    private static let nativeSize = CGSize(width: 637, height: 736)

    /// Depth vector (back-top → far-top): how far the art's own main
    /// face runs in each direction, matching the tile's North→East edge
    /// — same direction as `ShopWallLeftNode`'s own West→South (both
    /// point right-and-down).
    private static let nativeDepthVector = CGVector(dx: 630 - 40, dy: 305 - 0)

    /// The back-bottom corner — where this wall meets `ShopWallBackNode`
    /// at the tile's own North vertex — as a fraction of `nativeSize`.
    private static let backBottomAnchor = CGPoint(x: 38.0 / 637.0, y: 1 - 429.0 / 736.0)

    /// Same non-uniform-fit approach as the other three walls — see
    /// `ShopWallLeftNode`'s doc comment. No `heightAdjustment` hack this
    /// time: the new art's own height-to-depth ratio already tracks the
    /// other walls, so a plain footprint fit is enough.
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
        fatalError("init(coder:) is not supported for ShopWallRightNode")
    }
}
