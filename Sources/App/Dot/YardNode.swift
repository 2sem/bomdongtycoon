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
    private let gift = GiftNode()
    private static let giftX: CGFloat = 99
    private let labelLayer: SKNode
    private var notice: SKNode?
    private let noticeLines: [PixelLabel]

    init(layout: DotWorldLayout, labelLayer: SKNode) {
        crateRow = CGFloat(layout.yardHeight - 3)
        self.labelLayer = labelLayer
        label = PixelLabel(style: .tiny, scale: layout.scale, alignment: .left)
        noticeLines = (0..<2).map { _ in PixelLabel(style: .tiny, scale: layout.scale, color: SKColor(hex: 0x2b1b2e), shadowColor: nil) }
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
        gift.position = feetPoint(Self.giftX, crateRow)
        gift.zPosition = 6
        addChild(gift)

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

    /// Where the gift crate sits, for the sparkle.
    var giftPoint: CGPoint { rootPoint(Self.giftX, crateRow - 7) }

    /// A generous box around the crate: it is a rare, timed tap.
    func hitGift(local p: CGPoint) -> Bool {
        p.x >= Self.giftX - 16 && p.x < Self.giftX + 16 && p.y >= crateRow - 24 && p.y < crateRow + 4
    }

    func setGift(isPresent: Bool, remaining: Double, reduceMotion: Bool) {
        if isPresent {
            gift.appear(reduceMotion: reduceMotion)
            gift.setRemaining(remaining, reduceMotion: reduceMotion)
        } else {
            gift.disappear()
        }
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

    func shake(reduceMotion: Bool) { FXLayer.shake(crate, reduceMotion: reduceMotion) }

    /// A speech plate beside the crate saying why a harvest bounced. Two short lines, ink-edged like
    /// the rest of the UI, gone after a couple of seconds; showing it again restarts the timer.
    func showNotice(_ lines: [String], duration: TimeInterval = 2.4, reduceMotion: Bool) {
        let node = notice ?? makeNotice()
        for (label, text) in zip(noticeLines, lines) { label.text = text }
        let width = (noticeLines.map(\.contentWidth).max() ?? 0).rounded(.up) + 8
        let height: CGFloat = 24
        let origin = rootPoint(38, crateRow - 11)
        node.position = CGPoint(x: origin.x.rounded(), y: origin.y.rounded())
        guard let ink = node.childNode(withName: "ink") as? SKSpriteNode,
              let paper = node.childNode(withName: "paper") as? SKSpriteNode else { return }
        ink.size = CGSize(width: width + 2, height: height + 2)
        paper.size = CGSize(width: width, height: height)
        paper.position = CGPoint(x: 1, y: 1)
        for (i, label) in noticeLines.enumerated() {
            label.position = CGPoint(x: 1 + (width / 2).rounded(.down), y: CGFloat(i == 0 ? 14 : 5) + 1)
        }
        node.removeAllActions()
        node.alpha = 1
        node.isHidden = false
        node.run(.sequence([.wait(forDuration: duration),
                            .fadeOut(withDuration: reduceMotion ? 0.05 : 0.25),
                            .hide()]))
    }

    private func makeNotice() -> SKNode {
        let node = SKNode()
        node.zPosition = 20
        let ink = SKSpriteNode(color: SKColor(hex: 0x2b1b2e), size: .zero)
        ink.name = "ink"
        ink.anchorPoint = .zero
        let paper = SKSpriteNode(color: SKColor(hex: 0xfffaf0), size: .zero)
        paper.name = "paper"
        paper.anchorPoint = .zero
        node.addChild(ink)
        node.addChild(paper)
        for label in noticeLines { node.addChild(label); label.zPosition = 1 }
        labelLayer.addChild(node)
        notice = node
        return node
    }

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
