import SpriteKit

/// Coins a served customer leaves on the street. Each can be tapped for its tip until it fades.
/// The amount and the roll belong to `GameStore`; this only draws, ages and hit-tests them.
@MainActor
final class TipLayer: SKNode {

    static let maxCount = 6
    static let lifetime: TimeInterval = 6
    /// Last stretch of the lifetime, spent blinking so a coin about to vanish is noticed.
    private static let fadeWindow: TimeInterval = 1.5
    /// Generous next to the 8 px coin: a finger is far bigger than the sprite.
    private static let hitRadius: CGFloat = 11

    private final class Tip {
        let node = SKNode()
        let amount: Double
        var age: TimeInterval = 0
        init(amount: Double) { self.amount = amount }
    }

    private var tips: [Tip] = []

    override init() {
        super.init()
        zPosition = 5800
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var count: Int { tips.count }

    /// False, drawing nothing, while `maxCount` coins are already out.
    @discardableResult
    func drop(at point: CGPoint, amount: Double, reduceMotion: Bool) -> Bool {
        guard tips.count < Self.maxCount else { return false }
        let tip = Tip(amount: amount)
        let coin = dotSprite("dot_fx_coin_0", anchor: .pixel(4, 4))
        let spark = dotSprite("dot_fx_sparkle_0", anchor: .pixel(3, 3))
        spark.position = CGPoint(x: 4, y: 5)
        spark.zPosition = 0.1
        tip.node.addChild(coin)
        tip.node.addChild(spark)
        tip.node.position = CGPoint(x: point.x.rounded(.down) + 0.5, y: point.y.rounded())
        addChild(tip.node)
        if !reduceMotion {
            coin.run(.repeatForever(.animate(with: DotTexture.frames("dot_fx_coin", count: 4),
                                             timePerFrame: 0.12, resize: false, restore: false)))
            coin.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.35), .moveBy(x: 0, y: -1, duration: 0.35)])))
            spark.run(.repeatForever(.sequence([
                .animate(with: DotTexture.frames("dot_fx_sparkle", count: 4), timePerFrame: 0.09, resize: false, restore: false),
                .wait(forDuration: 0.9)])))
        }
        tips.append(tip)
        return true
    }

    func update(delta: TimeInterval) {
        for tip in tips {
            if DotDebug.alwaysTips { continue }
            tip.age += delta
            let left = Self.lifetime - tip.age
            if left < Self.fadeWindow {
                tip.node.alpha = Int(tip.age * 8) % 2 == 0 ? 1 : 0.35
            }
        }
        tips.removeAll { tip in
            guard tip.age >= Self.lifetime else { return false }
            tip.node.removeFromParent()
            return true
        }
    }

    /// Takes the tip under `point` (root space), if any: its amount and where it lay.
    func collect(at point: CGPoint) -> (amount: Double, point: CGPoint)? {
        let hit = tips
            .map { (tip: $0, distance: hypot($0.node.position.x - point.x, $0.node.position.y + 4 - point.y)) }
            .filter { $0.distance <= Self.hitRadius }
            .min { $0.distance < $1.distance }
        guard let tip = hit?.tip else { return nil }
        let at = tip.node.position
        tip.node.removeFromParent()
        tips.removeAll { $0 === tip }
        return (tip.amount, at)
    }

    /// Every coin on the street, root space; for the QA autoplayer.
    var points: [CGPoint] { tips.map(\.node.position) }

    func removeAll() {
        for tip in tips { tip.node.removeFromParent() }
        tips.removeAll()
    }
}
