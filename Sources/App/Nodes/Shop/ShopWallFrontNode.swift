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

    /// Same non-uniform-fit approach as the other two walls — see
    /// `ShopWallLeftNode`'s doc comment. Uses magnitudes throughout since
    /// this wall's depth vector's y-component is negative (points up).
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
        fatalError("init(coder:) is not supported for ShopWallFrontNode")
    }
}
