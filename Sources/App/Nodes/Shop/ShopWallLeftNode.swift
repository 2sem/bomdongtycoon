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

    /// Native bbox 205×276 — wider than just the wall's main face because
    /// the art also includes the end-cap (the wall's visible cut
    /// edge/thickness) past the face's own right edge, the same kind of
    /// "extra content past the measured footprint" a ground tile's skirt
    /// is.
    ///
    /// Unlike the ground tiles and the other three walls, this art is not
    /// a drawing that had to be corrected. It is rendered by
    /// `tools/isorender/` from an orthographic camera derived from
    /// `IsoGrid` itself, so its face edges are exactly vertical and its
    /// slope is the grid's own (0.61635 against 0.61639) rather than
    /// something a homography had to force. All the numbers below come
    /// from that render's measurement table — see the tool's README.
    ///
    /// In the trimmed image's own coordinates the main face is the
    /// parallelogram top-left(2,8.69), top-right(191,125.19),
    /// bottom-left(2,157.92), bottom-right(191,274.41).
    private static let nativeSize = CGSize(width: 205, height: 276)

    /// Depth vector (top-left → top-right): how far the art's own main
    /// face runs in each direction. This is what `spriteSize(fittingTo:)` scales
    /// against the tile's own half-diagonal edge — not `nativeSize`
    /// directly, since `nativeSize` includes the end-cap bleed.
    ///
    /// Rendered at 3× the grid's own half-edge, so this is exactly
    /// `(tileWidth / 2, tileHeight / 2) * 3` and `spriteSize(fittingTo:)`
    /// comes out as a uniform 1/3 on both axes — the art is not stretched
    /// at all, where the hand-corrected walls each need a different scale
    /// per axis to reach the same shape.
    private static let nativeDepthVector = CGVector(dx: 191 - 2, dy: 125.19 - 8.69)

    /// The back-bottom corner (top-left → bottom-left's *bottom* point) —
    /// the corner that lands on the shop tile's own West vertex — as a
    /// fraction of `nativeSize`, in SpriteKit's bottom-up anchor
    /// convention.
    private static let backBottomAnchor = CGPoint(x: 2.0 / 205.0, y: 1 - 157.92 / 276.0)

    /// Fits this wall's footprint (its bottom edge, back corner to front
    /// corner) exactly to `grid`'s own West→South tile-edge vector — the
    /// same non-uniform-fit approach `FieldGroundTileNode` uses against
    /// the grass tile's full footprint, just against a tile's own
    /// half-diagonal edge instead. This is what actually determines the
    /// wall's rendered height: it isn't a free parameter here — the
    /// source art's own depth-to-height ratio is fixed, so matching the
    /// footprint exactly also fixes how tall the wall ends up (~0.7× the
    /// tile's own width, at this grid's current tuning). Making the wall
    /// taller/shorter independent of the footprint would need either a
    /// redrawn asset at a different ratio, or stacking multiple copies —
    /// not attempted here.
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let halfWidth = grid.tileWidth / 2
        let halfHeight = grid.tileHeight / 2
        let scaleX = halfWidth / nativeDepthVector.dx
        let scaleY = halfHeight / nativeDepthVector.dy
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
