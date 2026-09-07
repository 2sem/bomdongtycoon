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
    // A 2×2 patch of this tile alone (no grass tile, no layer-level
    // spacingInset) so a seam problem is obviously this asset's own
    // measured geometry — topFaceHeightFraction/topFaceCenterAnchorY —
    // rather than something GroundLayer or the grass tile introduced.
    // Sized the same way GrassGroundTileNode sizes itself (a 128pt-wide
    // footprint), purely for this preview — in production
    // FieldGroundTileNode never picks its own size, see
    // `spriteSize(fittingTo:)`.
    let footprintWidth: CGFloat = 128
    let nativeAspect: CGFloat = {
        let native = SKTexture(imageNamed: "ground_tile_field").size()
        return native.height > 0 ? native.width / native.height : 1078.0 / 660.0
    }()
    let grid = IsoGrid(
        tileWidth: footprintWidth,
        tileHeight: (footprintWidth / nativeAspect) * FieldGroundTileNode.topFaceHeightFraction
    )
    let range = 0..<2

    let scene = SKScene(size: CGSize(width: 300, height: 300))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = GroundTile.fillColor

    // Center the patch: IsoGrid's origin (0, 0) isn't the centroid of an
    // arbitrary (col, row) rectangle, so average every cell's point first
    // (same approach GroundLayer.layout uses for its own, larger patch).
    var sum = CGPoint.zero
    var count = 0
    for row in range {
        for col in range {
            let point = grid.point(col: col, row: row)
            sum.x += point.x
            sum.y += point.y
            count += 1
        }
    }
    let centroid = CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    let origin = CGPoint(x: scene.size.width / 2 - centroid.x, y: scene.size.height / 2 - centroid.y)

    for row in range {
        for col in range {
            let tile = FieldGroundTileNode(fittingTo: grid)
            let point = grid.point(col: col, row: row)
            tile.position = CGPoint(x: point.x + origin.x, y: point.y + origin.y)
            tile.zPosition = CGFloat(col + row)
            scene.addChild(tile)
        }
    }

    return SpriteView(scene: scene)
        .frame(width: 300, height: 300)
        .ignoresSafeArea()
}
