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

    /// Unlike the other three walls, source art had a flat *black*
    /// background (no alpha channel) rather than a pre-keyed transparent
    /// one, so this went through the same connected-component background
    /// keying used for the very first grass/field tile JPEGs. First
    /// attempt at that keying badly fragmented the wall into ~390 tiny
    /// disconnected pieces — the ink outline strokes and the window's dark
    /// glass dipped below the brightness threshold, splitting "content"
    /// into many islands, and picking the single largest one kept only a
    /// fragment (visibly missing most of the wall). Fixed by
    /// `binary_closing` with a fairly large (9×9) structuring element
    /// *before* labeling, to bridge those thin dark-outline gaps so the
    /// whole wall labels as one component.
    ///
    /// After that, the same one-off vertical-edge homography correction
    /// used for every wall in this set. Corners (in the correctly-keyed,
    /// pre-correction image's own coordinates): back-top(40,0),
    /// far-top(531,194), back-bottom(0,506) — all three directly
    /// measured off a clean silhouette, same confidence level as
    /// `ShopWallFrontNode`'s corners (not `ShopWallBackNode`'s, which
    /// needed empirical recalibration). far-bottom was derived (completes
    /// the parallelogram) since it isn't used for anchoring. Native bbox
    /// 526×742 after correction and crop; back-top(34,0), far-top
    /// (525,194), back-bottom(34,506), far-bottom(525,700) in the
    /// corrected image's own coordinates.
    private static let nativeSize = CGSize(width: 526, height: 742)

    /// Depth vector (back-top → far-top): how far the art's own main face
    /// runs in each direction, matching the tile's North→East edge — same
    /// direction as `ShopWallLeftNode`'s own West→South (both point
    /// right-and-down), unlike the other two walls.
    private static let nativeDepthVector = CGVector(dx: 525 - 34, dy: 194 - 0)

    /// The back-bottom corner — where this wall meets `ShopWallBackNode`
    /// at the tile's own North vertex — as a fraction of `nativeSize`.
    private static let backBottomAnchor = CGPoint(x: 34.0 / 526.0, y: 1 - 506.0 / 742.0)

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
