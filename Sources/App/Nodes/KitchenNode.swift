import SpriteKit

/// A prep table standing in the shop's back-most footprint row, right in front of the back
/// wall. Purely visual for now — no cook or cooking props yet, and not wired to any
/// gameplay/staff-hire state.
final class KitchenLayer: SKNode {

    private static let tableTopTextureName = "kitchen_table_top"

    // The table spans roughly 2.3 of the shop's 4 columns — low and wide like a real prep
    // table seen front-on.
    private static let tableWidth = GroundTile.width * 2.3

    // The tabletop is a flat, horizontal surface sitting on the floor — like the ground
    // itself, not a standing upright sprite — so it's rendered as a tilted parallelogram
    // matching the ground/wall's isometric skew (see `GroundTile.path`), rather than a
    // plain front-facing rectangle. It's shallower ("front-to-back depth") than a full
    // ground tile since it's just a tabletop, not a whole extra floor tile.
    private static let tableDepth = GroundTile.height * 0.8

    // Matches GroundTile's own skew-to-height ratio (`GroundTile.skew / GroundTile.height`)
    // scaled down to the table's shallower depth, so the tabletop's shear angle visually
    // matches the ground/wall's shear angle exactly.
    private static let tableSkew = GroundTile.skew * (tableDepth / GroundTile.height)

    // Shifts the tabletop parallelogram so the shape's own horizontal center (the average of
    // its four corners) lands at local x = 0 — shared by `tableTopPath` and `tableApronPath`
    // so the apron's straight front edge lines up exactly under the tabletop's own front edge.
    private static let tableOffsetX = -(tableWidth + tableSkew) / 2

    /// The tabletop's outline: the same parallelogram construction as `GroundTile.path`
    /// (`(0,0)`, `(tableWidth,0)`, `(tableWidth+tableSkew,tableDepth)`, `(tableSkew,tableDepth)`),
    /// shifted by `tableOffsetX` so local x spans `-tableWidth/2 - tableSkew/2 ... tableWidth/2 +
    /// tableSkew/2`. This lets a caller position the node at `(centerX, centerY)` and have
    /// the rendered shape land horizontally centered on `centerX`.
    private static let tableTopPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tableOffsetX, y: 0))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth, y: 0))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth + tableSkew, y: tableDepth))
        path.addLine(to: CGPoint(x: tableOffsetX + tableSkew, y: tableDepth))
        path.closeSubpath()
        return path
    }()

    // A tilted parallelogram floating with nothing beneath it reads as a slab hovering above
    // the floor rather than a table standing on it. Rather than modeling individual legs, a
    // single straight-hanging "apron" panel — dropping vertically from the tabletop's own
    // front-bottom edge (no skew, since it's a front-facing vertical face, not a ground-plane
    // surface) — stands in for the legs/frame and visually grounds the table, the same way
    // ShopWallNode extrudes a vertical face down from the ground line instead of leaving a
    // flat tile floating in space.
    private static let tableApronHeight = GroundTile.height * 0.9

    /// The front apron's outline: a plain rectangle hanging from the tabletop's own
    /// front-bottom edge (`tableTopPath`'s first two points, at local y = 0) straight down by
    /// `tableApronHeight`, sharing `tableTopPath`'s exact x-range so the two seams align with
    /// no gap.
    private static let tableApronPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tableOffsetX, y: 0))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth, y: 0))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth, y: -tableApronHeight))
        path.addLine(to: CGPoint(x: tableOffsetX, y: -tableApronHeight))
        path.closeSubpath()
        return path
    }()

    // Darkens the apron's wood texture relative to the tabletop's own undimmed white tint —
    // the classic "lighter top face, darker front face" isometric shading cue that reinforces
    // the apron as a distinct vertical surface rather than more flat tabletop.
    private static let tableApronShadeColor = SKColor(white: 0.72, alpha: 1)

    /// The right side panel's outline: extrudes the tabletop's own right edge (`tableTopPath`'s
    /// skewed edge running from `(tableWidth,0)` front to `(tableWidth+tableSkew,tableDepth)`
    /// back) straight down by `tableApronHeight`, the same "extrude a diagonal ground-line edge
    /// downward into a vertical face" construction `ShopWallNode.wallSegmentPath` uses (there
    /// extruded upward from the ground instead of downward from a tabletop). Without this face
    /// the table reads as a flat top-plus-front cutout instead of a solid box — a real table
    /// standing on this isometric grid shows three faces (top, front, and this right side), not
    /// two.
    private static let tableRightPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tableOffsetX + tableWidth, y: 0))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth + tableSkew, y: tableDepth))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth + tableSkew, y: tableDepth - tableApronHeight))
        path.addLine(to: CGPoint(x: tableOffsetX + tableWidth, y: -tableApronHeight))
        path.closeSubpath()
        return path
    }()

    // Darker than the front apron's own shade — the right face angles further away from the
    // implied light source than the front face does, so it reads as the darkest of the table's
    // three visible faces (lightest top, mid-tone front, darkest side), matching how isometric
    // cubes are conventionally shaded.
    private static let tableRightShadeColor = SKColor(white: 0.6, alpha: 1)

    func layout(for size: CGSize) {
        removeAllChildren()

        let (shopStartRow, shopStartColumn) = ShopWallLayer.layoutMetrics(for: size)
        let (fieldStartRow, _) = FieldLayer.layoutMetrics(for: size)

        // The back-most of the shop's 3 footprint rows — directly in front of the back wall.
        let kitchenRowIndex = shopStartRow + ShopWallLayer.rowCount - 1
        let rowZPosition = ShopWallLayer.zPosition(forRowIndex: kitchenRowIndex, fieldStartRow: fieldStartRow)

        // Geometric centroid of the shop's full column span at this row — the same
        // "average of the parallelogram's corners" formula GroundLayer/FieldLayer/FarmerLayer
        // use to center content within a single tile cell, generalized here to the shop's
        // whole column width so the table lands centered under the roofline.
        let rowOriginX = CGFloat(shopStartColumn) * GroundTile.width + GroundTile.skew * CGFloat(kitchenRowIndex)
        let centerX = rowOriginX + CGFloat(ShopWallLayer.columnCount) * GroundTile.width / 2 + GroundTile.skew / 2
        let centerY = CGFloat(kitchenRowIndex) * GroundTile.height + GroundTile.height / 2

        // The tabletop is a flat horizontal surface, so it's built as a tilted parallelogram
        // shape textured with a top-down wood-plank texture (mirroring GroundTile/ShopWallNode's
        // "SKShapeNode with fillTexture" recipe for tilted surfaces), rather than an upright
        // front-view sprite — a plain rectangle would ignore the isometric skew the ground and
        // walls are drawn with.
        let table = SKShapeNode(path: Self.tableTopPath)
        table.fillTexture = SKTexture(imageNamed: Self.tableTopTextureName)
        table.fillColor = .white
        table.strokeColor = GroundTile.strokeColor
        table.lineWidth = 1
        table.position = CGPoint(x: centerX, y: centerY)
        table.zPosition = rowZPosition
        addChild(table)

        // The apron hangs from the tabletop's own front-bottom edge, so it's added as a child
        // of `table` rather than positioned independently — it inherits `table`'s position and
        // shares its exact local coordinate frame, guaranteeing the two seams align.
        let apron = SKShapeNode(path: Self.tableApronPath)
        apron.fillTexture = SKTexture(imageNamed: Self.tableTopTextureName)
        apron.fillColor = Self.tableApronShadeColor
        apron.strokeColor = GroundTile.strokeColor
        apron.lineWidth = 1
        table.addChild(apron)

        // The right side panel hangs from the tabletop's own right edge, same child-of-`table`
        // reasoning as the front apron above: it inherits `table`'s position and shares its
        // exact local coordinate frame, so this seam and the apron's shared corner both align
        // with no gap.
        let rightPanel = SKShapeNode(path: Self.tableRightPath)
        rightPanel.fillTexture = SKTexture(imageNamed: Self.tableTopTextureName)
        rightPanel.fillColor = Self.tableRightShadeColor
        rightPanel.strokeColor = GroundTile.strokeColor
        rightPanel.lineWidth = 1
        table.addChild(rightPanel)
    }
}
