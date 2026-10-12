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

/// A wall segment `ShopNode.buildEnclosure` leaves out, addressed in the
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
/// wall segments, laid out on an
/// `IsoGrid`, plus a `ShopPrepTableNode` (with a bowl standing on it)
/// running into the room from the right wall and, when the east-side
/// opening is present, a cash counter (with a register standing on it)
/// filling that opening. Placed via
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
    /// default 3×3 size — so the windowed right-edge segment at
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

    /// One item's spec for `buildTableItem`: its art, native size, the
    /// pixel where its base touches the worktop (top-left origin, y down —
    /// every measurement table in this catalog reports pixels that way),
    /// and which of `ShopPrepTableNode`'s worktop slots it claims.
    private struct TableItemSpec {
        let imageName: String
        let nativeSize: CGSize
        let baseCenterPixel: CGPoint
        let slotIndex: Int

        /// `anchorPoint` wants a fraction from the *bottom*; `baseCenterPixel`
        /// is from the *top*. Deriving `1 − y / height` here, instead of
        /// pasting a pre-flipped literal, keeps the flip visible — the small
        /// bowl's own pre-flipped hand-off value (0.749, measured from the
        /// rim) would sink it into the table if pasted directly.
        var baseAnchor: CGPoint {
            CGPoint(
                x: baseCenterPixel.x / nativeSize.width,
                y: 1 - baseCenterPixel.y / nativeSize.height
            )
        }
    }

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 66×55, base-center pixel (32.57, 41.19). Stands in the
    /// worktop's low-row end (slot 0) — screen-right, next to the windowed
    /// wall (see `buildTableItem`) — where the bowl was aligned in the
    /// previous, ad-hoc placement.
    private static let smallBowl = TableItemSpec(
        imageName: "shop_empty_bowl",
        nativeSize: CGSize(width: 66, height: 55),
        baseCenterPixel: CGPoint(x: 32.57, y: 41.19),
        slotIndex: 0
    )

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 67×56, base-center pixel (33.5, 41.82). The filled frame
    /// for the same slot 0 position as `smallBowl` — one pixel larger on
    /// each axis, per the art director's table, so it gets its own
    /// `TableItemSpec` rather than reusing `smallBowl`'s numbers: mixing
    /// one spec's `nativeSize` with the other's `baseCenterPixel` would
    /// derive a `baseAnchor` fraction for a texture it wasn't measured
    /// against. SpriteKit positions each frame via anchor fraction
    /// against its own native size, so the two specs still land in the
    /// same visual spot (anchor fractions differ by ~0.43px in x, ~0.12px
    /// in y) without either needing a manual nudge.
    private static let filledSmallBowl = TableItemSpec(
        imageName: "shop_geotjeori_bowl",
        nativeSize: CGSize(width: 67, height: 56),
        baseCenterPixel: CGPoint(x: 33.5, y: 41.82),
        slotIndex: 0
    )

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 104×87, base-center pixel (52.0, 65.98). Stands in the
    /// worktop's middle slot (slot 1).
    private static let largeBowl = TableItemSpec(
        imageName: "shop_large_empty_bowl",
        nativeSize: CGSize(width: 104, height: 87),
        baseCenterPixel: CGPoint(x: 52.0, y: 65.98),
        slotIndex: 1
    )

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 104×87, base-center pixel (52.0, 65.98) — identical to
    /// `largeBowl`'s own measurements (zero drift, per the art director's
    /// table), so its `baseAnchor` fraction matches exactly with no manual
    /// nudge needed. Still its own `TableItemSpec`, matching `smallBowl`/
    /// `filledSmallBowl`'s split, rather than reusing `largeBowl` for a
    /// different texture.
    private static let filledLargeBowl = TableItemSpec(
        imageName: "shop_bomdong_kimchi_bowl",
        nativeSize: CGSize(width: 104, height: 87),
        baseCenterPixel: CGPoint(x: 52.0, y: 65.98),
        slotIndex: 1
    )

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 123×116, base-center pixel (61.5, 88.58). Stands in the
    /// worktop's high-row end (slot 2), opposite the small bowl.
    private static let daejeopBowl = TableItemSpec(
        imageName: "shop_daejeop_bowl",
        nativeSize: CGSize(width: 123, height: 116),
        baseCenterPixel: CGPoint(x: 61.5, y: 88.58),
        slotIndex: 2
    )

    /// Camera-matrix measurement table (3× render), used as printed:
    /// trimmed 123×116, base-center pixel (61.5, 88.58) — identical to
    /// `daejeopBowl`'s own measurements (zero drift, per the art
    /// director's table), so its `baseAnchor` fraction matches exactly
    /// with no manual nudge needed. Still its own `TableItemSpec`,
    /// matching `smallBowl`/`filledSmallBowl` and `largeBowl`/
    /// `filledLargeBowl`'s split, rather than reusing `daejeopBowl` for a
    /// different texture.
    private static let filledDaejeopBowl = TableItemSpec(
        imageName: "shop_bomdong_bibimbap_bowl",
        nativeSize: CGSize(width: 123, height: 116),
        baseCenterPixel: CGPoint(x: 61.5, y: 88.58),
        slotIndex: 2
    )

    let placement: ShopPlacement

    /// One prep-table slot's fillable bowl: two frames, built once in
    /// `init` and never swapped, plus the menu-tier gate and cook-fill
    /// state that together decide which one shows. Two nodes toggling
    /// `isHidden`, rather than texture-swapping one node, sidesteps having
    /// to mutate `size`/`anchorPoint` together at runtime from two
    /// measurement tables that aren't pixel-interchangeable — see
    /// `filledSmallBowl`'s doc comment.
    private final class FillableBowl {
        let emptyItem: ShopPropSpriteNode
        let filledItem: ShopPropSpriteNode

        /// Whether the menu-tier gate hides this slot (`applyMenuTier`
        /// sets this), composed with `isFilled` in `updateVisibility`.
        var isGateHidden = false

        /// The fill state `applyCookFill` pushes in. Starts `false` so
        /// the empty frame is the default, matching `updateVisibility`'s
        /// result before either `applyMenuTier` or `applyCookFill` has
        /// run.
        var isFilled = false

        init(emptyItem: ShopPropSpriteNode, filledItem: ShopPropSpriteNode) {
            self.emptyItem = emptyItem
            self.filledItem = filledItem
        }

        /// Composes the tier gate with the fill state so a gated slot
        /// stays hidden whichever frame is "current" — the alternative,
        /// each caller setting `isHidden` independently, would let a
        /// cook-fill call re-show a gated slot.
        func updateVisibility() {
            emptyItem.isHidden = isGateHidden || isFilled
            filledItem.isHidden = isGateHidden || !isFilled
        }

        /// Whichever frame is currently shown.
        var currentItem: ShopPropSpriteNode {
            isFilled ? filledItem : emptyItem
        }
    }

    /// The small (slot 0), large (slot 1) and daejeop (slot 2) bowls, each
    /// with its own empty/filled pair — every slot a cook can tap, gauge
    /// and fill past the gauge's threshold.
    private var fillableBowlsBySlot: [Int: FillableBowl] = [:]

    /// Cook gauges keyed by menu index — slot index and menu index are the
    /// same number by construction (see `applyMenuTier`'s doc comment), so
    /// one dictionary serves the small (0), large (1) and daejeop (2)
    /// bowls alike. Built at the end of `init`, once each bowl's own item
    /// exists to hang a gauge off of.
    private var cookGaugeNodesByMenuIndex: [Int: ShopCookGaugeNode] = [:]

    /// The three enclosures — pojangmacha stall (tier 0), bunsik shop (tier 1) and jeonmun shop (tier 2) — all built
    /// once in `init`, all but one hidden, and swapped via `isHidden` in
    /// `applyStallTier`. Same two-nodes-always-built approach
    /// `FillableBowl` uses for its empty/filled frames, so there's no
    /// runtime texture swap to keep in sync with different measurement
    /// tables.
    private var stallEnclosureNodes: [SKNode] = []
    private var bunsikEnclosureNodes: [SKNode] = []
    private var jeonmunEnclosureNodes: [SKNode] = []

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
    /// One case this scheme doesn't handle, left alone because nothing
    /// exercises it: a corner cell has two walls of its own (e.g. `left`
    /// and `front`); a prop there would draw over both, not just the one
    /// behind it. (The cash counter is in exactly such a corner cell,
    /// `(1, 0)` at the default size — see `buildCashCounter` for why
    /// that's the correct outcome there, not an instance of this gap.)
    ///
    /// Not representable here: a roof over the stall. It would have to sit
    /// above every floor tile yet below the prep table and cook gauges, and
    /// no single zPosition satisfies both. `stall_canopy` is therefore not
    /// built; tier 0 is a cutaway like tiers 1 and 2.
    enum Slot: CGFloat {
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
    static func zPosition(col: Int, row: Int, slot: Slot) -> CGFloat {
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
    /// `buildEnclosure`' `colRange`/`rowRange`, not map-array indices. `nil`
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
        buildStallEnclosure(colRange: colRange, rowRange: rowRange, on: grid, openings: openings)
        buildBunsikEnclosure(colRange: colRange, rowRange: rowRange, on: grid, openings: openings)
        buildJeonmunEnclosure(colRange: colRange, rowRange: rowRange, on: grid, openings: openings)
        // All three enclosures exist from here on; the bunsik shop stays
        // the visible default until a caller actually knows the stall
        // tier and calls `applyStallTier` — mirrors `FillableBowl`'s own
        // empty-by-default state before `applyCookFill` first runs.
        applyStallTier(1)

        let prepTableFootprint = prepTableFootprint
            ?? Self.defaultPrepTableFootprint(colRange: colRange, rowRange: rowRange)
        let table = buildPrepTable(footprint: prepTableFootprint, on: grid)
        // All six items (the small, large and daejeop bowls' two frames
        // each) draw at `.onProp` on the same `nearestCellSum`, so they tie
        // on zPosition — harmless because every slot is 0.583 apart, centre
        // to centre, which is wider than any neighbouring pair's combined
        // half-widths: small bowl 0.24 across vs. large bowl 0.38 (0.12 +
        // 0.19 = 0.31), large bowl vs. daejeop bowl 0.45 (0.19 + 0.225 =
        // 0.415) — so no two footprints ever reach each other, and each
        // fillable bowl's own two frames sit exactly on top of one another
        // by design (only one is ever visible at a time).
        let bowlSpecs = [
            (Self.smallBowl, Self.filledSmallBowl),
            (Self.largeBowl, Self.filledLargeBowl),
            (Self.daejeopBowl, Self.filledDaejeopBowl),
        ]
        for (emptySpec, filledSpec) in bowlSpecs {
            let emptyItem = buildTableItem(emptySpec, standingOn: table, footprintCellSum: prepTableFootprint.nearestCellSum, on: grid)
            let filledItem = buildTableItem(filledSpec, standingOn: table, footprintCellSum: prepTableFootprint.nearestCellSum, on: grid)
            let bowl = FillableBowl(emptyItem: emptyItem, filledItem: filledItem)
            bowl.updateVisibility()
            fillableBowlsBySlot[emptySpec.slotIndex] = bowl
            cookGaugeNodesByMenuIndex[emptySpec.slotIndex] = buildCookGauge(
                standingOn: emptyItem,
                spec: emptySpec,
                footprintCellSum: prepTableFootprint.nearestCellSum,
                on: grid
            )
        }

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

    /// Rings `colRange` × `rowRange` with `walls`' segments on all four
    /// edges, skipping any cell named in `openings`, and appends them to
    /// `enclosure`:
    ///
    /// | Edge | Boundary | Anchors on | Opening `side` | shop-local fixed axis |
    /// |---|---|---|---|---|
    /// | back | minimum column, every row | West vertex | `.back` | `x == 0` |
    /// | right | minimum row, every column | North vertex | `.right` | `y == 0` |
    /// | left | maximum row, every column | West vertex | `.left` | `y == height - 1` |
    /// | front | maximum column, every row | South vertex | `.front` | `x == width - 1` |
    private func buildEnclosure(
        into enclosure: inout [SKNode],
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>,
        on grid: IsoGrid,
        openings: Set<ShopWallOpening>,
        back: () -> SKNode,
        right: () -> SKNode,
        left: () -> SKNode,
        front: () -> SKNode
    ) {
        let firstCol = colRange.lowerBound
        let lastCol = colRange.upperBound
        let firstRow = rowRange.lowerBound
        let lastRow = rowRange.upperBound

        for row in rowRange {
            guard !openings.contains(ShopWallOpening(side: .back, x: 0, y: row - firstRow)) else { continue }
            let wall = back()
            wall.position = westVertex(col: firstCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: firstCol, row: row, slot: .back)
            addChild(wall)
            enclosure.append(wall)
        }

        for col in colRange {
            guard !openings.contains(ShopWallOpening(side: .right, x: col - firstCol, y: 0)) else { continue }
            let wall = right()
            wall.position = northVertex(col: col, row: firstRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: firstRow, slot: .right)
            addChild(wall)
            enclosure.append(wall)
        }

        for col in colRange {
            guard !openings.contains(ShopWallOpening(side: .left, x: col - firstCol, y: lastRow - firstRow)) else { continue }
            let wall = left()
            wall.position = westVertex(col: col, row: lastRow, on: grid)
            wall.zPosition = Self.zPosition(col: col, row: lastRow, slot: .left)
            addChild(wall)
            enclosure.append(wall)
        }

        for row in rowRange {
            guard !openings.contains(ShopWallOpening(side: .front, x: lastCol - firstCol, y: row - firstRow)) else { continue }
            let wall = front()
            wall.position = southVertex(col: lastCol, row: row, on: grid)
            wall.zPosition = Self.zPosition(col: lastCol, row: row, slot: .front)
            addChild(wall)
            enclosure.append(wall)
        }
    }

    /// Tier 1 (분식집): the same `wall_shop_left` the old walled shop
    /// used on the left edge, new `bunsik_*` art on the other three.
    private func buildBunsikEnclosure(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>,
        on grid: IsoGrid,
        openings: Set<ShopWallOpening>
    ) {
        buildEnclosure(
            into: &bunsikEnclosureNodes, colRange: colRange, rowRange: rowRange, on: grid, openings: openings,
            back: { ShopTierWallNode(ShopTierWallNode.bunsikBack, fittingTo: grid) },
            right: { ShopTierWallNode(ShopTierWallNode.bunsikRight, fittingTo: grid) },
            left: { ShopWallLeftNode(fittingTo: grid) },
            front: { ShopTierWallNode(ShopTierWallNode.bunsikFront, fittingTo: grid) }
        )
    }

    /// Tier 2 (전문점): all four edges are `jeonmun_*` art.
    private func buildJeonmunEnclosure(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>,
        on grid: IsoGrid,
        openings: Set<ShopWallOpening>
    ) {
        buildEnclosure(
            into: &jeonmunEnclosureNodes, colRange: colRange, rowRange: rowRange, on: grid, openings: openings,
            back: { ShopTierWallNode(ShopTierWallNode.jeonmunBack, fittingTo: grid) },
            right: { ShopTierWallNode(ShopTierWallNode.jeonmunRight, fittingTo: grid) },
            left: { ShopTierWallNode(ShopTierWallNode.jeonmunLeft, fittingTo: grid) },
            front: { ShopTierWallNode(ShopTierWallNode.jeonmunFront, fittingTo: grid) }
        )
    }

    /// Tier 0: the pojangmacha stall's own pieces. Shares `openings` with
    /// the other enclosures, so the entrance gap stays in the same cells
    /// at every tier — the counter filling that gap doesn't change.
    private func buildStallEnclosure(
        colRange: ClosedRange<Int>,
        rowRange: ClosedRange<Int>,
        on grid: IsoGrid,
        openings: Set<ShopWallOpening>
    ) {
        buildEnclosure(
            into: &stallEnclosureNodes, colRange: colRange, rowRange: rowRange, on: grid, openings: openings,
            back: { StallWallBackNode(fittingTo: grid) },
            right: { StallCurtainRightNode(fittingTo: grid) },
            left: { StallWallLeftNode(fittingTo: grid) },
            front: { StallCurtainFrontNode(fittingTo: grid) }
        )
    }

    /// A requested opening that isn't on the perimeter it names (wrong
    /// fixed axis, or out of range on the other one) is a caller
    /// mistake: it never matches a cell in `buildEnclosure`'s loops, so it's
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
    @discardableResult
    private func buildPrepTable(footprint: ShopPropFootprint, on grid: IsoGrid) -> ShopPrepTableNode {
        let table = ShopPrepTableNode(fittingTo: grid)
        table.position = grid.point(col: footprint.center.col, row: footprint.center.row)
        table.zPosition = Self.zPosition(cellSum: footprint.nearestCellSum, slot: .prop)
        addChild(table)
        return table
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

    /// Stands one item on `table`'s worktop, in `spec.slotIndex` of
    /// `ShopPrepTableNode`'s three worktop slots. `IsoGrid.point` maps
    /// increasing row toward the screen's lower-left, so the worktop's
    /// *low*-row end is the one that reads as screen-*right* — the end
    /// next to the windowed wall, and slot 0 under
    /// `ShopPrepTableNode.slotCenterRowOffset`.
    ///
    /// The vertical lift is the same trick `buildCashRegister` uses for
    /// the register: the table's top-center and base-center share x =
    /// 214.5, so lifting an item onto the worktop is a pure y offset, the
    /// table's measured top-center-minus-base-center converted to points
    /// by `ShopPropSpriteNode.isorenderScale`.
    ///
    /// The along-table slide is a grid-space displacement, not a pixel
    /// one: `IsoGrid.point(col:row:)` is linear with no additive origin
    /// term, so `grid.point(col: 0, row: Δrow)` *is* the screen-space
    /// vector for a row-only move of `Δrow`, without needing to subtract
    /// two points. Column stays `0` — this never crosses the worktop's
    /// width.
    ///
    /// Z-ordered at `.onProp` on the table's own footprint sum, so it
    /// always draws above the table; every slot sits closer to row 0 than
    /// `nearestCellSum`'s corner, never past it, so draw order can't
    /// change relative to the rest of the shop. Two items in different
    /// slots tie on this zPosition — fine as long as their footprints
    /// don't overlap (see the call site).
    @discardableResult
    private func buildTableItem(
        _ spec: TableItemSpec,
        standingOn table: ShopPrepTableNode,
        footprintCellSum: Int,
        on grid: IsoGrid
    ) -> ShopPropSpriteNode {
        let item = ShopPropSpriteNode(
            imageName: spec.imageName,
            nativeSize: spec.nativeSize,
            baseAnchor: spec.baseAnchor,
            fittingTo: grid
        )
        let topOffset = (ShopPrepTableNode.baseCenterY - ShopPrepTableNode.topCenterY)
            * ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        let alongTable = grid.point(col: 0, row: ShopPrepTableNode.slotCenterRowOffset(spec.slotIndex))
        item.position = CGPoint(
            x: table.position.x + alongTable.x,
            y: table.position.y + topOffset + alongTable.y
        )
        item.zPosition = Self.zPosition(cellSum: footprintCellSum, slot: .onProp)
        addChild(item)
        return item
    }

    /// Sits a cook gauge just above `bowlItem`'s rim: `bowlItem`'s
    /// `position` is where `spec.baseAnchor` sits, so the rim is
    /// `(1 - baseAnchor.y)` of the bowl's own screen height further up —
    /// derived from the bowl's measurements rather than a guessed point
    /// offset, per `spec`'s doc comment. One more bar-height of clearance
    /// on top keeps the bar off the sprite itself.
    ///
    /// Z-ordered one `slotSpacing` step above `.onProp` on the same
    /// `footprintCellSum` the bowl itself uses, so it always draws above
    /// the bowl without needing its own `Slot` case.
    private func buildCookGauge(
        standingOn bowlItem: ShopPropSpriteNode,
        spec: TableItemSpec,
        footprintCellSum: Int,
        on grid: IsoGrid
    ) -> ShopCookGaugeNode {
        let gauge = ShopCookGaugeNode(fittingTo: grid)
        let bowlHeight = spec.nativeSize.height * ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        let rimOffset = bowlHeight * (1 - spec.baseAnchor.y)
        gauge.position = CGPoint(
            x: bowlItem.position.x,
            y: bowlItem.position.y + rimOffset + gauge.height
        )
        gauge.zPosition = Self.zPosition(cellSum: footprintCellSum, slot: .onProp) + Self.slotSpacing / 2
        addChild(gauge)
        return gauge
    }

    /// Shows/hides table items by menu tier: slot index and menu index are
    /// the same number by construction (`smallBowl`/`largeBowl`/`daejeopBowl`
    /// claim slots 0/1/2 for exactly the menus — 겉절이/봄동김치/봄동비빔밥—
    /// that unlock them), so gating each item on `slotIndex <= tier` gates
    /// it on the menu it belongs to directly, with no separate threshold
    /// table to keep in sync. Each slot's gate is recorded on its
    /// `FillableBowl` and composed there with the fill state; see
    /// `FillableBowl.updateVisibility`.
    func applyMenuTier(_ tier: Int) {
        for (slotIndex, bowl) in fillableBowlsBySlot {
            bowl.isGateHidden = slotIndex > tier
            bowl.updateVisibility()
        }
    }

    /// Shows exactly one enclosure: the pojangmacha stall at tier 0
    /// (포장마차), the bunsik shop at tier 1 (봄동 식당) and the jeonmun
    /// shop at tier >= 2 (봄동 전문점) — see `UpgradeDefinitions.stall`.
    /// Interior props (prep table, bowls, gauges, cash counter/register)
    /// and customers don't gate on this; only the enclosure swaps.
    func applyStallTier(_ tier: Int) {
        let shown = max(0, min(tier, 2))
        for node in stallEnclosureNodes {
            node.isHidden = shown != 0
        }
        for node in bunsikEnclosureNodes {
            node.isHidden = shown != 1
        }
        for node in jeonmunEnclosureNodes {
            node.isHidden = shown != 2
        }
    }

    /// Toggles which of `menuIndex`'s two bowl frames is visible: filled
    /// while its cook is more than half done, empty otherwise. A
    /// `menuIndex` with no fillable bowl (out of range) is a no-op.
    ///
    /// This itself stays unconditional, matching `applyMenuTier`'s own
    /// pattern: `MainStallScene` derives `isFilled` from the cook-progress
    /// value it already reads for `updateCookGauge` and only calls this
    /// when the value actually changes.
    func applyCookFill(_ isFilled: Bool, menuIndex: Int) {
        guard let bowl = fillableBowlsBySlot[menuIndex] else { return }
        bowl.isFilled = isFilled
        bowl.updateVisibility()
    }

    /// Feeds `menuIndex`'s cook gauge; `MainStallScene` is the store-aware
    /// caller, so this only forwards the numbers it already computed. A
    /// `menuIndex` with no gauge (out of range) is a no-op.
    func updateCookGauge(menuIndex: Int, progress: Double, isVisible: Bool) {
        cookGaugeNodesByMenuIndex[menuIndex]?.update(progress: progress, isVisible: isVisible)
    }

    /// Smallest side length a tap target may have, independent of a
    /// sprite's own measured size — HIG's 44pt minimum. The small bowl's
    /// own frame (~22×18pt) is well under it, so `tappedBowlMenuIndex` pads
    /// the *hit test* out to this, leaving the sprite itself untouched.
    private static let minimumTouchTarget: CGFloat = 44

    /// The bowls a tap can currently land on, each paired with the menu
    /// index it cooks. Gated on the tier, not on which frame is hidden by
    /// fill state, so a bowl mid-cook stays tappable. Each fillable bowl
    /// always contributes its `emptyItem`'s frame, not whichever frame is
    /// currently visible: the empty/filled specs place them within a
    /// fraction of a pixel of each other (see `filledSmallBowl`'s doc
    /// comment), so one frame's frame is a fine stand-in for both.
    private func tappableBowlItems() -> [(menuIndex: Int, item: ShopPropSpriteNode)] {
        fillableBowlsBySlot
            .filter { !$0.value.isGateHidden }
            .map { (menuIndex: $0.key, item: $0.value.emptyItem) }
    }

    /// The menu index of the bowl `scenePoint` (a touch location in the
    /// owning scene's coordinate space, as `SKScene.touchesEnded` reports
    /// it) hits, or `nil` if it hits none. `MainStallScene` hit-tests
    /// through here rather than reaching into the bowls' nodes itself,
    /// keeping this node the only thing that knows their frames. If two
    /// bowls' padded rects both contain the point (only possible right at
    /// their shared boundary), the nearer one by centre distance wins, so
    /// the tap always resolves to exactly one bowl.
    func tappedBowlMenuIndex(at scenePoint: CGPoint) -> Int? {
        guard let scene else { return nil }
        let localPoint = convert(scenePoint, from: scene)
        var best: (menuIndex: Int, distance: CGFloat)?
        for (menuIndex, item) in tappableBowlItems() {
            let frame = item.frame
            let width = max(frame.width, Self.minimumTouchTarget)
            let height = max(frame.height, Self.minimumTouchTarget)
            let hitArea = CGRect(x: frame.midX - width / 2, y: frame.midY - height / 2, width: width, height: height)
            guard hitArea.contains(localPoint) else { continue }
            let dx = localPoint.x - frame.midX
            let dy = localPoint.y - frame.midY
            let distance = dx * dx + dy * dy
            if best == nil || distance < best!.distance {
                best = (menuIndex, distance)
            }
        }
        return best?.menuIndex
    }

    /// Accept-tap feedback on `menuIndex`'s bowl: scales up and back over
    /// ~0.12s. Only ever called from an accepted tap, never per-frame, so
    /// building a fresh `SKAction` here each time is fine. Animates
    /// whichever frame is currently shown — animating the hidden one would
    /// silently do nothing on screen.
    func pulseBowl(menuIndex: Int) {
        fillableBowlsBySlot[menuIndex]?.currentItem.run(.sequence([
            .scale(to: 1.08, duration: 0.06),
            .scale(to: 1.0, duration: 0.06),
        ]))
    }

    // MARK: - Customer service point

    /// Spacing (in `IsoGrid` column units) between queued customers
    /// standing outside the counter, stepping further east per slot —
    /// far enough that neighbouring queue slots' sprites (~40pt wide)
    /// don't overlap at this grid's usual scale, without crossing a
    /// whole tile and looking like a separate line.
    private static let customerQueueColSpacing: CGFloat = 0.65

    /// The `IsoGrid` row every customer queue slot (and, in
    /// `ShopCustomerSpawner`, the spawn point far to the east on the same
    /// row) shares: centred on the two rows `defaultOpenings` removes the
    /// front wall from. A `static var`, not folded into
    /// `customerServicePoint` alone, so the spawner can put its own point
    /// on this row without faking an oversized queue slot to reach it.
    static var customerServiceRow: CGFloat {
        let start = GroundLayer.gridCoordinate(rowIndex: defaultPlacement.originY, colIndex: defaultPlacement.originX)
        return CGFloat(start.row) + 0.5
    }

    /// Where a customer stands to be served, `queueSlot` steps east of
    /// the counter itself (`0` is the customer actually being served).
    /// One cell east of `defaultPlacement`'s own east corner (the same
    /// column the front wall's opening — and the counter filling it —
    /// sit against) on `customerServiceRow`, then stepped further east
    /// per slot so a queue forms outside the shop rather than stacking on
    /// one point. Every slot's column is `> colRange.upperBound`, so the
    /// whole queue — like the counter it lines up in front of — stays
    /// clear of the shop rectangle regardless of `queueSlot`. Derived
    /// from `defaultPlacement` rather than a hardcoded point so it can't
    /// drift from where the counter itself is actually drawn.
    static func customerServicePoint(on grid: IsoGrid, queueSlot: Int = 0) -> CGPoint {
        let end = GroundLayer.gridCoordinate(
            rowIndex: defaultPlacement.originY + defaultPlacement.height - 1,
            colIndex: defaultPlacement.originX + defaultPlacement.width - 1
        )
        let col = CGFloat(end.col + 1) + CGFloat(queueSlot) * customerQueueColSpacing
        return grid.point(col: col, row: customerServiceRow)
    }

    /// Z-order for an actor (a customer) standing at world-space `y` on
    /// `grid`, on the same `col + row` scale every ground tile, wall and
    /// prop in this file compares against — recovered from `y` alone via
    /// `IsoGrid`'s own inverse (`col + row == -2y / tileHeight`) rather
    /// than tracking the actor's grid coordinate separately as it walks.
    /// One step above the shop's own highest in-cell slot (`.onProp`) so
    /// an actor in front of the shop always draws over its walls, counter
    /// and register at the same or a lower cellSum.
    static func actorZPosition(atWorldY y: CGFloat, on grid: IsoGrid) -> CGFloat {
        let cellSum = Int((-2 * y / grid.tileHeight).rounded(.down))
        return zPosition(cellSum: cellSum, slot: .onProp) + slotSpacing
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
