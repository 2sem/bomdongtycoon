import SpriteKit

/// Falling drops and ground splashes over the whole screen. `amount` eases 0...1 so rain fades
/// in and out; drops are recycled, never created per frame.
@MainActor
final class RainNode: SKNode {

    private struct Drop {
        let node: SKSpriteNode
        var x: CGFloat
        var y: CGFloat          // art px, y down
        var landY: CGFloat
    }

    private(set) var amount: CGFloat = 0
    private var drops: [Drop] = []
    private let layout: DotWorldLayout
    private let fx: FXLayer

    init(layout: DotWorldLayout, fx: FXLayer) {
        self.layout = layout
        self.fx = fx
        super.init()
        zPosition = 4500
        alpha = 0
        let width = layout.rightEdge - layout.leftEdge
        let height = layout.bottomEdge - layout.topEdge
        let count = max(24, Int(width * height / 650))
        for i in 0..<count {
            let node = dotSprite("dot_backdrop_raindrop", anchor: .pixel(0, 5))
            node.alpha = 1
            addChild(node)
            let x = layout.leftEdge + CGFloat(dotHash(i, 11) % 1000) / 1000 * width
            let y = layout.topEdge + CGFloat(dotHash(i, 12) % 1000) / 1000 * height
            let land = CGFloat(DotWorldLayout.backdropHeight + 20)
                + CGFloat(dotHash(i, 13) % 1000) / 1000 * (layout.bottomEdge - CGFloat(DotWorldLayout.backdropHeight + 20))
            drops.append(Drop(node: node, x: x, y: y, landY: max(land, y + 4)))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func update(delta: TimeInterval, isRaining: Bool, animated: Bool) {
        let target: CGFloat = isRaining ? 1 : 0
        let step = CGFloat(delta) * 1.2
        amount += max(-step, min(step, target - amount))
        alpha = amount
        isHidden = amount <= 0.001 || !animated
        guard !isHidden else { return }

        let d = CGFloat(delta)
        let width = layout.rightEdge - layout.leftEdge
        for i in drops.indices {
            drops[i].y += 110 * d
            drops[i].x -= 22 * d
            if drops[i].y >= drops[i].landY {
                if i % 3 == 0 { fx.rainSplash(at: feetPoint(drops[i].x.rounded(), drops[i].landY.rounded())) }
                let y = layout.topEdge - CGFloat(dotHash(i, Int(drops[i].landY)) % 30)
                drops[i].y = y
                drops[i].landY = max(CGFloat(DotWorldLayout.backdropHeight + 20) + CGFloat(dotHash(i, Int(y) &+ 7) % 1000) / 1000
                    * (layout.bottomEdge - CGFloat(DotWorldLayout.backdropHeight + 20)), y + 4)
            }
            if drops[i].x < layout.leftEdge { drops[i].x += width }
            drops[i].node.position = feetPoint(drops[i].x.rounded(), drops[i].y.rounded())
        }
    }
}
