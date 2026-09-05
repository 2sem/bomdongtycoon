import SpriteKit

/// A decorative prep kitchen — a table, small cooking props, and one cook figure — standing
/// in the shop's back-most footprint row, right in front of the back wall. Purely visual for
/// now: not wired to any gameplay/staff-hire state (see `StallState.menuCooks`, which this
/// intentionally ignores — a single cook figure stands in for the eventual roster).
final class KitchenLayer: SKNode {

    private static let tableTopTextureName = "kitchen_table_top"
    private static let burnerTextureName = "kitchen_burner"
    private static let potTextureName = "kitchen_pot"
    private static let soupPotTextureName = "kitchen_soup_pot"
    private static let bowlTextureName = "kitchen_bowl"
    private static let cookTextureName = "staff_chef_man"

    /// A prop's true visible-content bounding box within its source PNG, measured directly
    /// from the file's alpha channel. Unlike the standing character busts (whose baked-in
    /// padding is small enough to ignore — see `FarmerLayer`), these kitchen assets sit on a
    /// square canvas with a large transparent margin: sizing off the raw texture aspect would
    /// render them far smaller than intended and float them well above the tile they're meant
    /// to stand on. Cropping to this measured rect gives each prop its true visual aspect
    /// ratio and lets bottom-anchoring land exactly on the object's own base.
    private struct ContentBox {
        /// In image pixel space (origin top-left), matching how the box was measured.
        let pixelRect: CGRect
        /// The (square) source canvas's pixel width/height.
        let canvasSize: CGFloat

        /// Normalized rect in SKTexture's unit coordinate space (origin bottom-left, y-up).
        var unitRect: CGRect {
            CGRect(
                x: pixelRect.minX / canvasSize,
                y: (canvasSize - pixelRect.maxY) / canvasSize,
                width: pixelRect.width / canvasSize,
                height: pixelRect.height / canvasSize
            )
        }

        var aspect: CGFloat { pixelRect.width / pixelRect.height }
    }

    private static let burnerContentBox = ContentBox(pixelRect: CGRect(x: 160, y: 335, width: 814, height: 598), canvasSize: 1137)
    private static let potContentBox = ContentBox(pixelRect: CGRect(x: 102, y: 272, width: 939, height: 680), canvasSize: 1137)
    private static let soupPotContentBox = ContentBox(pixelRect: CGRect(x: 135, y: 159, width: 864, height: 824), canvasSize: 1137)
    private static let bowlContentBox = ContentBox(pixelRect: CGRect(x: 169, y: 153, width: 796, height: 831), canvasSize: 1137)

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

    /// The tabletop's outline: the same parallelogram construction as `GroundTile.path`
    /// (`(0,0)`, `(tableWidth,0)`, `(tableWidth+tableSkew,tableDepth)`, `(tableSkew,tableDepth)`),
    /// shifted so the shape's own horizontal center (the average of its four corners) lands
    /// at local x = 0 — local x spans `-tableWidth/2 - tableSkew/2 ... tableWidth/2 +
    /// tableSkew/2`. This lets a caller position the node at `(centerX, centerY)` and have
    /// the rendered shape land horizontally centered on `centerX`, the same way the old
    /// rectangular table (anchorPoint (0.5, 0)) did.
    private static let tableTopPath: CGPath = {
        let offsetX = -(tableWidth + tableSkew) / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: offsetX, y: 0))
        path.addLine(to: CGPoint(x: offsetX + tableWidth, y: 0))
        path.addLine(to: CGPoint(x: offsetX + tableWidth + tableSkew, y: tableDepth))
        path.addLine(to: CGPoint(x: offsetX + tableSkew, y: tableDepth))
        path.closeSubpath()
        return path
    }()

    // Props sized as a fraction of one tile-width so they read as small kitchen items sitting
    // on the table rather than dominating it.
    private static let burnerWidth = GroundTile.width * 0.42
    private static let potWidth = GroundTile.width * 0.30
    private static let soupPotWidth = GroundTile.width * 0.38
    private static let bowlWidth = GroundTile.width * 0.36

    // The cook stands a fraction of a tile further back than the table's own row. There's no
    // spare full row available here — this is the shop's back-most footprint row, right
    // against the back wall — unlike the farmer/cashier setups, which had a whole extra row.
    // Rather than a flat offset from the row's own ground line, this is measured from the
    // table's own rendered back edge (see `layout(for:)`): only this much of the cook's own
    // height is tucked behind that edge, with the rest standing visibly above it. The
    // tabletop itself is now a shallow tilted surface (`tableDepth`, not the old tall
    // front-view image's rendered height), so this is derived as a fraction of `tableDepth`
    // rather than a flat `GroundTile.height`-scaled constant — anchoring a fixed amount tuned
    // for the old tall image would bury the cook's entire base below the new, much shorter
    // surface.
    private static let cookHiddenBehindTable = tableDepth * 0.3
    private static let cookHeight = GroundTile.height * 2.3

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
        // whole column width so the table and cook land centered under the roofline.
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

        // The cook stands just behind the table, mostly above its rendered back edge with
        // only a small amount of its own base tucked behind that edge (see
        // `cookHiddenBehindTable`'s doc comment). Added right after the table — but before
        // the tabletop props below — so it draws in front of the table's own back edge
        // (reading as "standing behind it") while the props still draw in front of the cook
        // where they sit on the table's surface, closer to the camera than the cook's torso.
        let tableTopEdgeY = table.position.y + Self.tableDepth
        let cookTexture = SKTexture(imageNamed: Self.cookTextureName)
        // The cook's source art is a square canvas with small baked-in padding (matching
        // FarmerLayer's own staff art), so — unlike the props below — the raw texture aspect
        // is fine to use as-is.
        let cookAspect = cookTexture.size().width / cookTexture.size().height
        let cook = SKSpriteNode(texture: cookTexture)
        cook.size = CGSize(width: Self.cookHeight * cookAspect, height: Self.cookHeight)
        cook.anchorPoint = CGPoint(x: 0.5, y: 0)
        cook.position = CGPoint(x: centerX, y: tableTopEdgeY - Self.cookHiddenBehindTable)
        cook.zPosition = rowZPosition
        addChild(cook)

        // Props sit near the tabletop's own back edge, nudged down slightly so their base
        // nestles into the surface instead of floating just above it. Added after the cook so
        // they read as sitting on the table in front of it, rather than the cook's body
        // covering them.
        let tabletopY = table.position.y + Self.tableDepth * 0.88

        let burner = Self.makeCroppedSprite(named: Self.burnerTextureName, contentBox: Self.burnerContentBox, width: Self.burnerWidth)
        burner.anchorPoint = CGPoint(x: 0.5, y: 0)
        burner.position = CGPoint(x: centerX - Self.tableWidth * 0.34, y: tabletopY)
        burner.zPosition = rowZPosition
        addChild(burner)

        // The pot sits directly on the burner: same x, drawn after it so it covers the
        // burner's flame ring instead of the other way around.
        let pot = Self.makeCroppedSprite(named: Self.potTextureName, contentBox: Self.potContentBox, width: Self.potWidth)
        pot.anchorPoint = CGPoint(x: 0.5, y: 0)
        pot.position = CGPoint(x: burner.position.x, y: tabletopY + burner.size.height * 0.35)
        pot.zPosition = rowZPosition
        addChild(pot)

        let soupPot = Self.makeCroppedSprite(named: Self.soupPotTextureName, contentBox: Self.soupPotContentBox, width: Self.soupPotWidth)
        soupPot.anchorPoint = CGPoint(x: 0.5, y: 0)
        soupPot.position = CGPoint(x: centerX, y: tabletopY)
        soupPot.zPosition = rowZPosition
        addChild(soupPot)

        let bowl = Self.makeCroppedSprite(named: Self.bowlTextureName, contentBox: Self.bowlContentBox, width: Self.bowlWidth)
        bowl.anchorPoint = CGPoint(x: 0.5, y: 0)
        bowl.position = CGPoint(x: centerX + Self.tableWidth * 0.36, y: tabletopY)
        bowl.zPosition = rowZPosition
        addChild(bowl)
    }

    private static func makeCroppedSprite(named name: String, contentBox: ContentBox, width desiredWidth: CGFloat) -> SKSpriteNode {
        let fullTexture = SKTexture(imageNamed: name)
        let croppedTexture = SKTexture(rect: contentBox.unitRect, in: fullTexture)
        let sprite = SKSpriteNode(texture: croppedTexture)
        sprite.size = CGSize(width: desiredWidth, height: desiredWidth / contentBox.aspect)
        return sprite
    }
}
