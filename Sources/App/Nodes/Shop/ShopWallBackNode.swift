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

    /// Measured against the alpha-trimmed art (clean alpha channel
    /// already). Native bbox 459×624. This asset is architecturally
    /// busier than `ShopWallLeftNode` — a corner post at the front (West)
    /// edge and a cap beam along the roofline, both riding on top of the
    /// same underlying parallelogram every wall in this set reduces to.
    /// The post's own silhouette obscures where a plain back-bottom
    /// ground corner would be, so unlike the left wall (whose 4 corners
    /// were all directly measurable), this one's back-bottom corner was
    /// *derived* — assumed to complete the parallelogram implied by the
    /// other three measured corners (back-top, front-top, front-bottom)
    /// — rather than picked directly off the silhouette. Raw art corners
    /// (this image's own coordinates, after the same one-off vertical-edge
    /// correction used for the left wall): back-top(416,1),
    /// front-top(32,218), front-bottom(32,622), back-bottom(416,405).
    private static let nativeSize = CGSize(width: 459, height: 624)

    /// Depth vector (back-top → front-top): how far the art's own main
    /// face runs in each direction, matching the tile's North→West edge.
    /// Both components are negative (this wall's art runs the opposite
    /// horizontal direction from the left wall's, since North→West and
    /// West→South point different ways) — `spriteSize(fittingTo:)` uses
    /// magnitudes, so the sign doesn't matter there; it's `anchorPoint`
    /// that actually encodes the direction.
    private static let nativeDepthVector = CGVector(dx: 32 - 416, dy: 218 - 1)

    /// The front-bottom corner — where this wall meets `ShopWallLeftNode`
    /// at the tile's own West vertex — as a fraction of `nativeSize`, in
    /// SpriteKit's bottom-up anchor convention.
    private static let frontBottomAnchor = CGPoint(x: 32.0 / 459.0, y: 1 - 622.0 / 624.0)

    /// Same non-uniform-fit approach as `ShopWallLeftNode` — see that
    /// type's doc comment. Uses magnitudes throughout since this wall's
    /// depth vector points the opposite horizontal direction.
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
