import SpriteKit
import SwiftUI

/// A single grass ground tile: the isometric block sprite, sized and
/// anchored so its own rhombus tiles seamlessly on `IsoGrid`.
///
/// This tile's own measured geometry also defines the shared grid's
/// spacing unit (see `GroundLayer.grid`) — every other tile type
/// (`FieldGroundTileNode`) fits itself to this one, not the other way
/// around, so this is the one tile whose numbers are load-bearing for the
/// whole grid's tilt and scale.
final class GrassGroundTileNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "ground_tile_grass")

    /// On-screen width of one tile. Chosen independently of `GroundTile.width`
    /// (the old shear-grid's 64pt tile) since this artwork is a much more
    /// detailed painted block that reads better at a larger scale.
    static let footprintWidth: CGFloat = 128

    /// Full sprite size (top face + thin skirt), scaled uniformly from the
    /// texture's native aspect ratio so the art is never stretched.
    static let spriteSize: CGSize = {
        let native = texture.size()
        let aspect = native.height > 0 ? native.width / native.height : 1024.0 / 678.0
        return CGSize(width: footprintWidth, height: footprintWidth / aspect)
    }()

    /// Fraction of the sprite's rendered height that is the top rhombus
    /// *face only* (from its back/top vertex down to its own front vertex,
    /// not including the thin dark edge/skirt below). Measured against the
    /// original hand-drawn art (alpha-trimmed to 1024×678): top vertex
    /// y≈6, front vertex y≈637 ⇒ rhombus height ≈631 of 671, ≈0.940. The
    /// raw art wasn't a perfectly symmetric diamond — its left/right
    /// corners sat at y≈300/309, off by several px from the true midpoint
    /// implied by the top/front vertices — so before this PNG was saved,
    /// a one-off perspective warp (4-point homography, measured corners
    /// → exact symmetric diamond with the same top/front vertex y's) was
    /// applied to the source image to correct that. The warp only moved
    /// the left/right corners; top/front vertex y's were fixed points of
    /// it, so this fraction is unchanged by the correction.
    static let topFaceHeightFraction: CGFloat = 0.940

    /// Vertical center of the top rhombus (not the full sprite), as a
    /// fraction of sprite height from the *bottom* (SpriteKit's anchorPoint
    /// convention) — `1 - (6 + 631/2) / 678 ≈ 0.526`. This is what
    /// `anchorPoint.y` is set to below: the point that must land exactly
    /// on the grid point for rhombus-only spacing (see `GroundLayer.grid`)
    /// to tile edge-to-edge with zero gap/overlap.
    static let topFaceCenterAnchorY: CGFloat = 0.526

    init() {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize)
        anchorPoint = CGPoint(x: 0.5, y: Self.topFaceCenterAnchorY)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for GrassGroundTileNode")
    }
}

#Preview("Grass Ground Tile") {
    let scene = SKScene(size: CGSize(width: 200, height: 200))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = GroundTile.fillColor
    let tile = GrassGroundTileNode()
    tile.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
    scene.addChild(tile)
    return SpriteView(scene: scene)
        .frame(width: 200, height: 200)
        .ignoresSafeArea()
}
