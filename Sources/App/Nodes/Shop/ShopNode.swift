import SpriteKit

/// The shop's footprint: origin plus size in map-array-index coordinates
/// (`GroundLayer.map`'s own row/col indices — `x` is a column, `y` is a
/// row). `GroundLayer.kind(atCol:row:)` asks `ShopNode.defaultPlacement`
/// rather than keeping a second copy of this rectangle in its map
/// literal, so there's exactly one place the shop's rectangle is
/// expressed as numbers.
struct ShopPlacement {
    let originX: Int
    let originY: Int
    let width: Int
    let height: Int

    func contains(mapX: Int, mapY: Int) -> Bool {
        (originX..<(originX + width)).contains(mapX)
            && (originY..<(originY + height)).contains(mapY)
    }

    /// World-space centroid of this placement's cells on `grid`. Used to
    /// frame the launch camera on the shop — `GroundLayer.mapCentroid`
    /// averages the whole map, which drifted away from the shop once the
    /// map grew rows of field/grass around it.
    func centroid(on grid: IsoGrid) -> CGPoint {
        var sum = CGPoint.zero
        var count = 0
        for mapX in originX..<(originX + width) {
            for mapY in originY..<(originY + height) {
                let (col, row) = GroundLayer.gridCoordinate(rowIndex: mapY, colIndex: mapX)
                let point = grid.point(col: col, row: row)
                sum.x += point.x
                sum.y += point.y
                count += 1
            }
        }
        guard count > 0 else { return .zero }
        return CGPoint(x: sum.x / CGFloat(count), y: sum.y / CGFloat(count))
    }
}

/// A shop building: `ShopGroundTileNode` tiles ringed by the four
/// `ShopWall{Back,Right,Left,Front}Node` segments, laid out on an
/// `IsoGrid`. Placed via `originX`/`originY` (map-array-index
/// coordinates) and sized via `width`/`height`, defaulting to
/// `defaultWidth`×`defaultHeight` (3×4). Ground and walls come from one
/// `ShopPlacement`, so `GroundLayer.kind(atCol:row:)` can ask it which
/// cells are shop cells instead of keeping a second copy of the
/// rectangle.
final class ShopNode: SKNode {

    /// Default footprint: 3 wide (east-west) × 4 tall (north-south).
    static let defaultWidth = 3
    static let defaultHeight = 4

    /// The real shop's placement in the live game: map-array column 1,
    /// row 7, at the default 3×4 size. `MainStallScene` builds its
    /// `ShopNode` from this; `GroundLayer.kind(atCol:row:)` reads it too,
    /// so the two can't disagree about which cells are shop cells.
    static let defaultPlacement = ShopPlacement(
        originX: 1,
        originY: 7,
        width: defaultWidth,
        height: defaultHeight
    )

    let placement: ShopPlacement

    /// Painter's-order slot within a cell: ground, then walls back <
    /// right < left < front, so the wall nearer the camera wins where
    /// two meet at a shared corner.
    private enum Slot: CGFloat {
        case ground = 0
        case back = 1
        case right = 2
        case left = 3
        case front = 4
    }

    /// Fraction of one `col + row` step to space a cell's five slots
    /// apart by — kept under 1/4 (the highest slot) so a slot offset can
    /// never cross into the next `col + row` step and disturb
    /// cell-to-cell order.
    ///
    /// `zPosition` has to stay on this same unscaled `col + row` scale
    /// `GroundLayer`/`FieldLayer` use, since SpriteKit compares
    /// zPosition globally across the whole node tree. An earlier version
    /// multiplied `col + row` by 10 instead: fine while `col + row >= 0`,
    /// but scaling a negative `col + row` makes it *more* negative, so
    /// cells north/west of the grid origin (e.g. the shop's own north
    /// corner, col: -1, row: 0) sorted their walls behind neighboring
    /// ground tiles they should have drawn in front of.
    private static let slotSpacing: CGFloat = 0.1

    /// `col + row` orders cells; `slot * slotSpacing` orders a cell's
    /// own ground/walls without disturbing that (see `slotSpacing`).
    private static func zPosition(col: Int, row: Int, slot: Slot) -> CGFloat {
        CGFloat(col + row) + slot.rawValue * slotSpacing
    }

    /// Builds a shop at `(originX, originY)`, `width`×`height` cells,
    /// laid out on `grid` immediately — no separate `layout()` call,
    /// since a shop's footprint never changes after placement.
    init(
        originX: Int,
        originY: Int,
        width: Int = ShopNode.defaultWidth,
        height: Int = ShopNode.defaultHeight,
        fittingTo grid: IsoGrid
    ) {
        placement = ShopPlacement(originX: originX, originY: originY, width: width, height: height)
        super.init()

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

    /// Rings `colRange` × `rowRange` with wall segments on all four
    /// edges:
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

        for row in rowRange {
            let wall = ShopWallBackNode(fittingTo: grid)
            wall.position = westVertex(col: firstCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: firstCol, row: row, slot: .back)
            addChild(wall)
        }

        for col in colRange {
            let wall = ShopWallRightNode(fittingTo: grid)
            wall.position = northVertex(col: col, row: firstRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: firstRow, slot: .right)
            addChild(wall)
        }

        for col in colRange {
            let wall = ShopWallLeftNode(fittingTo: grid)
            wall.position = westVertex(col: col, row: lastRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: lastRow, slot: .left)
            addChild(wall)
        }

        // KNOWN COSMETIC ISSUE (art, not geometry — do not "fix" here):
        // `wall_shop_front`'s source art has an entrance gap baked into
        // it, so every one of these segments shows one. Flagged to the
        // art team.
        for row in rowRange {
            let wall = ShopWallFrontNode(fittingTo: grid)
            wall.position = southVertex(col: lastCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: lastCol, row: row, slot: .front)
            addChild(wall)
        }
    }

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
