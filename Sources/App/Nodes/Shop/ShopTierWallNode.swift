import SpriteKit

/// One wall segment of the tier 1 (분식집, `bunsik_*`) or tier 2 (전문점,
/// `jeonmun_*`) enclosure; `ShopNode.applyStallTier` shows exactly one of
/// the three enclosures (stall / bunsik / jeonmun) at a time.
///
/// All of it is rendered by the clean `tools/isorender/` rig at 3x, so
/// every number is a trimmed-PNG pixel off the render's measurement
/// table, used as printed. The half-edge depth vector is therefore
/// `(tileWidth / 2, tileHeight / 2) * 3` on every piece and
/// `spriteSize(fittingTo:)` is a uniform 1/3 — the art is not stretched.
///
/// Placement is by `anchor` (the bottom-left face corner, which lands on
/// the tile vertex), never by trimmed height: tier 2 carries eave and
/// fascia above the face, so its image is taller than the face needs.
final class ShopTierWallNode: SKSpriteNode {

    struct Spec {
        let imageName: String
        /// Trimmed PNG size, px.
        let nativeSize: CGSize
        /// Bottom-left face corner in the PNG's own coordinates (y down).
        let anchor: CGPoint
        /// Which way this edge runs on screen; the front (S->E) edge is
        /// the only one that climbs to the right. Only its magnitude
        /// feeds the size, the direction is carried by `anchor`.
        let depthDX: CGFloat
        let depthDY: CGFloat
    }

    private static let depthX: CGFloat = 189.0
    private static let depthY: CGFloat = 116.49

    static let bunsikBack = Spec(
        imageName: "bunsik_wall_back", nativeSize: CGSize(width: 210, height: 283),
        anchor: CGPoint(x: 204.34, y: 162.91), depthDX: -depthX, depthDY: depthY)
    static let bunsikRight = Spec(
        imageName: "bunsik_wall_right", nativeSize: CGSize(width: 207, height: 278),
        anchor: CGPoint(x: 2.66, y: 157.91), depthDX: depthX, depthDY: depthY)
    static let bunsikFront = Spec(
        imageName: "bunsik_wall_front", nativeSize: CGSize(width: 209, height: 281),
        anchor: CGPoint(x: 14.0, y: 279.41), depthDX: depthX, depthDY: -depthY)
    static let jeonmunLeft = Spec(
        imageName: "jeonmun_wall_left", nativeSize: CGSize(width: 229, height: 320),
        anchor: CGPoint(x: 21.0, y: 199.65), depthDX: depthX, depthDY: depthY)
    static let jeonmunBack = Spec(
        imageName: "jeonmun_wall_back", nativeSize: CGSize(width: 229, height: 328),
        anchor: CGPoint(x: 221.34, y: 207.64), depthDX: -depthX, depthDY: depthY)
    static let jeonmunRight = Spec(
        imageName: "jeonmun_wall_right", nativeSize: CGSize(width: 229, height: 328),
        anchor: CGPoint(x: 7.66, y: 207.64), depthDX: depthX, depthDY: depthY)
    static let jeonmunFront = Spec(
        imageName: "jeonmun_wall_front", nativeSize: CGSize(width: 229, height: 319),
        anchor: CGPoint(x: 19.0, y: 316.15), depthDX: depthX, depthDY: -depthY)

    init(_ spec: Spec, fittingTo grid: IsoGrid) {
        let scaleX = (grid.tileWidth / 2) / abs(spec.depthDX)
        let scaleY = (grid.tileHeight / 2) / abs(spec.depthDY)
        let size = CGSize(width: spec.nativeSize.width * scaleX, height: spec.nativeSize.height * scaleY)
        super.init(texture: SKTexture(imageNamed: spec.imageName), color: .clear, size: size)
        anchorPoint = CGPoint(
            x: spec.anchor.x / spec.nativeSize.width,
            y: 1 - spec.anchor.y / spec.nativeSize.height
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopTierWallNode")
    }
}
