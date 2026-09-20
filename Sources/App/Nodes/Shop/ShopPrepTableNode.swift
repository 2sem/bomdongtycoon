import SpriteKit

/// The shop's empty cook/prep counter — long axis along the row axis,
/// perpendicular to the wall it stands against. A `ShopNode` prop, not
/// the Kitchen scene's own furniture — it happens to share the
/// `kitchen_prep_table` asset name, not a class. Like the wall/ground
/// tile nodes, it has no say in the grid: it fits its footprint to
/// whatever `IsoGrid` it's handed at init.
final class ShopPrepTableNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "kitchen_prep_table")

    /// Camera-matrix measurement table, used as printed (not re-measured):
    /// trimmed 429×321, base-center anchor at (0.50000, 0.38919 from the
    /// bottom).
    private static let nativeSize = CGSize(width: 429, height: 321)
    private static let baseAnchor = CGPoint(x: 0.5, y: 0.38919)

    /// Same table, base-center and top-center y only, top-left origin
    /// (196.07, 132.93) — not `private`, so `ShopNode.buildTableItem` can
    /// turn their difference into an item's stand-on-table offset, the same
    /// way the cash counter's own base/top-center y feed the register.
    static let baseCenterY: CGFloat = 196.07
    static let topCenterY: CGFloat = 132.93

    /// `grid.tileWidth` at the moment this asset was rendered — the
    /// isorender pipeline always renders at exactly 3× whatever the live
    /// grid's tile width is. Dividing `nativeSize` by `3 ×
    /// measuredGridTileWidth` turns it into a fraction of `grid.tileWidth`
    /// rather than a baked pixel size, so the counter scales with the grid
    /// if it's ever retuned instead of drifting out of proportion.
    private static let measuredGridTileWidth: CGFloat = 126
    private static let widthFraction = nativeSize.width / (measuredGridTileWidth * 3)

    /// Whole grid cells this footprint covers: 1 column × 2 rows — the
    /// counter runs two cells deep into the room, one cell wide.
    static let cellSpan = (col: 1, row: 2)

    /// Offset, in fractional grid units, from the footprint's origin cell
    /// (the one against the wall) to the sprite's own center. Spec value
    /// (row 0.475), not the footprint rectangle's geometric center (which
    /// would be row 0.5) — nudges the visual mass slightly toward the
    /// wall, matching the visible air gap at that end.
    static let footprintCenterOffset: (col: CGFloat, row: CGFloat) = (0.0, 0.475)

    /// The worktop's own length, in grid rows (`tools/isorender/assets/kitchen_prep_table.py`'s
    /// `DEPTH`, 1.75) — the surface things stand on, not the 2-row footprint `cellSpan`
    /// occupies. A slot divides the worktop's length, so this is what it divides.
    static let worktopDepth: CGFloat = 1.75

    /// Equal-length slots along the worktop, for anything that stands on this table (the
    /// small bowl, the large bowl, and the pot) to claim a position without redoing the
    /// worktop math itself.
    static let slotCount = 3

    /// Row offset of slot `index`'s centre from this table's own footprint-centre row
    /// (`footprintCenterOffset.row`). Slot 0 is the worktop's low-row end — the end that
    /// reads as screen-right, next to the windowed wall (see `ShopNode.buildTableItem`'s
    /// placement comment for why low row is screen-right).
    ///
    /// An `index` outside `0..<slotCount` is a caller mistake — same class of error as an
    /// off-perimeter `ShopWallOpening` — so this asserts in debug (per `ShopNode.validate`'s
    /// precedent) and clamps to the nearest valid slot rather than crashing a release build.
    static func slotCenterRowOffset(_ index: Int) -> CGFloat {
        assert((0..<slotCount).contains(index), "slot \(index) is out of range 0..<\(slotCount)")
        let clamped = min(max(index, 0), slotCount - 1)
        return -(worktopDepth / 2) + (CGFloat(clamped) + 0.5) * (worktopDepth / CGFloat(slotCount))
    }

    private static func spriteSize(fittingTo grid: IsoGrid) -> CGSize {
        let width = grid.tileWidth * widthFraction
        return CGSize(width: width, height: width * (nativeSize.height / nativeSize.width))
    }

    init(fittingTo grid: IsoGrid) {
        super.init(texture: Self.texture, color: .clear, size: Self.spriteSize(fittingTo: grid))
        anchorPoint = Self.baseAnchor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopPrepTableNode")
    }
}
