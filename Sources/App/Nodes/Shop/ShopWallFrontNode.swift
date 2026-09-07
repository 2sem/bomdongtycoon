import SpriteKit

/// The shop plot's south-east-facing wall: sits along the shop tile's own
/// South→East diamond edge, extruded upward. Shares its back-bottom
/// corner with `ShopWallLeftNode`'s own far end (both meet at the tile's
/// South vertex) — `ShopWallLeftNode` runs West→South and anchors at
/// West, so its unanchored far corner (South) is exactly where this wall
/// starts.
///
/// Like `ShopWallLeftNode`/`ShopWallBackNode`, this has no say in the
/// grid — it fits its footprint to whatever `IsoGrid` it's handed at
/// init.
final class ShopWallFrontNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "wall_shop_front")

    /// Measured against the alpha-trimmed art (clean alpha channel
    /// already), then the same one-off vertical-edge correction used for
    /// every wall in this set (raw art's two "vertical" edges were tilted
    /// — this wall's own corners, in original-image coordinates, before
    /// correction: back-top(362,345), far-top(836,65), back-bottom
    /// (390,751), far-bottom(885,487); "back" here means the South-vertex
    /// side, shared with `ShopWallLeftNode`). Native bbox 544×687 after
    /// correction and crop; back-top(28,280), far-top(502,0),
    /// back-bottom(28,686), far-bottom(502,406) in the corrected image's
    /// own coordinates.
    ///
    /// `ShopWallBackNode` found its own directly-measured silhouette tip
    /// wasn't actually its true structural ground corner (an art bleed
    /// past the base), needing empirical recalibration against a debug
    /// marker. `backBottomAnchor` below was verified the same way from
    /// the start this time rather than trusting the raw measurement
    /// blindly — see the PR for the marker screenshots.
    ///
    /// Art was later replaced with a relit (brighter) revision of the
    /// same source — same measured corners (confirmed: alpha bbox matched
    /// to within 1px), just a 1px-wider crop after re-running the same
    /// correction, hence 545 not 544 here.
    private static let nativeSize = CGSize(width: 545, height: 687)

    /// Depth vector (back-top → far-top): how far the art's own main face
    /// runs in each direction, matching the tile's South→East edge. Both
    /// components differ in sign from the other two walls' (South→East
    /// points right-and-*up*, unlike West→South's right-and-down or
    /// North→West's left-and-down) — `spriteSize(fittingTo:)` uses
    /// magnitudes, so the sign doesn't matter there; it's `anchorPoint`
    /// that actually encodes the direction.
    private static let nativeDepthVector = CGVector(dx: 502 - 28, dy: 0 - 280)

    /// The back-bottom corner — where this wall meets `ShopWallLeftNode`
    /// at the tile's own South vertex — as a fraction of `nativeSize`.
    private static let backBottomAnchor = CGPoint(x: 28.0 / 545.0, y: 1 - 686.0 / 687.0)

    /// This wall's own footprint-fit height (56.31pt at this grid's
    /// current tuning) is proportionate to its footprint edge, same as
    /// every other wall — not undersized. The apparent "too short" look
    /// reported against `ShopWallBackNode`/`ShopWallLeftNode` is a
    /// consequence of the South vertex itself: `IsoGrid.point(col:row:)`
    /// puts South at `tileHeight/2` *below* West/North (it's the nearest,
    /// lowest corner of the diamond, same math that makes every tile's
    /// own South corner its lowest point), so a wall anchored there
    /// starts from a strictly lower base than `ShopWallLeftNode`/
    /// `ShopWallBackNode` (anchored at West) or `ShopWallRightNode`
    /// (anchored at North) — even with an equal or taller footprint-fit
    /// height, its roofline still lands lower on screen. Confirmed with
    /// debug markers placed at each wall's own real near-edge-top height,
    /// directly against each shared vertex: `ShopWallLeftNode`'s and
    /// `ShopWallBackNode`'s markers (49.75pt/58.3pt above their shared
    /// West vertex) both land exactly on their real rendered caps, and so
    /// does this wall's (56.31pt above South) — the numbers were never
    /// wrong, the vertex heights just aren't level.
    ///
    /// `heightAdjustment` deliberately overshoots this wall's own
    /// footprint-true height so its roofline visually reaches back up to
    /// about where `ShopWallLeftNode`'s roofline sits (49.75pt above
    /// *West*, i.e. 49.75 + tileHeight/2 above *South*).
    ///
    /// This wall's art is one rigid parallelogram — the ground edge
    /// (back-bottom → far-bottom) and the roofline (back-top → far-top)
    /// share the same depth vector, scaled together. Growing `scaleY`
    /// to lift the roofline unavoidably grows the ground edge's own
    /// vertical rise from South to East by the same factor, so the far
    /// (East) corner — shared with `ShopWallRightNode`'s own far end —
    /// drifts *above* the true East vertex by `halfHeight *
    /// (heightAdjustment - 1)` (~23pt at 1.6, verified with a debug
    /// marker: a visible but modest gap, not a glaring one). `scaleX` is
    /// left untouched (only `scaleY` carries `heightAdjustment`) since
    /// touching it too would only add horizontal drift on top of the
    /// vertical drift already unavoidable here, for no benefit — this is
    /// a straight tradeoff: a level, closed-looking roofline at the
    /// South corner (the one facing the camera) against a small gap at
    /// the East corner (tucked to the side, away from the camera). No
    /// way was found to get both exactly right with this single-sprite,
    /// single-scale-factor approach — that would need the source art
    /// itself redrawn taller.
    private static let heightAdjustment: CGFloat = 1.6

    /// Same non-uniform-fit approach as the other two walls — see
    /// `ShopWallLeftNode`'s doc comment — with `heightAdjustment` applied
    /// to `scaleY` only (see its own doc comment above), so the
    /// footprint (both ends) stays exactly where it was. Uses magnitudes
    /// throughout since this wall's depth vector's y-component is
    /// negative (points up).
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let halfWidth = grid.tileWidth / 2
        let halfHeight = grid.tileHeight / 2
        let scaleX = halfWidth / abs(nativeDepthVector.dx)
        let scaleY = halfHeight / abs(nativeDepthVector.dy) * heightAdjustment
        return CGSize(width: nativeSize.width * scaleX, height: nativeSize.height * scaleY)
    }

    init(fittingTo grid: IsoGrid) {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize(fittingTo: grid))
        anchorPoint = Self.backBottomAnchor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopWallFrontNode")
    }
}
