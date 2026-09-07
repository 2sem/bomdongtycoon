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

    /// Full replacement of the original art (new, matching set of 4 wall
    /// pieces designed together — see the sibling nodes' doc comments).
    /// Already alpha-keyed, already vertical-edged. Native bbox 526×687.
    /// Plain plank face on the near (South) side, a single corner post on
    /// the far (East) side — same shape idea as the original. Corners
    /// (this image's own coordinates, off the alpha silhouette):
    /// back-top(2,272), far-top(485,0), far-bottom(518,429) off the clean
    /// parts of each edge. back-bottom raw silhouette tip is (30,686),
    /// but (like `ShopWallBackNode`) the near corner's own foot has a
    /// visible flare past its structural base — `backBottomAnchor` below
    /// starts from that raw measurement and gets verified/recalibrated
    /// against a debug marker before shipping, not trusted blindly.
    private static let nativeSize = CGSize(width: 526, height: 687)

    /// Depth vector (back-top → far-top): how far the art's own main face
    /// runs in each direction, matching the tile's South→East edge.
    private static let nativeDepthVector = CGVector(dx: 485 - 2, dy: 0 - 272)

    /// The back-bottom corner — where this wall meets `ShopWallLeftNode`
    /// at the tile's own South vertex — as a fraction of `nativeSize`.
    /// Raw measurement (see `nativeSize`'s doc comment); verify against a
    /// debug marker before trusting it.
    private static let backBottomAnchor = CGPoint(x: 30.0 / 526.0, y: 1 - 686.0 / 687.0)

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
