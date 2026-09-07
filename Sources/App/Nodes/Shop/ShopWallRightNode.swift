import SpriteKit

/// The shop plot's north-east-facing wall (with a window): sits along the
/// shop tile's own North→East diamond edge, extruded upward. Shares its
/// back-bottom corner with `ShopWallBackNode`'s own far (unanchored) end
/// — both meet at the tile's North vertex. Its own far end (East) should
/// in turn line up with `ShopWallFrontNode`'s far end, closing the shop
/// box on all four sides — not independently anchored here, just expected
/// to fall out of both walls' own correct footprint-fit.
///
/// Like the other three walls, this has no say in the grid — it fits its
/// footprint to whatever `IsoGrid` it's handed at init.
final class ShopWallRightNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "wall_shop_right")

    /// Full replacement of the original art (new, matching set of 4 wall
    /// pieces designed together — see the sibling nodes' doc comments).
    /// Already alpha-keyed, already vertical-edged. Native bbox 630×745.
    /// Window on the near (North) side, a single corner post on the far
    /// (East) side — same shape idea as the original. Corners (this
    /// image's own coordinates, off the alpha silhouette's clean parts):
    /// back-top(0,0), far-top(629,306), back-bottom(0,394) — all directly
    /// measurable, no post-foot flare on this side (the window side has a
    /// clean corner, unlike `ShopWallBackNode`/`ShopWallFrontNode`'s
    /// near/far posts). far-bottom (629,727) has the same kind of flare
    /// the other walls' posts do, but it's the unanchored end here so it
    /// isn't load-bearing for anchoring precision.
    private static let nativeSize = CGSize(width: 630, height: 745)

    /// Depth vector (back-top → far-top): how far the art's own main
    /// face runs in each direction, matching the tile's North→East edge
    /// — same direction as `ShopWallLeftNode`'s own West→South (both
    /// point right-and-down).
    private static let nativeDepthVector = CGVector(dx: 629 - 0, dy: 306 - 0)

    /// The back-bottom corner — where this wall meets `ShopWallBackNode`
    /// at the tile's own North vertex — as a fraction of `nativeSize`.
    private static let backBottomAnchor = CGPoint(x: 0.0 / 630.0, y: 1 - 394.0 / 745.0)

    /// Same non-uniform-fit approach as the other three walls — see
    /// `ShopWallLeftNode`'s doc comment.
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
