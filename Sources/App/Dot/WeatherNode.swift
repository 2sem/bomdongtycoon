import SpriteKit
import GameCore

/// Rain, snow, falling leaves and blossom over the whole screen. Each event owns a recycled pool of
/// sprites whose `amount` eases 0...1, so weather fades in and out; nothing is created per frame.
@MainActor
final class WeatherNode: SKNode {

    private struct Particle {
        let node: SKSpriteNode
        var x: CGFloat
        var y: CGFloat          // art px, y down
        var landY: CGFloat      // where it is recycled (rain: where it splashes)
        let phase: CGFloat
    }

    private final class Pool {
        let container = SKNode()
        var particles: [Particle] = []
        var amount: CGFloat = 0
    }

    /// Multiply tint the world takes on while this weather is fully in: rain greys the light, snow
    /// cools it, leaves warm it, blossom blushes it.
    private static let tints: [Weather: UInt32] = [.rain: 0xb4bfd6, .snow: 0xd6e2f5, .leaves: 0xf0d6a8, .petals: 0xf8e0e8]

    private let pools: [Weather: Pool]
    private let layout: DotWorldLayout
    private let fx: FXLayer
    private var clock: CGFloat = 0
    private var ground: CGFloat { CGFloat(DotWorldLayout.backdropHeight + 20) }

    /// The tint of the strongest weather now showing and how far in it is; 0 when clear.
    private(set) var tint: (color: SKColor, amount: CGFloat) = (.white, 0)

    init(layout: DotWorldLayout, fx: FXLayer) {
        self.layout = layout
        self.fx = fx
        var pools: [Weather: Pool] = [:]
        for kind in Weather.events { pools[kind] = Pool() }
        self.pools = pools
        super.init()
        zPosition = 4500
        let area = (layout.rightEdge - layout.leftEdge) * (layout.bottomEdge - layout.topEdge)
        fill(.rain, count: max(24, Int(area / 650)), seed: 11) { _ in dotSprite("dot_backdrop_raindrop", anchor: .pixel(0, 5)) }
        fill(.snow, count: max(20, Int(area / 900)), seed: 21) { i in
            i % 3 == 0 ? dotSprite("dot_backdrop_snow_l", anchor: .pixel(1, 1)) : dotSprite("dot_backdrop_snow_s", anchor: .pixel(1, 1))
        }
        fill(.leaves, count: max(10, Int(area / 1800)), seed: 31) { i in dotSprite("dot_backdrop_leaf_\(i % 3)", anchor: .pixel(2, 2)) }
        fill(.petals, count: max(16, Int(area / 1100)), seed: 41) { i in dotSprite("dot_backdrop_petal_\(i % 2)", anchor: .pixel(1, 1)) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func fill(_ kind: Weather, count: Int, seed: Int, sprite: (Int) -> SKSpriteNode) {
        guard let pool = pools[kind] else { return }
        pool.container.alpha = 0
        pool.container.isHidden = true
        addChild(pool.container)
        let width = layout.rightEdge - layout.leftEdge
        let height = layout.bottomEdge - layout.topEdge
        for i in 0..<count {
            let node = sprite(i)
            pool.container.addChild(node)
            let x = layout.leftEdge + CGFloat(dotHash(i, seed) % 1000) / 1000 * width
            let y = layout.topEdge + CGFloat(dotHash(i, seed + 1) % 1000) / 1000 * height
            let land = landRow(i, seed: seed + 2, minimum: y + 4)
            pool.particles.append(Particle(node: node, x: x, y: y, landY: land,
                                           phase: CGFloat(dotHash(i, seed + 3) % 628) / 100))
        }
    }

    private func landRow(_ i: Int, seed: Int, minimum: CGFloat) -> CGFloat {
        let span = layout.bottomEdge - ground
        return max(ground + CGFloat(dotHash(i, seed) % 1000) / 1000 * span, minimum)
    }

    func update(delta: TimeInterval, weather: Weather, animated: Bool) {
        let d = CGFloat(delta)
        clock += d
        var strongest: (Weather, CGFloat)?
        for kind in Weather.events {
            guard let pool = pools[kind] else { continue }
            let step = d * 1.2
            pool.amount += max(-step, min(step, (weather == kind ? 1 : 0) - pool.amount))
            pool.container.alpha = pool.amount
            pool.container.isHidden = pool.amount <= 0.001 || !animated
            if pool.amount > (strongest?.1 ?? 0.001) { strongest = (kind, pool.amount) }
            if !pool.container.isHidden { move(kind, pool, d) }
        }
        if let (kind, amount) = strongest, let hex = Self.tints[kind] {
            tint = (SKColor(hex: hex), amount)
        } else {
            tint = (.white, 0)
        }
    }

    private func move(_ kind: Weather, _ pool: Pool, _ d: CGFloat) {
        let width = layout.rightEdge - layout.leftEdge
        for i in pool.particles.indices {
            var p = pool.particles[i]
            switch kind {
            case .rain:
                p.y += 110 * d
                p.x -= 22 * d
            case .snow:
                p.y += (12 + CGFloat(i % 3) * 5) * d
                p.x += (sin(clock * 0.9 + p.phase) * 9 - 2) * d
            case .leaves:
                p.y += (14 + sin(clock * 2.4 + p.phase) * 9) * d
                p.x -= (26 + CGFloat(i % 3) * 7) * d
                p.node.xScale = sin(clock * 4.5 + p.phase) < 0 ? -1 : 1
            case .petals:
                p.y += (10 + CGFloat(i % 2) * 3) * d
                p.x += (sin(clock * 1.3 + p.phase) * 13 - 6) * d
            case .clear:
                break
            }
            if p.y >= p.landY {
                if kind == .rain, i % 3 == 0 { fx.rainSplash(at: feetPoint(p.x.rounded(), p.landY.rounded())) }
                p.y = layout.topEdge - CGFloat(dotHash(i, Int(p.landY)) % 30)
                p.landY = landRow(i, seed: Int(p.y) &+ 7, minimum: p.y + 4)
            }
            if p.x < layout.leftEdge { p.x += width } else if p.x > layout.rightEdge { p.x -= width }
            p.node.position = feetPoint(p.x.rounded(), p.y.rounded())
            pool.particles[i] = p
        }
    }
}
