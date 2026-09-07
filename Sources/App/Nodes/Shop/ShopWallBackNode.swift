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

    /// Full replacement of the original art (new, matching set of 4 wall
    /// pieces designed together — see the sibling nodes' doc comments).
    /// Already alpha-keyed, already vertical-edged. Native bbox 520×640.
    /// A corner post at each end plus a cap beam along the roofline,
    /// riding on top of the same underlying parallelogram every wall in
    /// this set reduces to — same shape idea as the original. Corners
    /// (this image's own coordinates, off the alpha silhouette):
    /// front-top(2,272)... no — front-top(0,259), back-top(519,10),
    /// back-bottom(516,405), off the clean parts of each post's own
    /// vertical edge. front-bottom raw silhouette tip is (0,610), but
    /// (like the original back wall) the post's foot has a visible flare
    /// past its own structural base — `frontBottomAnchor` below starts
    /// from that raw measurement and gets verified/recalibrated against
    /// a debug marker before shipping, not trusted blindly.
    private static let nativeSize = CGSize(width: 520, height: 640)

    /// Depth vector (front-top → back-top): how far the art's own main
    /// face runs in each direction, matching the tile's North→West edge.
    private static let nativeDepthVector = CGVector(dx: 519 - 0, dy: 10 - 259)

    /// The front-bottom corner — where this wall meets `ShopWallLeftNode`
    /// at the tile's own West vertex — as a fraction of `nativeSize`.
    /// Raw measurement (see `nativeSize`'s doc comment); verify against a
    /// debug marker before trusting it.
    private static let frontBottomAnchor = CGPoint(x: 0.0 / 520.0, y: 1 - 610.0 / 640.0)

    /// Same non-uniform-fit approach as `ShopWallLeftNode` — see that
    /// type's doc comment.
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
