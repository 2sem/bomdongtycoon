import SpriteKit
import SwiftUI

/// A single stone-path ground tile: a 5×5 mosaic of small paving stones,
/// used as a walkway rather than open ground.
///
/// Unlike `GrassGroundTileNode` (which *defines* the shared grid's spacing
/// unit), this tile has no say in the grid — it fits itself to whatever
/// `IsoGrid` is handed to it at init, exactly like `FieldGroundTileNode`.
final class RoadGroundTileNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "ground_tile_road")

    /// Same measurement as `GrassGroundTileNode.topFaceHeightFraction`, but
    /// for this asset. Measured the same way: source was a flat-white-bg
    /// JPEG (no alpha), so it was first background-keyed (connected-
    /// component threshold, same technique used for the original grass/
    /// field art before they got clean pre-transparent replacements), then
    /// alpha-trimmed to 1107×696. Top vertex y≈0, front vertex y≈642 ⇒
    /// rhombus height ≈642 of the sprite's 695 vertex-to-vertex span,
    /// ≈0.924. Left/right corners sat at y≈304/303 — already close to
    /// symmetric (this is a regular geometric mosaic pattern, not
    /// hand-painted, so less natural wobble than the grass/field art had)
    /// but still off from the true midpoint the top/front vertices imply,
    /// so it went through the same one-off 4-point homography warp before
    /// being saved, correcting the left/right corners onto the exact
    /// symmetric diamond.
    static let topFaceHeightFraction: CGFloat = 0.924

    /// Same role as `GrassGroundTileNode.topFaceCenterAnchorY`, for this
    /// tile: `1 - (0 + 642/2) / 696 ≈ 0.539`.
    static let topFaceCenterAnchorY: CGFloat = 0.539

    /// Same non-uniform grid-fitting approach as `FieldGroundTileNode` —
    /// see that type's doc comment for why a single uniform scale can't
    /// work here either (native footprint aspect 1107/642 ≈ 1.72, close
    /// to grass's ≈1.51 but not identical).
    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let native = texture.size()
        let nativeHeight = native.height > 0 ? native.height : 696.0
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
        fatalError("init(coder:) is not supported for RoadGroundTileNode")
    }
}

#Preview("Road Ground Tile") {
    // A 2×2 patch of this tile alone — see FieldGroundTileNode's preview
    // for why (isolates this asset's own measured geometry from
    // GroundLayer's spacing tuning and every other tile type).
    let footprintWidth: CGFloat = 128
    let nativeAspect: CGFloat = {
        let native = SKTexture(imageNamed: "ground_tile_road").size()
        return native.height > 0 ? native.width / native.height : 1107.0 / 696.0
    }()
    let grid = IsoGrid(
        tileWidth: footprintWidth,
        tileHeight: (footprintWidth / nativeAspect) * RoadGroundTileNode.topFaceHeightFraction
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
            let tile = RoadGroundTileNode(fittingTo: grid)
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
