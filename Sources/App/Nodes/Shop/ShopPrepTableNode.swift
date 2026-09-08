import SpriteKit

/// The shop's empty cook/prep table. A `ShopNode` prop, not the Kitchen
/// scene's own furniture — it happens to share the `kitchen_prep_table`
/// asset name, not a class. Like the wall/ground tile nodes, it has no
/// say in the grid: it fits its footprint to whatever `IsoGrid` it's
/// handed at init.
final class ShopPrepTableNode: SKSpriteNode {

    private static let texture = SKTexture(imageNamed: "kitchen_prep_table")

    /// Camera-matrix measurement table, used as printed (not re-measured):
    /// trimmed 230×198, base-center anchor at (0.50000, 0.32035 from the
    /// bottom).
    private static let nativeSize = CGSize(width: 230, height: 198)
    private static let baseAnchor = CGPoint(x: 0.5, y: 0.32035)

    /// `grid.tileWidth` at the moment this asset was rendered — the
    /// isorender pipeline always renders at exactly 3× whatever the live
    /// grid's tile width is. Dividing `nativeSize` by `3 ×
    /// measuredGridTileWidth` turns it into a fraction of `grid.tileWidth`
    /// rather than a baked pixel size, so the table scales with the grid
    /// if it's ever retuned instead of drifting out of proportion.
    private static let measuredGridTileWidth: CGFloat = 126
    private static let widthFraction = nativeSize.width / (measuredGridTileWidth * 3)

    /// Footprint offset from the cell center, toward the wall behind it
    /// (row -0.5 in this cell) — deliberate, not derived from the art: it
    /// leaves a visible air gap off the wall while keeping 0.15 units of
    /// clearance to each side.
    static let footprintRowOffset: CGFloat = -0.15

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
