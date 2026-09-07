import SpriteKit
import SwiftUI

/// A single shop-plot ground tile: worn wooden/leather-toned flooring
/// marking where the shop building will eventually stand — replaces the
/// plain `GrassGroundTileNode` placeholder that used to sit there.
///
/// Unlike `GrassGroundTileNode` (which *defines* the shared grid's spacing
/// unit), this tile has no say in the grid — it fits itself to whatever
/// `IsoGrid` is handed to it at init, exactly like `FieldGroundTileNode`/
/// `RoadGroundTileNode`.
final class ShopGroundTileNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "ground_tile_shop")

    /// Same measurement as `GrassGroundTileNode.topFaceHeightFraction`, but
    /// for this asset. Source already had a clean alpha channel (no
    /// background-keying needed, unlike field/road). Alpha-trimmed bbox
    /// 1067×694, top vertex y≈0, front vertex y≈643 ⇒ rhombus height ≈643
    /// of the sprite's 693 vertex-to-vertex span, ≈0.928. Left/right
    /// corners sat at y≈283/290, off from the true midpoint the top/front
    /// vertices imply (≈321.5) by a similar margin to grass/field's raw
    /// art, so it went through the same one-off 4-point homography warp
    /// before being saved, correcting the left/right corners onto the
    /// exact symmetric diamond.
    static let topFaceHeightFraction: CGFloat = 0.928

    /// Same role as `GrassGroundTileNode.topFaceCenterAnchorY`, for this
    /// tile: `1 - (0 + 643/2) / 694 ≈ 0.537`.
    static let topFaceCenterAnchorY: CGFloat = 0.537

    /// Same non-uniform grid-fitting approach as `FieldGroundTileNode`/
    /// `RoadGroundTileNode` — see `FieldGroundTileNode`'s doc comment for
    /// why a single uniform scale can't work (native footprint aspect
    /// 1067/643 ≈ 1.66, close to grass's ≈1.51 but not identical).
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let native = texture.size()
        let nativeHeight = native.height > 0 ? native.height : 694.0
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
        fatalError("init(coder:) is not supported for ShopGroundTileNode")
    }
}

#Preview("Shop Ground Tile") {
    // A 2×2 patch of this tile alone — see FieldGroundTileNode's preview
    // for why (isolates this asset's own measured geometry from
    // GroundLayer's spacing tuning and every other tile type).
    let footprintWidth: CGFloat = 128
    let nativeAspect: CGFloat = {
        let native = SKTexture(imageNamed: "ground_tile_shop").size()
        return native.height > 0 ? native.width / native.height : 1067.0 / 694.0
    }()
    let grid = IsoGrid(
        tileWidth: footprintWidth,
        tileHeight: (footprintWidth / nativeAspect) * ShopGroundTileNode.topFaceHeightFraction
    )
    let range = 0..<2

    let scene = SKScene(size: CGSize(width: 300, height: 300))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = GroundTile.fillColor

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
            let tile = ShopGroundTileNode(fittingTo: grid)
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
