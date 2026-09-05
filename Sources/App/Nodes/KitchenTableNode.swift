import SpriteKit

/// A free-standing prep table rendered as a tilted three-face box — top, front apron, and
/// right side panel — matching the ground/wall's isometric skew (see `GroundTile.path` for
/// the same parallelogram construction this mirrors). Local `(0,0)` is the tabletop's own
/// front-bottom-center point, so a caller just sets `position` to place it in the world, the
/// same way `SKShapeNode`/`SKSpriteNode` placement works elsewhere in this codebase.
final class KitchenTableNode: SKNode {

    private static let topTextureName = "kitchen_table_top"

    // The table spans roughly 2.3 of the shop's 4 columns — low and wide like a real prep
    // table seen front-on.
    static let width = GroundTile.width * 2.3

    // The tabletop is a flat, horizontal surface sitting on the floor — like the ground
    // itself, not a standing upright sprite — so it's rendered as a tilted parallelogram
    // matching the ground/wall's isometric skew (see `GroundTile.path`), rather than a
    // plain front-facing rectangle. It's shallower ("front-to-back depth") than a full
    // ground tile since it's just a tabletop, not a whole extra floor tile.
    static let depth = GroundTile.height * 0.8

    // Matches GroundTile's own skew-to-height ratio (`GroundTile.skew / GroundTile.height`)
    // scaled down to the table's shallower depth, so the tabletop's shear angle visually
    // matches the ground/wall's shear angle exactly.
    private static let skew = GroundTile.skew * (depth / GroundTile.height)

    // Shifts the tabletop parallelogram so the shape's own horizontal center (the average of
    // its four corners) lands at local x = 0 — shared by `topPath`, `apronPath`, and
    // `rightPath` so every face's shared edges line up with no gap.
    private static let offsetX = -(width + skew) / 2

    /// The tabletop's outline: the same parallelogram construction as `GroundTile.path`
    /// (`(0,0)`, `(width,0)`, `(width+skew,depth)`, `(skew,depth)`), shifted by `offsetX` so
    /// local x spans `-width/2 - skew/2 ... width/2 + skew/2`. This lets a caller position
    /// this node at `(centerX, centerY)` and have the rendered shape land horizontally
    /// centered on `centerX`.
    private static let topPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: offsetX, y: 0))
        path.addLine(to: CGPoint(x: offsetX + width, y: 0))
        path.addLine(to: CGPoint(x: offsetX + width + skew, y: depth))
        path.addLine(to: CGPoint(x: offsetX + skew, y: depth))
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
    private static let apronHeight = GroundTile.height * 0.9

    /// The front apron's outline: a plain rectangle hanging from the tabletop's own
    /// front-bottom edge (`topPath`'s first two points, at local y = 0) straight down by
    /// `apronHeight`, sharing `topPath`'s exact x-range so the two seams align with no gap.
    private static let apronPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: offsetX, y: 0))
        path.addLine(to: CGPoint(x: offsetX + width, y: 0))
        path.addLine(to: CGPoint(x: offsetX + width, y: -apronHeight))
        path.addLine(to: CGPoint(x: offsetX, y: -apronHeight))
        path.closeSubpath()
        return path
    }()

    // Darkens the apron's wood texture relative to the tabletop's own undimmed white tint —
    // the classic "lighter top face, darker front face" isometric shading cue that reinforces
    // the apron as a distinct vertical surface rather than more flat tabletop.
    private static let apronShadeColor = SKColor(white: 0.72, alpha: 1)

    /// The right side panel's outline: extrudes the tabletop's own right edge (`topPath`'s
    /// skewed edge running from `(width,0)` front to `(width+skew,depth)` back) straight down
    /// by `apronHeight`, the same "extrude a diagonal ground-line edge downward into a
    /// vertical face" construction `ShopWallNode.wallSegmentPath` uses (there extruded upward
    /// from the ground instead of downward from a tabletop). Without this face the table reads
    /// as a flat top-plus-front cutout instead of a solid box — a real table standing on this
    /// isometric grid shows three faces (top, front, and this right side), not two.
    private static let rightPath: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: offsetX + width, y: 0))
        path.addLine(to: CGPoint(x: offsetX + width + skew, y: depth))
        path.addLine(to: CGPoint(x: offsetX + width + skew, y: depth - apronHeight))
        path.addLine(to: CGPoint(x: offsetX + width, y: -apronHeight))
        path.closeSubpath()
        return path
    }()

    // Darker than the front apron's own shade — the right face angles further away from the
    // implied light source than the front face does, so it reads as the darkest of the table's
    // three visible faces (lightest top, mid-tone front, darkest side), matching how isometric
    // cubes are conventionally shaded.
    private static let rightShadeColor = SKColor(white: 0.6, alpha: 1)

    override init() {
        super.init()

        // The tabletop is a flat horizontal surface, so it's built as a tilted parallelogram
        // shape textured with a top-down wood-plank texture (mirroring GroundTile/ShopWallNode's
        // "SKShapeNode with fillTexture" recipe for tilted surfaces), rather than an upright
        // front-view sprite — a plain rectangle would ignore the isometric skew the ground and
        // walls are drawn with.
        let top = SKShapeNode(path: Self.topPath)
        top.fillTexture = SKTexture(imageNamed: Self.topTextureName)
        top.fillColor = .white
        top.strokeColor = GroundTile.strokeColor
        top.lineWidth = 1
        addChild(top)

        let apron = SKShapeNode(path: Self.apronPath)
        apron.fillTexture = SKTexture(imageNamed: Self.topTextureName)
        apron.fillColor = Self.apronShadeColor
        apron.strokeColor = GroundTile.strokeColor
        apron.lineWidth = 1
        addChild(apron)

        let rightPanel = SKShapeNode(path: Self.rightPath)
        rightPanel.fillTexture = SKTexture(imageNamed: Self.topTextureName)
        rightPanel.fillColor = Self.rightShadeColor
        rightPanel.strokeColor = GroundTile.strokeColor
        rightPanel.lineWidth = 1
        addChild(rightPanel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
