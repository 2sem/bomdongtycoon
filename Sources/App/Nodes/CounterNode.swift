import SpriteKit

/// The service counter and the cashier staffing it, standing inside `ShopWallLayer`'s open
/// (south) front — the counter sits at the shop's front row facing the camera, and the
/// cashier stands one row further back, on the interior side, as if working the register.
/// Purely visual for now — not wired to any gameplay/staff-hire state (`StallState`'s
/// `cashierCount`/`cashierTier` are intentionally left untouched by this layer).
final class CounterLayer: SKNode {

    private static let counterTextureName = "shop_counter"
    private static let cashierTextureName = "staff_cashier"

    // The counter spans the middle 2 of the shop's 4 columns, centered within the shop's
    // own footprint rather than the full width, so it reads as a single service desk rather
    // than a wall-to-wall divider.
    private static let counterColumnSpan = 2

    // The cashier stands directly behind the counter, one row further into the shop's
    // interior — mirroring how FarmerLayer stands one row behind FieldLayer's own rows.
    private static let cashierRowOffset = 1

    // Fixed-height, aspect-derived-width sizing (same convention FarmerLayer uses for its
    // own figure) rather than fixed-width: the source art's crop includes both the desk box
    // AND the raised register standing on top of it, so anchoring size to a target *width*
    // (~2 tile-columns) would inflate the resulting height — via the aspect ratio — to
    // roughly a full standing-figure's height. That leaves almost no vertical clearance for
    // the cashier standing only one row (one `GroundTile.height` step) further back to rise
    // above it. Sizing by height instead keeps the counter at a believable waist/chest-high
    // scale (well under FarmerLayer's full-body `GroundTile.height * 3`), which is what
    // actually determines how much of the cashier clears its top.
    private static let counterHeight = GroundTile.height * 2

    // Source art is a bust portrait (head + shoulders, no legs). Sized so a clear majority
    // of it rises above `counterHeight` once placed one row back (see the clearance math in
    // `layout(for:)`), reading as "visible from the counter-top up" rather than swallowed by
    // the counter in front of it.
    private static let cashierHeight = GroundTile.height * 2.5

    func layout(for size: CGSize) {
        removeAllChildren()

        // Reuse ShopWallLayer's own footprint math exactly, mirroring how ShopWallLayer
        // itself reuses FieldLayer's — one source of truth for "where is the shop" shared by
        // every layer that furnishes its interior.
        let (shopStartRow, shopStartColumn) = ShopWallLayer.layoutMetrics(for: size)
        let (fieldStartRow, _) = FieldLayer.layoutMetrics(for: size)

        // Column span centered within the shop's 4-column footprint, e.g. columns 1 and 2
        // of 0..<4 for a 2-column span.
        let spanStartColumn = shopStartColumn + (ShopWallLayer.columnCount - Self.counterColumnSpan) / 2

        let counterRowIndex = shopStartRow
        let cashierRowIndex = shopStartRow + Self.cashierRowOffset

        addChild(makeCounter(rowIndex: counterRowIndex, spanStartColumn: spanStartColumn, fieldStartRow: fieldStartRow))
        addChild(makeCashier(rowIndex: cashierRowIndex, spanStartColumn: spanStartColumn, fieldStartRow: fieldStartRow))
    }

    /// Horizontal center, in world x, of the `counterColumnSpan`-wide column band starting
    /// at `spanStartColumn`, evaluated at `rowIndex`'s own skew — the same "glue adjacent
    /// tile parallelograms into one bigger parallelogram, then take its centroid" formula
    /// FieldLayer/FarmerLayer apply to a single column (this is that formula generalized to
    /// N columns; N == 1 reduces to their exact expression).
    private static func spanCenterX(spanStartColumn: Int, rowIndex: Int) -> CGFloat {
        CGFloat(spanStartColumn) * GroundTile.width
            + GroundTile.skew * CGFloat(rowIndex)
            + CGFloat(Self.counterColumnSpan) * GroundTile.width / 2
            + GroundTile.skew / 2
    }

    private func makeCounter(rowIndex: Int, spanStartColumn: Int, fieldStartRow: Int) -> SKSpriteNode {
        let texture = SKTexture(imageNamed: Self.counterTextureName)
        let aspect = texture.size().width / texture.size().height
        let counterSize = CGSize(width: Self.counterHeight * aspect, height: Self.counterHeight)

        let counter = SKSpriteNode(texture: texture)
        counter.size = counterSize

        // Anchor at the sprite's base so `position` lands on the tile's ground line rather
        // than the sprite's visual center, matching FarmerLayer's convention.
        counter.anchorPoint = CGPoint(x: 0.5, y: 0)

        let centerX = Self.spanCenterX(spanStartColumn: spanStartColumn, rowIndex: rowIndex)
        let tileOriginY = CGFloat(rowIndex) * GroundTile.height
        counter.position = CGPoint(x: centerX, y: tileOriginY + GroundTile.height / 2)

        counter.zPosition = ShopWallLayer.zPosition(forRowIndex: rowIndex, fieldStartRow: fieldStartRow)

        return counter
    }

    private func makeCashier(rowIndex: Int, spanStartColumn: Int, fieldStartRow: Int) -> SKSpriteNode {
        let texture = SKTexture(imageNamed: Self.cashierTextureName)
        let aspect = texture.size().width / texture.size().height
        let cashierSize = CGSize(width: Self.cashierHeight * aspect, height: Self.cashierHeight)

        let cashier = SKSpriteNode(texture: texture)
        cashier.size = cashierSize
        cashier.anchorPoint = CGPoint(x: 0.5, y: 0)

        // Recomputed at the cashier's own (one-row-further-back) rowIndex, so the skew term
        // shifts it to the correct on-screen spot directly behind the counter, rather than
        // reusing the counter's raw x — the same row-offset pattern FarmerLayer/ShopWallNode
        // use throughout this scene.
        let centerX = Self.spanCenterX(spanStartColumn: spanStartColumn, rowIndex: rowIndex)
        let tileOriginY = CGFloat(rowIndex) * GroundTile.height
        cashier.position = CGPoint(x: centerX, y: tileOriginY + GroundTile.height / 2)

        cashier.zPosition = ShopWallLayer.zPosition(forRowIndex: rowIndex, fieldStartRow: fieldStartRow)

        return cashier
    }
}
