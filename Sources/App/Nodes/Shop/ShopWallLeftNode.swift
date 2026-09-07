import SpriteKit

/// The shop plot's west-facing side wall: sits along the shop tile's own
/// West→South diamond edge (the lower-left edge in screen terms — "down"
/// and to the left of the tile's center), extruded upward. The counter
/// goes on the *other* visible edge (South→East, lower-right) — a
/// separate piece, not yet built.
///
/// Like `FieldGroundTileNode`/`RoadGroundTileNode`, this has no say in
/// the grid — it fits its footprint to whatever `IsoGrid` it's handed at
/// init, so it lines up with the shop tile beneath it regardless of the
/// grid's own tuning.
final class ShopWallLeftNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "wall_shop_left")

    /// Full replacement of the original art (new, matching set of 4 wall
    /// pieces designed together — see the sibling nodes' doc comments —
    /// noticeably more height-consistent with each other than the
    /// originals were). Already alpha-keyed, already vertical-edged (no
    /// homography correction needed). Native bbox 620×732. Corners (this
    /// image's own coordinates, off the alpha silhouette): top-left(0,29),
    /// top-right(613,299), bottom-left(0,400), bottom-right(619,664) — a
    /// clean parallelogram (no post/flare complications, this is the
    /// plain plank face like the original), plus a thin beveled end-cap
    /// past the right edge (same "extra content past the measured
    /// footprint" the original had).
    private static let nativeSize = CGSize(width: 620, height: 732)

    /// Depth vector (top-left → top-right): how far the art's own main
    /// face runs in each direction. This is what `spriteSize(fittingTo:)`
    /// scales against the tile's own half-diagonal edge — not
    /// `nativeSize` directly, since `nativeSize` includes the end-cap
    /// bleed.
    private static let nativeDepthVector = CGVector(dx: 613 - 0, dy: 299 - 29)

    /// The back-bottom corner (top-left → bottom-left's *bottom* point) —
    /// the corner that lands on the shop tile's own West vertex — as a
    /// fraction of `nativeSize`, in SpriteKit's bottom-up anchor
    /// convention.
    private static let backBottomAnchor = CGPoint(x: 0.0 / 620.0, y: 1 - 400.0 / 732.0)

    /// Fits this wall's footprint (its bottom edge, back corner to front
    /// corner) exactly to `grid`'s own West→South tile-edge vector — see
    /// the original doc comment (unchanged approach, just against the new
    /// art's own measurements).
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
        fatalError("init(coder:) is not supported for ShopWallLeftNode")
    }
}
