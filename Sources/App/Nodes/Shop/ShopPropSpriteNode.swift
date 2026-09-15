import SpriteKit

/// A flat isorender sprite scaled and anchored purely from its own
/// measurement table. Every such prop (`ShopPrepTableNode` included)
/// shares the same scaling rule — native pixel size divided by 3× the
/// live grid's tile width, since every isorender asset in this catalog
/// is rendered at exactly 3× whatever the grid's tile width was at
/// render time — so this factors that rule out once instead of each
/// prop type redefining it. Used directly (not subclassed) by the
/// shop's cash counter and the register that stands on it, since
/// neither needs anything beyond "this image, at this native size,
/// anchored at this fraction."
final class ShopPropSpriteNode: SKSpriteNode {

    private static let measuredGridTileWidth: CGFloat = 126

    /// Points per native (3× render) pixel on `grid`. Exposed so a caller
    /// can scale a measured *offset between two sprites* — e.g. the
    /// register's stand-on-counter offset — by the same factor this type
    /// uses internally to scale a whole sprite, instead of re-deriving it.
    static func isorenderScale(fittingTo grid: IsoGrid) -> CGFloat {
        grid.tileWidth / (measuredGridTileWidth * 3)
    }

    private static func spriteSize(fittingTo grid: IsoGrid, nativeSize: CGSize) -> CGSize {
        let width = nativeSize.width * isorenderScale(fittingTo: grid)
        return CGSize(width: width, height: width * (nativeSize.height / nativeSize.width))
    }

    init(imageName: String, nativeSize: CGSize, baseAnchor: CGPoint, fittingTo grid: IsoGrid) {
        let texture = SKTexture(imageNamed: imageName)
        super.init(
            texture: texture,
            color: .clear,
            size: Self.spriteSize(fittingTo: grid, nativeSize: nativeSize)
        )
        anchorPoint = baseAnchor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopPropSpriteNode")
    }
}
