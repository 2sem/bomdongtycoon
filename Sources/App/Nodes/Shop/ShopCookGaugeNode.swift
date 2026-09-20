import SpriteKit

/// A thin progress bar over the prep table's small-bowl slot (menu index 0)
/// — fills left-to-right toward the next portion, resets when one
/// completes. Holds no game state itself: `ShopNode` owns and positions it
/// as furniture, `MainStallScene` pushes fresh numbers in every frame.
final class ShopCookGaugeNode: SKNode {

    private let track = SKShapeNode()
    private let fill = SKShapeNode()

    /// Bar size in points, exposed so `ShopNode` can place it a bar-height
    /// clear of the bowl's rim without a second, separately-guessed offset.
    let width: CGFloat
    let height: CGFloat

    private static let fillColor = SKColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1)
    private static let strokeColor = SKColor(red: 0.10, green: 0.38, blue: 0.18, alpha: 1)

    /// Same derivation every isorender prop in this catalog uses —
    /// `grid.tileWidth` divided by its own reference tile width — so a
    /// hand-drawn shape (no native pixel size to scale from) still holds
    /// its ~26×5pt proportions if the grid is retuned.
    private static let referenceTileWidth: CGFloat = 126
    private static let referenceWidth: CGFloat = 26
    private static let referenceHeight: CGFloat = 5

    init(fittingTo grid: IsoGrid) {
        width = grid.tileWidth * (Self.referenceWidth / Self.referenceTileWidth)
        height = grid.tileWidth * (Self.referenceHeight / Self.referenceTileWidth)
        super.init()

        let corner = height / 2
        track.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: corner, cornerHeight: corner, transform: nil
        )
        track.fillColor = SKColor(white: 0, alpha: 0.35)
        track.strokeColor = Self.strokeColor
        track.lineWidth = 1
        addChild(track)

        // Fill's own local origin sits at the bar's left edge, not its
        // centre, so scaling `xScale` below grows it rightward from that
        // edge instead of from the middle.
        fill.path = CGPath(rect: CGRect(x: 0, y: -height / 2, width: width, height: height), transform: nil)
        fill.position.x = -width / 2
        fill.fillColor = Self.fillColor
        fill.strokeColor = .clear
        fill.xScale = 0
        addChild(fill)

        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopCookGaugeNode")
    }

    /// Called every frame — the only per-frame work is this `xScale`
    /// assignment, no node allocation or `SKAction`.
    func update(progress: Double, isVisible: Bool) {
        isHidden = !isVisible
        fill.xScale = CGFloat(min(max(progress, 0), 1))
    }
}
