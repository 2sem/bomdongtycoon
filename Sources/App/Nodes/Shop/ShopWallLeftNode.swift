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

    /// Measured against the alpha-trimmed art (source had a clean alpha
    /// channel already). Native bbox 654×731 — wider than just the wall's
    /// main face because the art also includes a beveled end-cap (the
    /// wall's visible cut edge/thickness) past the face's own right edge,
    /// the same kind of "extra content past the measured footprint" a
    /// ground tile's skirt is.
    ///
    /// The raw source wasn't a true parallelogram: its two vertical edges
    /// were tilted ~46px off across a 410px run (~11%) — hand-drawn
    /// imprecision, same as every ground tile so far — so it went through
    /// the same one-off homography correction technique before being
    /// saved, this time forcing the left/right edges exactly vertical
    /// rather than correcting a diamond's corners. In this corrected,
    /// cropped image's own coordinates, the wall's main face is the
    /// parallelogram top-left(41,0), top-right(615,320),
    /// bottom-left(41,410), bottom-right(615,730).
    private static let nativeSize = CGSize(width: 654, height: 731)

    /// Depth vector (top-left → top-right): how far the art's own main
    /// face runs in each direction. This is what `spriteSize(fittingTo:)` scales
    /// against the tile's own half-diagonal edge — not `nativeSize`
    /// directly, since `nativeSize` includes the end-cap bleed.
    private static let nativeDepthVector = CGVector(dx: 615 - 41, dy: 320 - 0)

    /// The back-bottom corner (top-left → bottom-left's *bottom* point) —
    /// the corner that lands on the shop tile's own West vertex — as a
    /// fraction of `nativeSize`, in SpriteKit's bottom-up anchor
    /// convention.
    private static let backBottomAnchor = CGPoint(x: 41.0 / 654.0, y: 1 - 410.0 / 731.0)

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
