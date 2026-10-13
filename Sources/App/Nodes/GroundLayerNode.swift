import SpriteKit
import SwiftUI

/// Legacy sheared-parallelogram tile geometry. This described the *old*
/// ground art (a flat, seamless repeat texture stretched into a sheared
/// parallelogram and clipped) and is kept only because the scene reads
/// `fillColor` and `KitchenTableNode` and the Kitchen bowl nodes still
/// size themselves with it. `GroundLayer` itself no longer uses it — see
/// `IsoGrid` below for the new true-isometric grid. Do not change these
/// values without checking every one of those call sites first.
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
        point(col: CGFloat(col), row: CGFloat(row))
    }

    /// Same projection, for a footprint centered off-cell (a fractional
    /// `col`/`row`) rather than on a whole grid cell.
    func point(col: CGFloat, row: CGFloat) -> CGPoint {
        CGPoint(
            x: (col - row) * (tileWidth / 2),
            y: -(col + row) * (tileHeight / 2)
        )
    }
}

/// Lays out ground tiles on `IsoGrid` from a literal map (see `map` below):
/// a `ShopGroundTileNode` marking the shop plot, ringed by
/// `FieldGroundTileNode`s and a `GrassGroundTileNode` border (with a
/// `RoadGroundTileNode` entry path) for `FieldLayer` to
/// place their own content on — with plain grass filling every other cell
/// the current viewport can show, so the ground never runs out into bare
/// background beyond `map`'s own small footprint (see `kind(atCol:row:)`).
/// See `Nodes/Tiles/` for the individual tile types — this class owns only
/// the grid itself (spacing, map data, draw order), not any tile's own
/// art or measured geometry.
final class GroundLayer: SKNode {

    /// Flat pixel adjustment applied to the grid's spacing unit, in points,
    /// the same absolute amount on *both* axes. `0` (the default)
    /// reproduces the grass tile's rhombus footprint exactly, so tiles sit
    /// edge-to-edge with zero gap and zero overlap — the seamless baseline
    /// derived from `GrassGroundTileNode`'s own measurements, not an
    /// arbitrary starting guess.
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
    /// is the one knob to reach for — there's no need to touch anything in
    /// `GrassGroundTileNode` (its measured constants describe the fixed
    /// art, not spacing).
    private static let spacingInset: CGFloat = -2

    /// The grid's spacing unit is `GrassGroundTileNode`'s own rhombus
    /// footprint — full sprite width (the rhombus already spans the sprite
    /// edge to edge horizontally) by `topFaceHeightFraction` of its
    /// height, plus `spacingInset` on each — not the full sprite (face +
    /// skirt). This is standard isometric diamond math: when grid spacing
    /// exactly equals a rhombus's own bounding box, rhombi tile perfectly
    /// edge-to-edge with zero gap *and* zero overlap for every neighbor,
    /// straight and diagonal alike. The thin skirt (sprite content below
    /// the rhombus, excluded from this spacing) then hangs down into the
    /// screen region the true south neighbor — `(col+1, row+1)`, a full
    /// grid step down — occupies, and gets buried by that neighbor's own
    /// opaque art, provided that neighbor is drawn after it (see
    /// zPosition below). Every other tile type (`FieldGroundTileNode`)
    /// fits itself to this same `grid` rather than defining its own. Not
    /// private: `FieldLayer` positions its own content
    /// (crops, farmers) directly against this same grid — same world
    /// space, no separate centering step — so it lines up with the
    /// ground tiles beneath it.
    static let grid = IsoGrid(
        tileWidth: GrassGroundTileNode.spriteSize.width + spacingInset,
        tileHeight: GrassGroundTileNode.spriteSize.height * GrassGroundTileNode.topFaceHeightFraction + spacingInset
    )

    /// The ground's fixed layout as literal map data: outer array is rows
    /// from north/back (index 0) to south/front (last index); each inner
    /// array is that row's tiles from west/left (index 0) to east/right
    /// (last index) — ordinary top-to-bottom, left-to-right reading order,
    /// matching how the array literal below actually looks written out.
    /// Every row must be the same length (`layout(for:)` traps otherwise —
    /// a ragged map has no sensible single origin/column count).
    ///
    /// This is the source of truth for what's drawn where, with one
    /// deliberate exception: the shop's own cells. `kind(atCol:row:)`
    /// checks `ShopNode.defaultPlacement` — not this array — to decide
    /// whether a cell is a shop cell, so the rows this literal spans for
    /// the shop (7-9 below) are written as plain `.field` and never
    /// actually read for those cells; `ShopNode.defaultPlacement` is the
    /// one place that rectangle is spelled out as numbers (see its own
    /// doc comment for why: a second `.shop` literal here could silently
    /// drift out of sync with the placement `MainStallScene` actually
    /// builds its `ShopNode` from). `layout(for:)` walks this array,
    /// translating each `(rowIndex, colIndex)` into an `IsoGrid` `(col,
    /// row)` via `mapOrigin`. To reshape the ground — grow it, carve out
    /// a different field shape — edit this array; to move or resize the
    /// shop, edit `ShopNode.defaultPlacement` instead.
    ///
    /// Shape: a 1-row grass border, six field rows (unchanged from before
    /// the shop grew — `FieldLayer` sits at fixed rows
    /// relative to this block and must not move), three shop rows, then a
    /// 1-row grass border whose middle tile is `.road` instead: a stone
    /// path continuing straight out from the shop plot toward the viewer,
    /// like a doorstep leading up to the shop building.
    ///
    /// Row count dropped from 12 to 11 along with `ShopNode.defaultHeight`
    /// (4 -> 3): trimming only `defaultHeight` would leave this array's
    /// row 10 as a real, still-read `.field` row wedged between the
    /// shop's new south wall and its own doorstep, instead of removing
    /// the shop's last row outright.
    private static let map: [[GroundTileKind]] = [
        [.grass, .grass, .grass, .grass, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .field, .field, .field, .grass],
        [.grass, .grass, .road,  .grass, .grass],
    ]

    /// `IsoGrid` `(col, row)` of `map[0][0]` — the map's north-west
    /// corner. Every other cell's grid coordinate is this plus its own
    /// `(rowIndex, colIndex)` offset (see `gridCoordinate(rowIndex:
    /// colIndex:)`). Keeps the shop plot's own first cell (row 7, col 2 in
    /// `map` — the single cell it used to occupy before growing to a 3×3
    /// block) at `IsoGrid` row/col 0, matching where earlier iterations of
    /// this grid anchored it, so `FieldLayer`'s own fixed row
    /// constants (tuned against that anchor) don't need to change just
    /// because `map` grew rows to fit the shop's new size.
    ///
    /// Not private: `ShopNode` reads this indirectly through
    /// `gridCoordinate(rowIndex:colIndex:)` to convert its own
    /// map-array-index placement into `IsoGrid` coordinates, rather than
    /// re-deriving "mapOrigin.col + x" locally.
    static let mapOrigin = (col: -2, row: -7)

    /// Map-array-index coordinates (`rowIndex`/`colIndex`, 0-based from
    /// `map`'s own top-left corner — the same space `ShopPlacement`'s
    /// `originX`/`originY` use) → `IsoGrid` `(col, row)`. Not private:
    /// `ShopNode` calls this to place itself without duplicating
    /// `mapOrigin`'s arithmetic.
    static func gridCoordinate(rowIndex: Int, colIndex: Int) -> (col: Int, row: Int) {
        (mapOrigin.col + colIndex, mapOrigin.row + rowIndex)
    }

    /// `IsoGrid` rows/columns `map` itself covers (without the world
    /// margin) — what `LocationBackdropNode` lines its walls up against.
    static var mapRows: ClosedRange<Int> { mapOrigin.row...(mapOrigin.row + map.count - 1) }
    static var mapColumns: ClosedRange<Int> {
        mapOrigin.col...(mapOrigin.col + (map.first?.count ?? 1) - 1)
    }

    /// `IsoGrid` column just past `map`'s own east edge (`mapOrigin.col`
    /// plus `map`'s column count) — tracks `map`'s actual width rather
    /// than a hardcoded literal. `ShopCustomerSpawner` spawns customers a
    /// few more columns out from here, on the shop's service row.
    static var eastMapEdgeColumn: Int {
        mapOrigin.col + (map.first?.count ?? 0)
    }

    /// `map`'s tile at `(col, row)`, or `.grass` if that cell falls
    /// outside `map`'s own bounds — the open lawn ringing the farm/shop
    /// plot out to `worldColumns`/`worldRows`'s edge. Checks
    /// `ShopNode.defaultPlacement` before consulting `map` at all: the
    /// shop's rectangle lives there, not as a `.shop` literal in `map`
    /// (see that constant's own doc comment) — this is the one place
    /// "is this cell a shop cell" gets answered, so it can't disagree with
    /// what `ShopNode` itself draws.
    private static func kind(atCol col: Int, row: Int) -> GroundTileKind {
        let rowIndex = row - mapOrigin.row
        let colIndex = col - mapOrigin.col
        if ShopNode.defaultPlacement.contains(mapX: colIndex, mapY: rowIndex) {
            return .shop
        }
        guard map.indices.contains(rowIndex), map[rowIndex].indices.contains(colIndex) else {
            return .grass
        }
        return map[rowIndex][colIndex]
    }

    /// Extra rings of plain grass drawn beyond `map`'s own footprint —
    /// this (not the viewport) is what bounds how far the ground extends
    /// and therefore how far the camera can pan — see `worldColumns`/
    /// `worldRows`/`clampedCameraPosition(_:viewportSize:)`.
    ///
    /// Needs to clear `clampedCameraPosition`'s own viewport-derived
    /// margin (half the *viewport's* col/row span, ~7 units on a typical
    /// phone at this grid's tile size) before any panning is actually
    /// possible at all — below that, every camera position clamps back to
    /// dead-center (confirmed: `2` visibly did this, no scroll range
    /// whatsoever). `10` clears that with real room to spare.
    private static let marginTiles = 10

    /// The fixed `(col, row)` extent of every tile this layer will ever
    /// draw: `map`'s own bounds (via `mapOrigin`) padded by `marginTiles`
    /// on every side. Unlike earlier revisions of this file, this is no
    /// longer computed from the current viewport size — `layout()` draws
    /// this fixed region exactly once, in world space, and a camera (see
    /// `MainStallScene`) pans within it instead of tiles being regenerated
    /// to chase whatever the screen happens to show.
    private static let worldColumns: ClosedRange<Int> = {
        let columnCount = map.first?.count ?? 0
        return (mapOrigin.col - marginTiles)...(mapOrigin.col + columnCount - 1 + marginTiles)
    }()
    private static let worldRows: ClosedRange<Int> = {
        (mapOrigin.row - marginTiles)...(mapOrigin.row + map.count - 1 + marginTiles)
    }()

    /// Clamps a proposed camera position so a viewport of `viewportSize`
    /// centered there never shows anything beyond `worldColumns`/
    /// `worldRows` — the actual bounded, pannable extent of the ground
    /// ("size limited by map data" the scrollable area is bounded by).
    ///
    /// Works in `(col, row)` space rather than a plain x/y bounding box.
    /// `worldColumns`×`worldRows` is a rectangle in `(col, row)` space,
    /// but `IsoGrid` renders it as a *diamond* on screen — its x/y
    /// bounding box's own corners sit in the diamond's empty "notches",
    /// outside the diamond itself. Clamping the camera's raw x/y against
    /// that box would let it reach those corners and reveal empty
    /// background there (confirmed visually — this replaced an earlier,
    /// wrong version that did exactly that). Converting the camera to
    /// `(col, row)` first and clamping *that* keeps it — and therefore
    /// every corner of its viewport — inside the actual rectangular
    /// region, whatever its on-screen (rotated) shape.
    static func clampedCameraPosition(_ proposed: CGPoint, viewportSize: CGSize) -> CGPoint {
        // Half the (col, row) span a viewport this size covers around its
        // own center — same inversion `IsoGrid.point(col:row:)` doc
        // describes, applied to the viewport's half-extents rather than a
        // single point (a corner offset by (±halfWidth, ±halfHeight) from
        // center always lands `halfWidth/tileWidth + halfHeight/tileHeight`
        // col/row units away, regardless of which corner — the same margin
        // in every direction).
        let margin = (viewportSize.width / 2) / grid.tileWidth + (viewportSize.height / 2) / grid.tileHeight

        var col = proposed.x / grid.tileWidth - proposed.y / grid.tileHeight
        var row = -proposed.y / grid.tileHeight - proposed.x / grid.tileWidth

        let colLower = CGFloat(worldColumns.lowerBound) + margin
        let colUpper = CGFloat(worldColumns.upperBound) - margin
        col = colLower <= colUpper
            ? min(max(col, colLower), colUpper)
            : CGFloat(worldColumns.lowerBound + worldColumns.upperBound) / 2

        let rowLower = CGFloat(worldRows.lowerBound) + margin
        let rowUpper = CGFloat(worldRows.upperBound) - margin
        row = rowLower <= rowUpper
            ? min(max(row, rowLower), rowUpper)
            : CGFloat(worldRows.lowerBound + worldRows.upperBound) / 2

        let x = (col - row) * (grid.tileWidth / 2)
        let y = -(col + row) * (grid.tileHeight / 2)
        return CGPoint(x: x, y: y)
    }

    /// World-space centroid of `map`'s own cells (the farm/shop plot, not
    /// the larger `worldColumns`/`worldRows` padded region). `MainStallScene`
    /// starts its camera here so the farm is centered on first launch —
    /// the same framing this grid had before panning existed.
    static var mapCentroid: CGPoint {
        var sum = CGPoint.zero
        var count = 0
        for rowIndex in map.indices {
            for colIndex in map[rowIndex].indices {
                let (col, row) = gridCoordinate(rowIndex: rowIndex, colIndex: colIndex)
                let point = grid.point(col: col, row: row)
                sum.x += point.x
                sum.y += point.y
                count += 1
            }
        }
        guard count > 0 else { return .zero }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }

    /// The doorstep road tile's variant per `locationTier`, built once by
    /// `layout()` and toggled by `applyLocationTier`.
    private var roadTilesByLocation: [Int: RoadGroundTileNode] = [:]
    private var grassTiles: [GrassGroundTileNode] = []
    private var appliedLocationTier = 0

    /// Per-location grass tint, indexed by tier. SpriteKit lerps the
    /// texture toward `color` by `blend`, so each result is measured
    /// against the baked grass' mean colour (0.45, 0.71, 0.15) — a
    /// saturated yellow-green that a 0.15-0.30 blend with a mid colour
    /// barely moved (the first attempt looked identical across
    /// locations). Resulting mean colour per tier:
    ///   alley   (0.41, 0.60, 0.27)  muted, slightly cool
    ///   market  (0.68, 0.67, 0.22)  straw / olive-yellow
    ///   Gangnam (0.36, 0.57, 0.46)  cool grey blue-green
    /// Blend stays at 0.45-0.60 so the painted blades keep about half
    /// their contrast. `GroundTile.fillColor` (scene background,
    /// transition veil) is deliberately not tinted: it is shared, and the
    /// veil must match the background it fades to.
    private static let grassTints: [(color: SKColor, blend: CGFloat)] = [
        (SKColor(red: 0.36, green: 0.46, blue: 0.42, alpha: 1), 0.45),  // alley
        (SKColor(red: 0.90, green: 0.62, blue: 0.28, alpha: 1), 0.50),  // market
        (SKColor(red: 0.30, green: 0.48, blue: 0.66, alpha: 1), 0.60),  // Gangnam
    ]

    /// Tier clamped into `grassTints`' (and the road variants') range.
    private static func clampedTier(_ tier: Int) -> Int {
        max(0, min(tier, min(RoadGroundTileNode.variantCount, grassTints.count) - 1))
    }

    private static func tintGrass(_ tile: GrassGroundTileNode, tier: Int) {
        let tint = grassTints[tier]
        tile.color = tint.color
        tile.colorBlendFactor = tint.blend
    }

    /// Shows the road tile and grass tint for `tier` (clamped) and hides
    /// the other road variants.
    func applyLocationTier(_ tier: Int) {
        let shown = Self.clampedTier(tier)
        appliedLocationTier = shown
        for (index, node) in roadTilesByLocation {
            node.isHidden = index != shown
        }
        for tile in grassTiles {
            Self.tintGrass(tile, tier: shown)
        }
    }

    /// Draws every tile in `worldColumns` × `worldRows` exactly once, at
    /// its raw `IsoGrid` world position — no per-call centering offset.
    /// `MainStallScene`'s camera (not this layout pass) is what frames
    /// this on screen; call this once, not on every size change.
    func layout() {
        removeAllChildren()
        roadTilesByLocation = [:]
        grassTiles = []
        precondition(
            Set(Self.map.map(\.count)).count <= 1,
            "GroundLayer.map rows must all be the same length"
        )

        for row in Self.worldRows {
            for col in Self.worldColumns {
                let kind = Self.kind(atCol: col, row: row)

                // Each tile type sizes and anchors itself in its own init,
                // so this loop only needs to place it.
                let tile: SKSpriteNode
                switch kind {
                case .grass:
                    let grass = GrassGroundTileNode()
                    Self.tintGrass(grass, tier: appliedLocationTier)
                    grassTiles.append(grass)
                    tile = grass
                case .field: tile = FieldGroundTileNode(fittingTo: Self.grid)
                case .road:
                    // One variant per location, all in the same cell and
                    // z slot; `applyLocationTier` shows exactly one.
                    for tier in 0..<RoadGroundTileNode.variantCount {
                        let road = RoadGroundTileNode(location: tier, fittingTo: Self.grid)
                        road.position = Self.grid.point(col: col, row: row)
                        road.zPosition = CGFloat(col + row)
                        road.isHidden = tier != appliedLocationTier
                        addChild(road)
                        roadTilesByLocation[tier] = road
                    }
                    continue
                case .shop:
                    // ShopNode — added separately by whoever assembles the
                    // scene (MainStallScene, GroundPreviewScene below) —
                    // draws its own ground tiles for exactly this
                    // footprint as part of the same unit that also draws
                    // its walls (see ShopNode's own doc comment). Skipping
                    // here avoids a second, identically-positioned but
                    // differently-z-ordered copy underneath it.
                    continue
                }

                tile.position = Self.grid.point(col: col, row: row)
                // Standard back-to-front painter's algorithm: tiles further
                // "south" (higher col + row) are nearer the viewer and are
                // drawn after — on top of — the tiles behind them, so a
                // south tile's own art fully buries the skirt the north
                // tile behind it left hanging into its territory (see
                // `grid`'s doc comment).
                tile.zPosition = CGFloat(col + row)
                addChild(tile)
            }
        }
    }
}

/// One cell of `GroundLayer.map`.
enum GroundTileKind {
    case grass
    case field
    case road
    case shop
}

// MARK: - Preview

/// Minimal scene wrapper so `GroundLayer` — an `SKNode`, not a view — can be
/// driven by SwiftUI's `SpriteView` in an Xcode canvas preview. Exists only
/// for the preview below; `MainStallScene` builds its own real scene.
///
/// `GroundLayer.layout()` draws in raw world space now (no per-call
/// centering) — a real camera, positioned at `GroundLayer.mapCentroid`,
/// is what frames the farm/shop plot on screen here, mirroring how
/// `MainStallScene` frames (and pans) the same content.
private final class GroundPreviewScene: SKScene {
    private let groundLayer = GroundLayer()
    private let cameraNode = SKCameraNode()

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = GroundLayer.mapCentroid

        addChild(groundLayer)
        groundLayer.layout()

        // groundLayer.layout() deliberately leaves the shop's own cells
        // blank (see its `.shop` case) — ShopNode is what actually draws
        // there, added here the same way MainStallScene adds its own, so
        // this preview shows the real, current shop plot rather than a
        // hole where it used to be a single tile.
        let shop = ShopNode(
            originX: ShopNode.defaultPlacement.originX,
            originY: ShopNode.defaultPlacement.originY,
            fittingTo: GroundLayer.grid
        )
        addChild(shop)
    }
}

#Preview("Ground Tile Grid") {
    let scene = GroundPreviewScene(size: CGSize(width: 400, height: 700))
    scene.scaleMode = .resizeFill
    return SpriteView(scene: scene)
        .frame(width: 400, height: 700)
        .ignoresSafeArea()
}
