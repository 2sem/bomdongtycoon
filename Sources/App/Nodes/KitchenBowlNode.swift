import SpriteKit

/// A small serving bowl prop meant to sit on top of `KitchenTableNode`. Cropped to its true
/// visible-content bounding box, measured directly from the source PNG's alpha channel: the
/// art sits on a square canvas with a large transparent margin, so sizing off the raw texture
/// aspect would render the bowl far smaller than intended and float it above the surface it's
/// meant to stand on. `anchorPoint` is bottom-center so a caller's `position` lands exactly on
/// the bowl's own base.
final class KitchenBowlNode: SKSpriteNode {

    private static let textureName = "kitchen_bowl"

    private static let contentPixelRect = CGRect(x: 169, y: 153, width: 796, height: 831)
    private static let canvasSize: CGFloat = 1137

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

    // Sized as a fraction of one tile-width so it reads as a small kitchen item sitting on the
    // table rather than dominating it.
    static let width = GroundTile.width * 0.36

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
