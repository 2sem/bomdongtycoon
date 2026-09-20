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

    // Deliberately not CookButtonNode's greens: that button is 110×50pt on a
    // plain background, where a mid-dark green reads fine. This bar is
    // 26×6pt sitting on a brown bowl/table against green ground tiles, so a
    // green fill has neither hue nor value separation from what's behind
    // it. Amber sits opposite the ground's green in hue and well above the
    // bowl/table in luminance, separating on both axes; the near-opaque
    // dark track and near-black stroke keep the empty portion and the edge
    // readable against light and dark art alike. Do not "fix" this back to
    // match the button — the two contexts need different palettes on purpose.
    private static let fillColor = SKColor(red: 1.0, green: 0.69, blue: 0.13, alpha: 1)
    private static let trackColor = SKColor(red: 0.10, green: 0.09, blue: 0.08, alpha: 0.85)
    private static let strokeColor = SKColor(white: 0.05, alpha: 1)

    /// Same derivation every isorender prop in this catalog uses —
    /// `grid.tileWidth` divided by its own reference tile width — so a
    /// hand-drawn shape (no native pixel size to scale from) still holds
    /// its ~26×6pt proportions if the grid is retuned.
    private static let referenceTileWidth: CGFloat = 126
    private static let referenceWidth: CGFloat = 26
    private static let referenceHeight: CGFloat = 6

    init(fittingTo grid: IsoGrid) {
        width = grid.tileWidth * (Self.referenceWidth / Self.referenceTileWidth)
        height = grid.tileWidth * (Self.referenceHeight / Self.referenceTileWidth)
        super.init()

        let corner = height / 2
        track.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: corner, cornerHeight: corner, transform: nil
        )
        track.fillColor = Self.trackColor
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
