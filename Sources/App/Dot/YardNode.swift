import SpriteKit
import GameCore

/// Yard band: the warehouse crate with its `count/capacity` label, plus a couple of bushes.
@MainActor
final class YardNode: BandNode {

    private let crate = dotSprite("dot_farm_warehouse_crate_empty")
    private let label: PixelLabel
    private let crateRow: CGFloat
    private var lastKey = ""

    init(layout: DotWorldLayout) {
        crateRow = CGFloat(layout.yardHeight - 3)
        label = PixelLabel(style: .small, scale: layout.scale, alignment: .left)
        super.init(top: layout.yardTop)
        zPosition = 300
        crate.position = feetPoint(22, crateRow)
        addChild(crate)
        label.position = artPoint(42, crateRow - 8)
        addChild(label)

        let bushes: [(CGFloat, CGFloat)] = [(130, CGFloat(layout.yardHeight) - 12), (112, CGFloat(layout.yardHeight) - 2)]
        for (x, y) in bushes {
            let bush = dotSprite("dot_ground_bush")
            bush.position = feetPoint(x, y)
            bush.zPosition = -1
            addChild(bush)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Where harvested cabbages land.
    var cratePoint: CGPoint { rootPoint(22, crateRow - 14) }

    func hit(local p: CGPoint) -> Bool {
        p.x >= 4 && p.x < 56 && p.y >= crateRow - 26 && p.y < crateRow + 4
    }

    func bump(reduceMotion: Bool) { FXLayer.squash(crate, reduceMotion: reduceMotion) }

    func apply(count: Int, capacity: Int) {
        let variant: String
        if count <= 0 { variant = "empty" }
        else if capacity > 0, Double(count) / Double(capacity) >= 0.8 { variant = "full" }
        else { variant = "half" }
        let key = "\(variant) \(count)/\(capacity)"
        guard key != lastKey else { return }
        lastKey = key
        crate.texture = DotTexture.named("dot_farm_warehouse_crate_\(variant)")
        label.text = "\(count)/\(capacity)"
    }
}
