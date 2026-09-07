import SpriteKit
import SwiftUI

/// Legacy sheared-parallelogram tile geometry. This described the *old*
/// ground art (a flat, seamless repeat texture stretched into a sheared
/// parallelogram and clipped) and is kept only because `ShopWallNode`,
/// `FarmerNode`, `FieldLayerNode`, `KitchenNode`, and `KitchenTableNode`
/// still position themselves with this formula. `GroundLayer` itself no
/// longer uses it — see `IsoGrid` below for the new true-isometric grid.
/// Do not change these values without checking every one of those call
/// sites first.
enum GroundTile {
    static let width: CGFloat = 64
    static let height: CGFloat = 32
    static let skew: CGFloat = width / 4

    static let fillColor = SKColor(red: 0.69, green: 0.78, blue: 0.26, alpha: 1)
    static let strokeColor = SKColor(red: 0.2, green: 0.19, blue: 0.16, alpha: 1)

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width + skew, y: height))
        path.addLine(to: CGPoint(x: skew, y: height))
        path.closeSubpath()
        return path
    }()
}

/// A reusable true-isometric (2.5D) diamond-grid coordinate transform.
///
/// Unlike `GroundTile`'s sheared-parallelogram grid, this projects
/// `(col, row)` grid coordinates onto screen positions with the standard
/// isometric diamond formula, adapted for SpriteKit's y-up coordinate
/// space:
///
///     screenX = (col - row) * tileWidth / 2
///     screenY = -(col + row) * tileHeight / 2
///
/// The y term is negated relative to the textbook y-down formula so that
/// increasing `col` and/or `row` moves a tile toward the *bottom* of the
/// screen (visually nearer, "south") rather than the top — matching how
/// painter's-algorithm depth sorting expects a diamond grid to recede.
///
/// `tileWidth`/`tileHeight` are the grid's spacing unit along each screen
/// axis — how far apart adjacent tile centers sit — not necessarily the
/// pixel size of whatever's drawn at each point. A caller decides what
/// that unit should be. Note that a step of 1 in `col` or `row` alone (a
/// diagonal on-screen neighbor) moves by only *half* a spacing unit in
/// each axis, while a step in both together (a straight-down/up/left/right
/// on-screen neighbor) moves by a *full* unit — inherent to this formula.
/// So sprites sized to exactly the spacing unit sit flush against their
/// straight neighbors but always overlap their diagonal ones by a quarter
/// of their area; see `GroundLayer` for how that plays out with art that
/// has content (a dirt skirt) extending past its flat top-face footprint.
struct IsoGrid {
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    /// The screen-space center of the diamond footprint at `(col, row)`,
    /// relative to the grid's own origin (col: 0, row: 0).
    func point(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col - row) * (tileWidth / 2),
            y: -CGFloat(col + row) * (tileHeight / 2)
        )
    }
}

final class GroundLayer: SKNode {

    private static let texture = SKTexture(imageNamed: "ground_tile_grass")

    /// On-screen width of one tile. Chosen independently of `GroundTile.width`
    /// (the old shear-grid's 64pt tile) since the new artwork is a much more
    /// detailed painted block that reads better at a larger scale.
    private static let footprintWidth: CGFloat = 128

    /// Full sprite size (top face + thin skirt), scaled uniformly from the
    /// texture's native aspect ratio so the art is never stretched.
    private static let spriteSize: CGSize = {
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
    private static let topFaceHeightFraction: CGFloat = 0.940

    /// Vertical center of the top rhombus (not the full sprite), as a
    /// fraction of sprite height from the *bottom* (SpriteKit's anchorPoint
    /// convention) — `1 - (6 + 631/2) / 678 ≈ 0.526`. This is what
    /// `tile.anchorPoint.y` is set to below: the point that must land
    /// exactly on the grid point for rhombus-only spacing (see `grid`) to
    /// tile edge-to-edge with zero gap/overlap.
    private static let topFaceCenterAnchorY: CGFloat = 0.526

    /// Flat pixel adjustment applied to the grid's spacing unit, in points,
    /// the same absolute amount on *both* axes. `0` (the default)
    /// reproduces the rhombus footprint exactly, so tiles sit edge-to-edge
    /// with zero gap and zero overlap — the seamless baseline derived from
    /// the measurements above, not an arbitrary starting guess.
    ///
    /// This replaced an earlier percent-based `spacingScale` multiplier:
    /// multiplying width and height by the same factor shrinks each by a
    /// *different* number of points (width's baseline is ~128pt, height's
    /// ~80pt), so it opened an uneven-looking gap per axis instead of a
    /// consistent one. A flat point value avoids that — the visible gap (or
    /// overlap) is the same number of points along both screen axes.
    ///
    /// To adjust spacing: raise above 0 to pull tiles apart by that many
    /// points (visible gaps appear, background shows through) or lower
    /// below 0 to push them closer by that many points (tiles overlap,
    /// each one increasingly buries its straight/diagonal neighbors). This
    /// is the one knob to reach for — there's no need to touch
    /// `topFaceHeightFraction` or `topFaceCenterAnchorY` (those describe
    /// the fixed art, not spacing).
    private static let spacingInset: CGFloat = -2

    /// The grid's spacing unit is the rhombus's own footprint — full sprite
    /// width (the rhombus already spans the sprite edge to edge
    /// horizontally) by `topFaceHeightFraction` of its height, plus
    /// `spacingInset` on each — not the full sprite (face + skirt). This is
    /// standard isometric diamond math: when grid spacing exactly equals a
    /// rhombus's own bounding box, rhombi tile perfectly edge-to-edge with
    /// zero gap *and* zero overlap for every neighbor, straight and
    /// diagonal alike. The thin skirt (sprite content below the rhombus,
    /// excluded from this spacing) then hangs down into the screen region
    /// the true south neighbor — `(col+1, row+1)`, a full grid step down —
    /// occupies, and gets buried by that neighbor's own opaque art,
    /// provided that neighbor is drawn after it (see zPosition below).
    private static let grid = IsoGrid(
        tileWidth: spriteSize.width + spacingInset,
        tileHeight: spriteSize.height * topFaceHeightFraction + spacingInset
    )

    /// The `(col, row)` bounds of the patch actually drawn. A small fixed
    /// 3×3 block (rather than filling the whole viewport) centered on
    /// `centerCol`/`centerRow` — the single grass tile — surrounded by a
    /// ring of field tiles.
    private static let gridColumns = -1..<2
    private static let gridRows = -1..<2
    private static let centerCol = 0
    private static let centerRow = 0

    private static func isCenter(col: Int, row: Int) -> Bool {
        col == centerCol && row == centerRow
    }

    // MARK: - Field (plowed farm plot) tile

    private static let fieldTexture = SKTexture(imageNamed: "ground_tile_field")

    /// Same measurement as `topFaceHeightFraction`, but for
    /// `ground_tile_field` (a different source asset — plowed, furrowed
    /// soil rather than grass). Measured the same way: alpha-trimmed bbox
    /// 1078×660, top vertex y≈2, front vertex y≈606 ⇒ rhombus height ≈604
    /// of the sprite's 657 vertex-to-vertex span, ≈0.919. Like the grass
    /// art, the raw source wasn't a perfectly symmetric diamond (its
    /// left/right corners sat well above the true midpoint implied by the
    /// top/front vertices — this one is noticeably more front-heavy than
    /// the grass tile was), so it went through the same one-off 4-point
    /// homography warp before being saved, correcting the left/right
    /// corners onto the exact symmetric diamond.
    private static let fieldTopFaceHeightFraction: CGFloat = 0.919

    /// Same role as `topFaceCenterAnchorY`, for the field tile:
    /// `1 - (2 + 604/2) / 660 ≈ 0.539`.
    private static let fieldTopFaceCenterAnchorY: CGFloat = 0.539

    /// The field tile must interlock with the grass grid, so it can't just
    /// get its own uniformly-scaled `spriteSize` the way grass does — its
    /// native footprint aspect (1078/604 ≈ 1.78) differs from grass's
    /// (≈1.51), so one scale factor can't fit both its width *and* its
    /// footprint-height to the shared `grid` cell at once. Instead this
    /// scales each axis independently: width is forced to exactly
    /// `grid.tileWidth` (matching every grass tile's own rendered width),
    /// and a separate Y scale is chosen so the native *footprint* height
    /// (not the full sprite) maps to exactly `grid.tileHeight` — then that
    /// same Y scale is applied to the full native height, so the skirt
    /// below the footprint scales proportionally with it rather than
    /// getting stretched independently.
    private static let fieldSpriteSize: CGSize = {
        let native = fieldTexture.size()
        let nativeHeight = native.height > 0 ? native.height : 660.0
        let nativeTopFaceHeight = nativeHeight * fieldTopFaceHeightFraction
        let yScale = nativeTopFaceHeight > 0 ? grid.tileHeight / nativeTopFaceHeight : 1
        return CGSize(width: grid.tileWidth, height: nativeHeight * yScale)
    }()

    func layout(for size: CGSize) {
        removeAllChildren()
        guard size.width > 0, size.height > 0 else { return }

        let spriteSize = Self.spriteSize

        // gridColumns/gridRows is an arbitrary (col, row) rectangle, and
        // IsoGrid's origin (0, 0) isn't generally its centroid — so average
        // every cell's grid point and use that as the centering offset,
        // keeping the patch centered on screen regardless of which range
        // is configured above.
        var sum = CGPoint.zero
        var count = 0
        for row in Self.gridRows {
            for col in Self.gridColumns {
                let point = Self.grid.point(col: col, row: row)
                sum.x += point.x
                sum.y += point.y
                count += 1
            }
        }
        guard count > 0 else { return }
        let centroid = CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
        let originOffset = CGPoint(x: size.width / 2 - centroid.x, y: size.height / 2 - centroid.y)

        for row in Self.gridRows {
            for col in Self.gridColumns {
                // The single center cell keeps the grass texture; every
                // other cell in the patch renders as a field tile — a
                // grass tile with a ring of field around it.
                let isCenter = Self.isCenter(col: col, row: row)
                let tile = SKSpriteNode(texture: isCenter ? Self.texture : Self.fieldTexture)
                tile.size = isCenter ? spriteSize : Self.fieldSpriteSize
                // Each tile type's own rhombus vertical center (not the
                // full sprite's) must land on the grid point — see
                // `topFaceCenterAnchorY`/`fieldTopFaceCenterAnchorY`.
                // Horizontally both rhombi are already centered in their
                // sprite, so 0.5 is correct as-is for either.
                tile.anchorPoint = CGPoint(x: 0.5, y: isCenter ? Self.topFaceCenterAnchorY : Self.fieldTopFaceCenterAnchorY)
                let point = Self.grid.point(col: col, row: row)
                tile.position = CGPoint(x: point.x + originOffset.x, y: point.y + originOffset.y)
                // Standard back-to-front painter's algorithm: tiles further
                // "south" (higher col + row) are nearer the viewer and are
                // drawn after — on top of — the tiles behind them, so a
                // south tile's own art fully buries the skirt the north
                // tile behind it left hanging into its territory (see
                // `grid`'s doc comment). Matches the row-based zPosition
                // convention already used by FarmerNode/ShopWallNode.
                tile.zPosition = CGFloat(col + row)
                addChild(tile)
            }
        }
    }
}

// MARK: - Preview

/// Minimal scene wrapper so `GroundLayer` — an `SKNode`, not a view — can be
/// driven by SwiftUI's `SpriteView` in an Xcode canvas preview. Exists only
/// for the preview below; `MainStallScene` builds its own real scene.
private final class GroundPreviewScene: SKScene {
    private let groundLayer = GroundLayer()

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor
        addChild(groundLayer)
        groundLayer.layout(for: size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        groundLayer.layout(for: size)
    }
}

#Preview("Ground Tile Grid") {
    let scene = GroundPreviewScene(size: CGSize(width: 400, height: 700))
    scene.scaleMode = .resizeFill
    return SpriteView(scene: scene)
        .frame(width: 400, height: 700)
        .ignoresSafeArea()
}
