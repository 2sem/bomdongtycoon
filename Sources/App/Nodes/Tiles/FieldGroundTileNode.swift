import SpriteKit
import SwiftUI

/// A single plowed-field ground tile: furrowed soil rather than grass.
///
/// Unlike `GrassGroundTileNode` (which *defines* the shared grid's spacing
/// unit), this tile has no say in the grid — it fits itself to whatever
/// `IsoGrid` is handed to it at init, so it interlocks with the grass tile
/// and every other field tile regardless of its own native proportions.
final class FieldGroundTileNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "ground_tile_field")

    /// Same measurement as `GrassGroundTileNode.topFaceHeightFraction`, but
    /// for this asset — a different source image (plowed, furrowed soil
    /// rather than grass). Measured the same way: alpha-trimmed bbox
    /// 1078×660, top vertex y≈2, front vertex y≈606 ⇒ rhombus height ≈604
    /// of the sprite's 657 vertex-to-vertex span, ≈0.919. Like the grass
    /// art, the raw source wasn't a perfectly symmetric diamond (its
    /// left/right corners sat well above the true midpoint implied by the
    /// top/front vertices — this one is noticeably more front-heavy than
    /// the grass tile was), so it went through the same one-off 4-point
    /// homography warp before being saved, correcting the left/right
    /// corners onto the exact symmetric diamond.
    static let topFaceHeightFraction: CGFloat = 0.919

    /// Same role as `GrassGroundTileNode.topFaceCenterAnchorY`, for this
    /// tile: `1 - (2 + 604/2) / 660 ≈ 0.539`.
    static let topFaceCenterAnchorY: CGFloat = 0.539

    /// This tile must interlock with the grass grid, so it can't just get
    /// its own uniformly-scaled size the way `GrassGroundTileNode` does —
    /// its native footprint aspect (1078/604 ≈ 1.78) differs from grass's
    /// (≈1.51), so one scale factor can't fit both its width *and* its
    /// footprint-height to the shared grid cell at once. Instead this
    /// scales each axis independently: width is forced to exactly
    /// `grid.tileWidth` (matching every grass tile's own rendered width),
    /// and a separate Y scale is chosen so the native *footprint* height
    /// (not the full sprite) maps to exactly `grid.tileHeight` — then that
    /// same Y scale is applied to the full native height, so the skirt
    /// below the footprint scales proportionally with it rather than
    /// getting stretched independently.
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let native = texture.size()
        let nativeHeight = native.height > 0 ? native.height : 660.0
        let nativeTopFaceHeight = nativeHeight * topFaceHeightFraction
        let yScale = nativeTopFaceHeight > 0 ? grid.tileHeight / nativeTopFaceHeight : 1
        return CGSize(width: grid.tileWidth, height: nativeHeight * yScale)
    }

    init(fittingTo grid: IsoGrid) {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize(fittingTo: grid))
        anchorPoint = CGPoint(x: 0.5, y: Self.topFaceCenterAnchorY)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for FieldGroundTileNode")
    }
}

#Preview("Field Ground Tile") {
    // A grid matching GrassGroundTileNode's own native footprint, just to
    // size this preview's single tile — layer-level spacing tuning
    // (GroundLayer.spacingInset) isn't relevant to how this tile's own art
    // looks in isolation, so it's deliberately left out here.
    let grid = IsoGrid(
        tileWidth: GrassGroundTileNode.spriteSize.width,
        tileHeight: GrassGroundTileNode.spriteSize.height * GrassGroundTileNode.topFaceHeightFraction
    )
    let scene = SKScene(size: CGSize(width: 200, height: 200))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = GroundTile.fillColor
    let tile = FieldGroundTileNode(fittingTo: grid)
    tile.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
    scene.addChild(tile)
    return SpriteView(scene: scene)
        .frame(width: 200, height: 200)
        .ignoresSafeArea()
}
