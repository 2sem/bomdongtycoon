import SpriteKit

/// A large, empty stainless-steel mixing bowl — the "before" counterpart to
/// `KitchenKimchiBowlNode`'s filled 겉절이 bowl, meant to sit on top of `KitchenTableNode`.
/// Distinguished from the small ceramic `KitchenEmptyBowlNode` by its larger footprint and
/// metal color, reading as the prep bowl the kimchi salad gets tossed in before serving.
/// Cropped to its true visible-content bounding box, measured directly from the source PNG's
/// alpha channel — the same approach the other bowl nodes use, since the art sits on a square
/// canvas with a large transparent margin. `anchorPoint` is bottom-center so a caller's
/// `position` lands exactly on the bowl's own base.
final class KitchenEmptyKimchiBowlNode: SKSpriteNode {

    private static let textureName = "empty_kimchi_bowl"

    private static let contentPixelRect = CGRect(x: 141, y: 413, width: 742, height: 482)
    private static let canvasSize: CGFloat = 1024

    /// Normalized rect in SKTexture's unit coordinate space (origin bottom-left, y-up).
    private static var contentUnitRect: CGRect {
        CGRect(
            x: contentPixelRect.minX / canvasSize,
            y: (canvasSize - contentPixelRect.maxY) / canvasSize,
            width: contentPixelRect.width / canvasSize,
            height: contentPixelRect.height / canvasSize
        )
    }

    private static var contentAspect: CGFloat { contentPixelRect.width / contentPixelRect.height }

    // Wider than `KitchenEmptyBowlNode`/`KitchenKimchiBowlNode`'s 0.36 fraction — this reads as
    // a larger mixing bowl among the table's smaller serving bowls, while still fitting inside
    // one tile slot's width.
    static let width = GroundTile.width * 0.44

    init() {
        let fullTexture = SKTexture(imageNamed: Self.textureName)
        let croppedTexture = SKTexture(rect: Self.contentUnitRect, in: fullTexture)
        super.init(
            texture: croppedTexture,
            color: .clear,
            size: CGSize(width: Self.width, height: Self.width / Self.contentAspect)
        )
        anchorPoint = CGPoint(x: 0.5, y: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
