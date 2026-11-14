import SpriteKit
import GameCore

/// Yard band: the warehouse crate with its `count/capacity` label, plus a couple of bushes.
@MainActor
final class YardNode: BandNode {

    private let crate = dotSprite("dot_farm_warehouse_crate_empty")
    private let label: PixelLabel
    private let crateRow: CGFloat
    private let alert = SKNode()
    private let alertRest: CGPoint
    private var lastKey = ""

    init(layout: DotWorldLayout, labelLayer: SKNode) {
        crateRow = CGFloat(layout.yardHeight - 3)
        label = PixelLabel(style: .tiny, scale: layout.scale, alignment: .left)
        alertRest = feetPoint(76, CGFloat(layout.yardHeight - 3) - 3)
        super.init(top: layout.yardTop)
        zPosition = 300
        crate.position = feetPoint(22, crateRow)
        addChild(crate)
        label.position = rootPoint(40, crateRow - 8)
        labelLayer.addChild(label)

        // Beside the count label, inside the yard: above the crate it would cover the street's customers.
        alert.position = alertRest
        alert.zPosition = 5
        alert.isHidden = true
        alert.addChild(dotSprite("dot_fx_bubble", anchor: .pixel(10, 21)))
        let mark = PixelLabel(style: .bold, scale: layout.scale, color: SKColor(hex: 0xd94a40), shadowColor: nil)
        mark.text = "!"
        mark.position = CGPoint(x: 0, y: 8)
        mark.zPosition = 0.1
        alert.addChild(mark)
        addChild(alert)

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

    /// A "!" bubble over the crate while the warehouse is empty and a dish has no stock.
    func setAlert(_ active: Bool, reduceMotion: Bool) {
        alert.isHidden = !active
        if active, !reduceMotion {
            guard alert.action(forKey: "bob") == nil else { return }
            alert.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.4), .moveBy(x: 0, y: -1, duration: 0.4)])),
                      withKey: "bob")
        } else {
            alert.removeAction(forKey: "bob")
            alert.position = alertRest
        }
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
