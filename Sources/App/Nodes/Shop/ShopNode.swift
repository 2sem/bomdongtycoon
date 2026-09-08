import SpriteKit

/// The shop's footprint on the map: origin plus size, in the same
/// map-array-index coordinate space `GroundLayer.map`'s literal uses —
/// `x` is a column index, `y` is a row index, both 0-based from that
/// literal's own top-left corner (see `GroundLayer.gridCoordinate
/// (rowIndex:colIndex:)`, which is what actually converts a placement's
/// cells to `IsoGrid` `(col, row)`).
///
/// This is the *only* place the shop's rectangle is expressed as raw
/// numbers. `ShopNode` builds its own ground/walls from one placement,
/// and `GroundLayer.kind(atCol:row:)` asks `ShopNode.defaultPlacement`
/// whether a cell is a shop cell instead of hardcoding a second,
/// possibly-drifting copy of the same rectangle in its own map literal —
/// see that function's doc comment.
struct ShopPlacement {
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int

    /// Whether the map cell at `(mapX, mapY)` — same coordinate space as
    /// `originX`/`originY` — falls inside this rectangle. `GroundLayer`
    /// calls this with the `(colIndex, rowIndex)` it already computes for
    /// every cell it's about to draw.
    func contains(mapX: Int, mapY: Int) -> Bool {
        (originX..<(originX + width)).contains(mapX)
            && (originY..<(originY + height)).contains(mapY)
    }
}

/// A shop building: a rectangular block of `ShopGroundTileNode` ground
/// tiles, ringed on all four outer edges by the `ShopWall{Back,Right,
/// Left,Front}Node` wall segments, laid out on whatever `IsoGrid` it's
/// handed.
///
/// Placed anywhere on the map via `originX`/`originY` (map-array-index
/// coordinates — see `ShopPlacement`) and sized via `width`/`height` (in
/// map cells), defaulting to `defaultWidth`×`defaultHeight` (3×4). Owns
/// its whole footprint — ground *and* walls — as one unit built from a
/// single `ShopPlacement`, so there's exactly one place that says which
/// cells belong to the shop: `GroundLayer.kind(atCol:row:)` reads
/// `ShopNode.defaultPlacement` rather than encoding a second copy of the
/// same rectangle in its own map literal, and skips drawing ground tiles
/// under it (see that function and `GroundLayer.layout()`'s `.shop`
/// case) so this node's own ground tiles are the only copy drawn.
///
/// Generalizes `ShopWallsPreviewScene`'s original 3×3 layout (which
/// `buildGround`/`buildWalls` below are lifted from almost verbatim,
/// including its zPosition scheme) from a single square `span` to an
/// independent column range and row range — see that file for the worked
/// example this geometry was first proven against.
final class ShopNode: SKNode {

    /// Default footprint size in map cells: 3 wide (east-west, `width`)
    /// by 4 tall (north-south, `height`) — the shop's current in-game
    /// size. Exposed so `defaultPlacement` below composes from these same
    /// two numbers instead of a second hardcoded 3/4 pair that could
    /// drift out of sync with `init`'s own default arguments.
    static let defaultWidth = 3
    static let defaultHeight = 4

    /// Where the one real shop in the live game sits: map-array column 1,
    /// row 7 (`GroundLayer.map`'s own index space), at the default 3×4
    /// size. Both `MainStallScene` (to build the actual `ShopNode`) and
    /// `GroundLayer.kind(atCol:row:)` (to know which ground cells are
    /// shop cells) read this one constant rather than each hardcoding the
    /// rectangle separately — see `ShopPlacement`'s own doc comment.
    ///
    /// Row 7 is the first shop row directly beneath `GroundLayer.map`'s
    /// six field rows (indices 1-6, unchanged by the shop's move to a
    /// full 3×4 block). Column 1 keeps the block centered under the
    /// field/grass border exactly like the single legacy shop cell (row
    /// 7, col 2) it replaces — extending 3 cells wide from column 1
    /// through 3 still centers on column 2.
    static let defaultPlacement = ShopPlacement(
        originX: 1,
        originY: 7,
        width: defaultWidth,
        height: defaultHeight
    )

    /// This instance's own footprint, as handed to `init` (or the
    /// defaults it fell back on).
    let placement: ShopPlacement

    /// Painter's-order slot within a single cell — ground first, then the
    /// four walls in back-to-front order. Mirrors the old
    /// `MainStallScene`'s hand-assigned 7/8/10/11 constants (back <
    /// right < left < front, so that at a shared corner the wall nearer
    /// the camera draws on top) but as an offset added to a *per-cell*
    /// base instead of one fixed set of four numbers, so it scales to
    /// however many cells the footprint covers. See `zPosition(col:row:
    /// slot:)`.
    private enum Slot: CGFloat {
        case ground = 0
        case back = 1
        case right = 2
        case left = 3
        case front = 4
    }

    /// `(col + row) * 10` spaces every cell's own five slots (ground plus
    /// four walls) a full 10 units apart from its neighbors' — plenty of
    /// headroom for the 0...4 a single cell ever uses — while preserving
    /// cell-to-cell draw order (`col + row` grows toward the camera, the
    /// same convention `GroundLayer.layout()` uses for its own plain
    /// `col + row` zPosition). Lifted directly from
    /// `ShopWallsPreviewScene`'s own `zPosition(col:row:slot:)`, which
    /// proved this out against a real 3×3 block before the footprint
    /// became configurable.
    private static func zPosition(col: Int, row: Int, slot: Slot) -> CGFloat {
        CGFloat(col + row) * 10 + slot.rawValue
    }

    /// Builds a shop at `(originX, originY)` in map-array-index
    /// coordinates (see `ShopPlacement`), `width`×`height` cells in size
    /// (defaulting to `defaultWidth`×`defaultHeight`, 3×4), laid out on
    /// `grid`. Every ground tile and wall segment positions and z-orders
    /// itself immediately — there's no separate `layout()` call, unlike
    /// `GroundLayer`, since a shop's footprint never changes after it's
    /// placed.
    init(
        originX: Int,
        originY: Int,
        width: Int = ShopNode.defaultWidth,
        height: Int = ShopNode.defaultHeight,
        fittingTo grid: IsoGrid
    ) {
        placement = ShopPlacement(originX: originX, originY: originY, width: width, height: height)
        super.init()

        // Map-array-index coordinates → IsoGrid (col, row): the same
        // transform GroundLayer.layout() applies to every other tile
        // (see GroundLayer.gridCoordinate(rowIndex:colIndex:)), reused
        // here rather than re-deriving "mapOrigin.col + x" locally so the
        // two can't drift apart.
        let start = GroundLayer.gridCoordinate(rowIndex: originY, colIndex: originX)
        let end = GroundLayer.gridCoordinate(rowIndex: originY + height - 1, colIndex: originX + width - 1)
        let colRange = start.col...end.col
        let rowRange = start.row...end.row

        buildGround(colRange: colRange, rowRange: rowRange, on: grid)
        buildWalls(colRange: colRange, rowRange: rowRange, on: grid)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopNode")
    }

    private func buildGround(colRange: ClosedRange<Int>, rowRange: ClosedRange<Int>, on grid: IsoGrid) {
        for col in colRange {
            for row in rowRange {
                let tile = ShopGroundTileNode(fittingTo: grid)
                tile.position = grid.point(col: col, row: row)
                tile.zPosition = Self.zPosition(col: col, row: row, slot: .ground)
                addChild(tile)
            }
        }
    }

    /// Rings `colRange` × `rowRange` with wall segments along all four
    /// outer edges. Identical to `ShopWallsPreviewScene.buildWalls`,
    /// generalized from a single shared `span` (that preview's footprint
    /// was square) to an independent column range and row range:
    ///
    /// | Wall | Boundary | Anchors on |
    /// |---|---|---|
    /// | `ShopWallBackNode` | minimum column, every row | West vertex |
    /// | `ShopWallRightNode` | minimum row, every column | North vertex |
    /// | `ShopWallLeftNode` | maximum row, every column | West vertex |
    /// | `ShopWallFrontNode` | maximum column, every row | South vertex |
    private func buildWalls(colRange: ClosedRange<Int>, rowRange: ClosedRange<Int>, on grid: IsoGrid) {
        let firstCol = colRange.lowerBound
        let lastCol = colRange.upperBound
        let firstRow = rowRange.lowerBound
        let lastRow = rowRange.upperBound

        // North-west side: the North→West edge of every cell in the
        // minimum column, anchored on each cell's own West vertex.
        for row in rowRange {
            let wall = ShopWallBackNode(fittingTo: grid)
            wall.position = westVertex(col: firstCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: firstCol, row: row, slot: .back)
            addChild(wall)
        }

        // North-east side: the North→East edge of every cell in the
        // minimum row, anchored on each cell's own North vertex.
        for col in colRange {
            let wall = ShopWallRightNode(fittingTo: grid)
            wall.position = northVertex(col: col, row: firstRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: firstRow, slot: .right)
            addChild(wall)
        }

        // South-west side: the West→South edge of every cell in the
        // maximum row, anchored on each cell's own West vertex.
        for col in colRange {
            let wall = ShopWallLeftNode(fittingTo: grid)
            wall.position = westVertex(col: col, row: lastRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: lastRow, slot: .left)
            addChild(wall)
        }

        // South-east side: the South→East edge of every cell in the
        // maximum column, anchored on each cell's own South vertex.
        // KNOWN COSMETIC ISSUE (art, not geometry — do not "fix" here):
        // `wall_shop_front`'s source art has an entrance gap baked into
        // it, so every one of these segments shows one. Flagged to the
        // art team; each segment's own placement/z is otherwise correct.
        for row in rowRange {
            let wall = ShopWallFrontNode(fittingTo: grid)
            wall.position = southVertex(col: lastCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: lastCol, row: row, slot: .front)
            addChild(wall)
        }
    }

    // A cell's own diamond vertices, in the same terms
    // `ShopWallsPreviewScene` and the old `MainStallScene` hand-placement
    // used for a single tile.

    private func westVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x - grid.tileWidth / 2, y: center.y)
    }

    private func southVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x, y: center.y - grid.tileHeight / 2)
    }

    private func northVertex(col: Int, row: Int, on grid: IsoGrid) -> CGPoint {
        let center = grid.point(col: col, row: row)
        return CGPoint(x: center.x, y: center.y + grid.tileHeight / 2)
    }
}
