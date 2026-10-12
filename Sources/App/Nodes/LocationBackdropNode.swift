import SpriteKit

/// The per-location scenery along the map's two back edges, one set per
/// `locationTier`, all built once and toggled by `apply(tier:)` — same
/// approach as `ShopNode`'s three enclosures.
///
/// Each piece is a one-cell-edge module, tiled once per cell the way the
/// shop's walls are: back-left runs down the map's minimum-column edge
/// (`GroundLayer.mapOrigin.col - 0.5`, one module per row) anchored on the
/// cell's West vertex like `StallWallBackNode`; back-right runs along the
/// minimum-row edge (one module per column) anchored on the North vertex
/// like the shop's right wall. Both reuse the shop's z-rule
/// (`ShopNode.zPosition`, `.back` / `.right` slot, keyed off col + row), so
/// a module sorts behind everything standing on or in front of its cell.
///
/// Added to the scene directly, not under `GroundLayer`, so its z values
/// share the unscaled `col + row` scale the shop and ground use.
final class LocationBackdropNode: SKNode {

    /// Trimmed PNG pixel sizes and face-corner anchors (bottom-up
    /// fractions) off the render's measurement table; Gangnam's right
    /// piece differs from its left by 1px in height because its trim does.
    struct Piece {
        let imageName: String
        let nativeSize: CGSize
        let anchor: CGPoint
    }

    struct LocationSet {
        let left: Piece
        let right: Piece
    }

    static let sets: [LocationSet] = [
        LocationSet(
            left: Piece(imageName: "backdrop_alley_back_left", nativeSize: CGSize(width: 208, height: 466),
                        anchor: CGPoint(x: 0.99096, y: 0.25333)),
            right: Piece(imageName: "backdrop_alley_back_right", nativeSize: CGSize(width: 208, height: 466),
                         anchor: CGPoint(x: 0.00904, y: 0.25333))),
        LocationSet(
            left: Piece(imageName: "backdrop_market_back_left", nativeSize: CGSize(width: 208, height: 371),
                        anchor: CGPoint(x: 0.99096, y: 0.31916)),
            right: Piece(imageName: "backdrop_market_back_right", nativeSize: CGSize(width: 208, height: 371),
                         anchor: CGPoint(x: 0.00904, y: 0.31916))),
        LocationSet(
            left: Piece(imageName: "backdrop_gangnam_back_left", nativeSize: CGSize(width: 207, height: 635),
                        anchor: CGPoint(x: 0.99333, y: 0.18639)),
            right: Piece(imageName: "backdrop_gangnam_back_right", nativeSize: CGSize(width: 207, height: 634),
                         anchor: CGPoint(x: 0.00667, y: 0.18669)))
    ]

    /// Half-edge depth vector of the 3x render, as in `ShopTierWallNode`:
    /// one cell edge is 189 x 116.49 px, so each module is scaled to span
    /// exactly half a tile in each axis and the art is not stretched.
    private static let depthX: CGFloat = 189.0
    private static let depthY: CGFloat = 116.49

    private var setNodes: [SKNode] = []

    init(fittingTo grid: IsoGrid) {
        super.init()
        for set in Self.sets {
            let container = SKNode()

            // Back-left: minimum column, one module per row, West vertex.
            let firstCol = GroundLayer.mapColumns.lowerBound
            for row in GroundLayer.mapRows {
                let center = grid.point(col: firstCol, row: row)
                let node = Self.sprite(set.left, fittingTo: grid)
                node.position = CGPoint(x: center.x - grid.tileWidth / 2, y: center.y)
                node.zPosition = ShopNode.zPosition(col: firstCol, row: row, slot: .back)
                container.addChild(node)
            }

            // Back-right: minimum row, one module per column, North vertex.
            let firstRow = GroundLayer.mapRows.lowerBound
            for col in GroundLayer.mapColumns {
                let center = grid.point(col: col, row: firstRow)
                let node = Self.sprite(set.right, fittingTo: grid)
                node.position = CGPoint(x: center.x, y: center.y + grid.tileHeight / 2)
                node.zPosition = ShopNode.zPosition(col: col, row: firstRow, slot: .right)
                container.addChild(node)
            }

            addChild(container)
            setNodes.append(container)
        }
        apply(tier: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for LocationBackdropNode")
    }

    func apply(tier: Int) {
        let shown = max(0, min(tier, setNodes.count - 1))
        for (index, node) in setNodes.enumerated() {
            node.isHidden = index != shown
        }
    }

    private static func sprite(_ piece: Piece, fittingTo grid: IsoGrid) -> SKSpriteNode {
        let scaleX = (grid.tileWidth / 2) / depthX
        let scaleY = (grid.tileHeight / 2) / depthY
        let size = CGSize(width: piece.nativeSize.width * scaleX, height: piece.nativeSize.height * scaleY)
        let node = SKSpriteNode(texture: SKTexture(imageNamed: piece.imageName), color: .clear, size: size)
        node.anchorPoint = piece.anchor
        return node
    }
}
