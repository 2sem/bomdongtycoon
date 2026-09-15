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

/// A prop's footprint on the shop's `IsoGrid`: the whole cells its base
/// stands on (`origin`, `colSpan` columns × `rowSpan` rows, each >= 1)
/// and the exact fractional grid point its sprite is centered on. `center`
/// is kept separate from the rectangle because a prop's visual center
/// doesn't have to be its footprint's geometric center — see
/// `ShopPrepTableNode.footprintCenterOffset`.
struct ShopPropFootprint {
    let origin: (col: Int, row: Int)
    let colSpan: Int
    let rowSpan: Int
    let center: (col: CGFloat, row: CGFloat)

    /// `col + row` of the nearest cell the footprint covers. For an
    /// axis-aligned rectangle that's always the corner with both the
    /// highest col and highest row — no need to walk every cell. See
    /// `ShopNode.Slot.prop` for why the *nearest* covered cell, not
    /// `center`'s cell, has to set draw order.
    var nearestCellSum: Int {
        (origin.col + colSpan - 1) + (origin.row + rowSpan - 1)
    }
}

/// A wall segment `ShopNode.buildWalls` leaves out, addressed in the
/// shop's own local offsets from its own origin — `x` toward the east
/// corner (screen lower-right), `y` toward the south corner (screen
/// lower-left) — the same offsets the user names a cell by ("[2, 0]"),
/// and offsets that stay correct wherever the shop is placed. Chosen over
/// `IsoGrid` coordinates (what `ShopPropFootprint`/`prepTableFootprint`
/// use) because an opening is a property of the shop, not of the grid
/// cell underneath it — it has to move with the shop, not stay pinned to
/// wherever the shop happened to be the day the opening was added.
struct ShopWallOpening: Hashable {
    enum Side {
        case back, right, left, front
    }

    let side: Side
    let x: Int
    let y: Int
}

/// A shop building: `ShopGroundTileNode` tiles ringed by the four
/// `ShopWall{Back,Right,Left,Front}Node` segments, laid out on an
/// `IsoGrid`, plus a `ShopPrepTableNode` running into the room from the
/// right wall and, when the east-side opening is present, a cash counter
/// (with a register standing on it) filling that opening. Placed via
/// `originX`/`originY` (map-array-index coordinates) and sized via
/// `width`/`height`, defaulting to `defaultWidth`×`defaultHeight` (3×3).
/// Ground and walls come from one `ShopPlacement`, so
/// `GroundLayer.kind(atCol:row:)` can ask it which cells are shop cells
/// instead of keeping a second copy of the rectangle.
final class ShopNode: SKNode {

    /// Default footprint: 3 wide (east-west) × 3 tall (north-south).
    static let defaultWidth = 3
    static let defaultHeight = 3

    /// The real shop's placement in the live game: map-array column 1,
    /// row 7, at the default 3×3 size. `MainStallScene` builds its
    /// `ShopNode` from this; `GroundLayer.kind(atCol:row:)` reads it too,
    /// so the two can't disagree about which cells are shop cells.
    static let defaultPlacement = ShopPlacement(
        originX: 1,
        originY: 7,
        width: defaultWidth,
        height: defaultHeight
    )

    /// The live shop's east side leaves out its two front segments
    /// nearest the east corner — shop-local `(2, 0)` and `(2, 1)` at the
    /// default 3×3 size — so the windowed `ShopWallRightNode` segment at
    /// the east corner stands alone with its corner post showing rather
    /// than butting into a plain front segment. `(2, 2)`, by the south
    /// corner, keeps its front wall.
    static let defaultOpenings: Set<ShopWallOpening> = [
        ShopWallOpening(side: .front, x: defaultWidth - 1, y: 0),
        ShopWallOpening(side: .front, x: defaultWidth - 1, y: 1),
    ]

    /// The wall openings the cash counter needs before it's drawn at all
    /// — the same two cells `defaultOpenings` removes by default. Gating
    /// on the openings actually passed in (not just on being the default
    /// shop) means `ShopWallsPreviewScene`, which asks for `openings: []`
    /// to show the whole unbroken ring, doesn't get a counter standing in
    /// front of a wall that's still there.
    private static func requiredCashCounterOpenings(width: Int) -> Set<ShopWallOpening> {
        [
            ShopWallOpening(side: .front, x: width - 1, y: 0),
            ShopWallOpening(side: .front, x: width - 1, y: 1),
        ]
    }

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 409×338, base-center anchor at (0.50000, 0.37399 from the
    /// bottom).
    private static let cashCounterImageName = "shop_cash_counter"
    private static let cashCounterNativeSize = CGSize(width: 409, height: 338)
    private static let cashCounterBaseAnchor = CGPoint(x: 0.5, y: 0.37399)

    /// Top-center minus base-center, in the counter's own native (3×
    /// render) pixel space (211.59 − 127.41) — how far above its own
    /// `baseAnchor` point the counter's worktop sits. Used to derive the
    /// register's stand-on-counter offset instead of hardcoding a point
    /// value; see `buildCashRegister`.
    private static let cashCounterBaseCenterY: CGFloat = 211.59
    private static let cashCounterTopCenterY: CGFloat = 127.41

    /// Whole grid cells the counter's footprint covers (1 column × 2
    /// rows) and the spec center's offset from that footprint's origin
    /// cell — (1.20, 0.475) at the default size, `origin + (0.20,
    /// 0.475)`. See `defaultCashCounterFootprint`.
    private static let cashCounterCellSpan = (col: 1, row: 2)
    private static let cashCounterFootprintCenterOffset: (col: CGFloat, row: CGFloat) = (0.20, 0.475)

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 95×88, base-center anchor at (0.50000, 0.33648 from the
    /// bottom).
    private static let cashRegisterImageName = "shop_cash_register"
    private static let cashRegisterNativeSize = CGSize(width: 95, height: 88)
    private static let cashRegisterBaseAnchor = CGPoint(x: 0.5, y: 0.33648)

    let placement: ShopPlacement

    /// Painter's-order slot within a cell: ground, then walls back <
    /// right < left < front, so the wall nearer the camera wins where
    /// two meet at a shared corner; `prop` sits above all four so
    /// furniture always draws in front of whatever wall shares its cell.
    /// `onProp` sits above `prop` for a prop that stands on another prop
    /// (the cash register on the cash counter) rather than on the floor.
    /// A multi-cell prop (`ShopPropFootprint`) uses its *nearest* covered
    /// cell for this, not its anchor/center cell — right for a solid
    /// object standing on the floor, since it must draw over that near
    /// cell's own ground tile too.
    ///
    /// Two cases this scheme doesn't handle, left alone because nothing
    /// exercises them yet:
    /// - a corner cell has two walls of its own (e.g. `left` and
    ///   `front`); a prop there would draw over both, not just the one
    ///   behind it. (The cash counter is in exactly such a corner cell,
    ///   `(1, 0)` at the default size — see `buildCashCounter` for why
    ///   that's the correct outcome there, not an instance of this gap.)
    /// - a prop meant to be partially *occluded* by nearer scenery would
    ///   need the opposite rule — its farthest cell, not its nearest.
    private enum Slot: CGFloat {
        case ground = 0
        case back = 1
        case right = 2
        case left = 3
        case front = 4
        case prop = 5
        case onProp = 6
    }

    /// Fraction of one `col + row` step to space a cell's slots apart by
    /// — kept small enough that even `onProp`, the highest slot at 6,
    /// stays under 1 (`6 * slotSpacing = 0.6`), so a slot offset can never
    /// cross into the next `col + row` step and disturb cell-to-cell order.
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
        zPosition(cellSum: col + row, slot: slot)
    }

    /// Same rule, taking the `col + row` sum directly — for a multi-cell
    /// footprint, that's `ShopPropFootprint.nearestCellSum`, not any
    /// single cell's own `col + row`.
    private static func zPosition(cellSum: Int, slot: Slot) -> CGFloat {
        CGFloat(cellSum) + slot.rawValue * slotSpacing
    }

    /// Builds a shop at `(originX, originY)`, `width`×`height` cells,
    /// laid out on `grid` immediately — no separate `layout()` call,
    /// since a shop's footprint never changes after placement.
    ///
    /// `prepTableFootprint` is in the same `IsoGrid` `(col, row)` space as
    /// `buildWalls`' `colRange`/`rowRange`, not map-array indices. `nil`
    /// (the default) falls back to `defaultPrepTableFootprint`.
    ///
    /// `openings` defaults to `defaultOpenings`, so any caller building a
    /// shop at the default 3×3 size without naming its own openings gets
    /// the live shop's east-side gap for free (`MainStallScene` and the
    /// ground-layer preview both do this). A caller that wants the full,
    /// unbroken wall ring — `ShopWallsPreviewScene` — passes `[]`
    /// explicitly.
    ///
    /// `cashCounterFootprint` follows the same nil-falls-back-to-default
    /// pattern as `prepTableFootprint`, but the counter it places is only
    /// actually built when `openings` removes the two front-wall segments
    /// it stands in front of (see `requiredCashCounterOpenings`) — so
    /// `ShopWallsPreviewScene`'s `openings: []` correctly gets no counter.
    init(
        originX: Int,
        originY: Int,
        width: Int = ShopNode.defaultWidth,
        height: Int = ShopNode.defaultHeight,
        prepTableFootprint: ShopPropFootprint? = nil,
        cashCounterFootprint: ShopPropFootprint? = nil,
        openings: Set<ShopWallOpening> = ShopNode.defaultOpenings,
        fittingTo grid: IsoGrid
    ) {
        placement = ShopPlacement(originX: originX, originY: originY, width: width, height: height)
        super.init()
        Self.validate(openings, width: width, height: height)

        let start = GroundLayer.gridCoordinate(rowIndex: originY, colIndex: originX)
        let end = GroundLayer.gridCoordinate(rowIndex: originY + height - 1, colIndex: originX + width - 1)
        let colRange = start.col...end.col
        let rowRange = start.row...end.row

        buildGround(colRange: colRange, rowRange: rowRange, on: grid)
        buildWalls(colRange: colRange, rowRange: rowRange, on: grid, openings: openings)

        let prepTableFootprint = prepTableFootprint
            ?? Self.defaultPrepTableFootprint(colRange: colRange, rowRange: rowRange)
        buildPrepTable(footprint: prepTableFootprint, on: grid)

        if openings.isSuperset(of: Self.requiredCashCounterOpenings(width: width)) {
            let cashCounterFootprint = cashCounterFootprint
                ?? Self.defaultCashCounterFootprint(colRange: colRange, rowRange: rowRange)
            let counter = buildCashCounter(footprint: cashCounterFootprint, on: grid)
            buildCashRegister(standingOn: counter, footprintCellSum: cashCounterFootprint.nearestCellSum, on: grid)
        }
    }

    /// The table's spec placement absent an explicit override: its
    /// origin (wall-adjacent) cell is the middle column of the
    /// right-wall run, at that run's row — `(0, 0)` at `defaultPlacement`'s
    /// size, matching the spec.
    private static func defaultPrepTableFootprint(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>
    ) -> ShopPropFootprint {
        let origin = (col: (colRange.lowerBound + colRange.upperBound) / 2, row: rowRange.lowerBound)
        return ShopPropFootprint(
            origin: origin,
            colSpan: ShopPrepTableNode.cellSpan.col,
            rowSpan: ShopPrepTableNode.cellSpan.row,
            center: (
                col: CGFloat(origin.col) + ShopPrepTableNode.footprintCenterOffset.col,
                row: CGFloat(origin.row) + ShopPrepTableNode.footprintCenterOffset.row
            )
        )
    }

    /// The counter's spec placement absent an explicit override: its
    /// footprint's origin (wall-adjacent) cell is `colRange`'s upper
    /// bound — the shop's east corner — at `rowRange`'s lower bound,
    /// `(1, 0)`-`(1, 1)` at `defaultPlacement`'s size, the same two
    /// cells `defaultOpenings` removes the front wall from.
    private static func defaultCashCounterFootprint(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>
    ) -> ShopPropFootprint {
        let origin = (col: colRange.upperBound, row: rowRange.lowerBound)
        return ShopPropFootprint(
            origin: origin,
            colSpan: cashCounterCellSpan.col,
            rowSpan: cashCounterCellSpan.row,
            center: (
                col: CGFloat(origin.col) + cashCounterFootprintCenterOffset.col,
                row: CGFloat(origin.row) + cashCounterFootprintCenterOffset.row
            )
        )
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
    /// edges, skipping any cell named in `openings`:
    ///
    /// | Wall | Boundary | Anchors on | Opening `side` | shop-local fixed axis |
    /// |---|---|---|---|---|
    /// | `ShopWallBackNode` | minimum column, every row | West vertex | `.back` | `x == 0` |
    /// | `ShopWallRightNode` | minimum row, every column | North vertex | `.right` | `y == 0` |
    /// | `ShopWallLeftNode` | maximum row, every column | West vertex | `.left` | `y == height - 1` |
    /// | `ShopWallFrontNode` | maximum column, every row | South vertex | `.front` | `x == width - 1` |
    private func buildWalls(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>,
        on grid: IsoGrid,
        openings: Set<ShopWallOpening>
    ) {
        let firstCol = colRange.lowerBound
        let lastCol = colRange.upperBound
        let firstRow = rowRange.lowerBound
        let lastRow = rowRange.upperBound

        for row in rowRange {
            guard !openings.contains(ShopWallOpening(side: .back, x: 0, y: row - firstRow)) else { continue }
            let wall = ShopWallBackNode(fittingTo: grid)
            wall.position = westVertex(col: firstCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: firstCol, row: row, slot: .back)
            addChild(wall)
        }

        for col in colRange {
            guard !openings.contains(ShopWallOpening(side: .right, x: col - firstCol, y: 0)) else { continue }
            let wall = ShopWallRightNode(fittingTo: grid)
            wall.position = northVertex(col: col, row: firstRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: firstRow, slot: .right)
            addChild(wall)
        }

        for col in colRange {
            guard !openings.contains(ShopWallOpening(side: .left, x: col - firstCol, y: lastRow - firstRow)) else { continue }
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
            guard !openings.contains(ShopWallOpening(side: .front, x: lastCol - firstCol, y: row - firstRow)) else { continue }
            let wall = ShopWallFrontNode(fittingTo: grid)
            wall.position = southVertex(col: lastCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: lastCol, row: row, slot: .front)
            addChild(wall)
        }
    }

    /// A requested opening that isn't on the perimeter it names (wrong
    /// fixed axis, or out of range on the other one) is a caller
    /// mistake: it never matches a cell in `buildWalls`' loops, so it's
    /// silently a no-op — every wall stays. `assert` catches that mistake
    /// during development without taking down a release build.
    private static func validate(_ openings: Set<ShopWallOpening>, width: Int, height: Int) {
        for opening in openings {
            switch opening.side {
            case .back:
                assert(opening.x == 0 && (0..<height).contains(opening.y), "\(opening) is not on the shop's back wall")
            case .front:
                assert(opening.x == width - 1 && (0..<height).contains(opening.y), "\(opening) is not on the shop's front wall")
            case .right:
                assert(opening.y == 0 && (0..<width).contains(opening.x), "\(opening) is not on the shop's right wall")
            case .left:
                assert(opening.y == height - 1 && (0..<width).contains(opening.x), "\(opening) is not on the shop's left wall")
            }
        }
    }

    /// Places a `ShopPrepTableNode` at `footprint.center` — not a whole
    /// grid cell, hence the fractional `IsoGrid.point(col:row:)` overload
    /// rather than the whole-cell one used everywhere else in this file —
    /// and z-orders it by `footprint.nearestCellSum` (see `Slot.prop`).
    private func buildPrepTable(footprint: ShopPropFootprint, on grid: IsoGrid) {
        let table = ShopPrepTableNode(fittingTo: grid)
        table.position = grid.point(col: footprint.center.col, row: footprint.center.row)
        table.zPosition = Self.zPosition(cellSum: footprint.nearestCellSum, slot: .prop)
        addChild(table)
    }

    /// Places the cash counter at `footprint.center` (`(1.20, 0.475)` at
    /// the default size) and z-orders it by `footprint.nearestCellSum`
    /// (see `Slot.prop`).
    ///
    /// Its origin cell, `(1, 0)` at the default size, is the shop's east
    /// corner — a cell with two walls of its own, the general gap
    /// `Slot`'s doc comment flags. It's benign here: that corner's
    /// *front* segment is the opening this counter fills (removed by
    /// `defaultOpenings`), and its *right* (windowed) segment runs along
    /// the row −0.5 edge, behind where the counter's own footprint starts
    /// (row −0.40, from its center at 0.475 minus half the spec `DEPTH`
    /// 1.75) — so the counter drawing over both is correct, not just
    /// harmless. Do not "fix" this by giving the counter its own slot
    /// exception.
    private func buildCashCounter(footprint: ShopPropFootprint, on grid: IsoGrid) -> ShopPropSpriteNode {
        let counter = ShopPropSpriteNode(
            imageName: Self.cashCounterImageName,
            nativeSize: Self.cashCounterNativeSize,
            baseAnchor: Self.cashCounterBaseAnchor,
            fittingTo: grid
        )
        counter.position = grid.point(col: footprint.center.col, row: footprint.center.row)
        counter.zPosition = Self.zPosition(cellSum: footprint.nearestCellSum, slot: .prop)
        addChild(counter)
        return counter
    }

    /// Stands the register on `counter`'s own top-center: same x, and y
    /// raised by the counter's measured top-center-minus-base-center
    /// offset, converted from the counter's native (3× render) pixels to
    /// points by `ShopPropSpriteNode.isorenderScale` — the same ratio the
    /// counter's own sprite is scaled by — rather than a separately
    /// measured or hardcoded point offset. Z-ordered at `.onProp` on the
    /// counter's own footprint sum, so it always draws above the counter
    /// it stands on.
    private func buildCashRegister(standingOn counter: ShopPropSpriteNode, footprintCellSum: Int, on grid: IsoGrid) {
        let register = ShopPropSpriteNode(
            imageName: Self.cashRegisterImageName,
            nativeSize: Self.cashRegisterNativeSize,
            baseAnchor: Self.cashRegisterBaseAnchor,
            fittingTo: grid
        )
        let topOffset = (Self.cashCounterBaseCenterY - Self.cashCounterTopCenterY)
            * ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        register.position = CGPoint(x: counter.position.x, y: counter.position.y + topOffset)
        register.zPosition = Self.zPosition(cellSum: footprintCellSum, slot: .onProp)
        addChild(register)
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
