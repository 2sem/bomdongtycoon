import SpriteKit
import SwiftUI

/// The stone-path ground tile at the shop's doorstep, one variant per
/// location (`ground_road_<alley|market|gangnam>`).
///
/// Like `FieldGroundTileNode`, this has no say in the grid — it fits itself
/// to whatever `IsoGrid` it is handed. All three variants come from the
/// `tools/isorender/` rig at 3x with identical geometry (381x255 trimmed,
/// top-face centre at 0.535 from the bottom), so they swap in place with
/// no per-location offsets.
final class RoadGroundTileNode: SKSpriteNode {

    private static let imageNames = ["ground_road_alley", "ground_road_market", "ground_road_gangnam"]

    static var variantCount: Int { imageNames.count }

    private static let nativeSize = CGSize(width: 381, height: 255)

    /// One grid cell is 378 px wide in the 3x render (126pt on
    /// `GroundLayer.grid`); the tile is fitted by width with one uniform
    /// scale so the art is not stretched. The 3 px of overhang is the
    /// render's own ink outline.
    private static let nativeCellWidth: CGFloat = 378

    /// Top-face centre as a bottom-up fraction of the trimmed height.
    static let topFaceCenterAnchorY: CGFloat = 0.535

    /// `location` is a `locationTier`, clamped to the available variants.
    init(location: Int, fittingTo grid: IsoGrid) {
        let name = Self.imageNames[max(0, min(location, Self.imageNames.count - 1))]
        let scale = grid.tileWidth / Self.nativeCellWidth
        super.init(
            texture: SKTexture(imageNamed: name),
            color: .clear,
            size: CGSize(width: Self.nativeSize.width * scale, height: Self.nativeSize.height * scale)
        )
        anchorPoint = CGPoint(x: 0.5, y: Self.topFaceCenterAnchorY)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for RoadGroundTileNode")
    }
}

#Preview("Road Ground Tile") {
    // A 2×2 patch of the alley variant alone, isolating this asset's own
    // geometry from GroundLayer's spacing and every other tile type.
    let grid = IsoGrid(tileWidth: 126, tileHeight: 126 * 0.6)
    let range = 0..<2

    let scene = SKScene(size: CGSize(width: 300, height: 300))
    scene.scaleMode = .resizeFill
    scene.backgroundColor = GroundTile.fillColor

    for row in range {
        for col in range {
            let tile = RoadGroundTileNode(location: 0, fittingTo: grid)
            let point = grid.point(col: col, row: row)
            tile.position = CGPoint(x: point.x + 150, y: point.y + 200)
            tile.zPosition = CGFloat(col + row)
            scene.addChild(tile)
        }
    }

    return SpriteView(scene: scene)
        .frame(width: 300, height: 300)
        .ignoresSafeArea()
}
