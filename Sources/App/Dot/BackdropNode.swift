import SpriteKit
import UIKit

/// Sky fill, sun and moon, stars, clouds and the location skyline. Everything is positioned in
/// root space; the band itself spans art rows 0..<56 and the sky fill continues above it.
@MainActor
final class BackdropNode: SKNode {

    private let layout: DotWorldLayout
    private let skyFill = SKSpriteNode()
    private let sun = dotSprite("dot_backdrop_sun", anchor: .pixel(8, 8))
    private let moon = dotSprite("dot_backdrop_moon", anchor: .pixel(8, 8))
    private var stars: [(node: SKSpriteNode, phase: Double)] = []
    private var clouds: [(node: SKSpriteNode, speed: CGFloat, x: CGFloat)] = []
    private let skylineLayer = SKNode()
    private var elapsed: TimeInterval = 0

    init(layout: DotWorldLayout, locationTier: Int) {
        self.layout = layout
        super.init()
        let left = layout.leftEdge
        let width = layout.rightEdge - left
        skyFill.anchorPoint = CGPoint(x: 0, y: 1)
        skyFill.position = artPoint(left, layout.topEdge)
        skyFill.size = CGSize(width: width, height: CGFloat(DotWorldLayout.backdropHeight) - layout.topEdge)
        addChild(skyFill)

        buildStars(left: left, width: width)
        buildClouds(left: left, width: width)
        for body in [sun, moon] {
            body.zPosition = 3
            body.isHidden = true
            addChild(body)
        }
        skylineLayer.zPosition = 10
        addChild(skylineLayer)
        setLocation(tier: locationTier)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setLocation(tier: Int) {
        skylineLayer.removeAllChildren()
        let name = ["dot_backdrop_alley", "dot_backdrop_market", "dot_backdrop_gangnam"][min(max(tier, 0), 2)]
        let tile = CGFloat(DotWorldLayout.width)
        var x = (layout.leftEdge / tile).rounded(.down) * tile
        while x < layout.rightEdge {
            let sprite = dotSprite(name, anchor: .bottomLeft)
            sprite.position = artPoint(x, CGFloat(DotWorldLayout.backdropHeight))
            skylineLayer.addChild(sprite)
            x += tile
        }
    }

    private func buildStars(left: CGFloat, width: CGFloat) {
        let top = layout.topEdge
        let usable = CGFloat(30) - top
        for i in 0..<28 {
            let star = dotSprite("dot_backdrop_star", anchor: .pixel(1, 1))
            let x = left + CGFloat(dotHash(i, 1) % 1000) / 1000 * width
            let y = top + CGFloat(dotHash(i, 2) % 1000) / 1000 * usable
            star.position = feetPoint(x.rounded(), y.rounded())
            star.zPosition = 1
            star.alpha = 0
            addChild(star)
            stars.append((star, Double(dotHash(i, 3) % 100) / 100 * .pi * 2))
        }
    }

    private func buildClouds(left: CGFloat, width: CGFloat) {
        let rows: [CGFloat] = [8, 20, 31]
        for (i, row) in rows.enumerated() {
            let cloud = dotSprite("dot_backdrop_cloud_\(i % 2)", anchor: .pixel(16, 6))
            cloud.zPosition = 2
            cloud.alpha = 0.95
            addChild(cloud)
            let x = left + width * CGFloat(i) / CGFloat(rows.count) + 20
            clouds.append((cloud, 1.2 + CGFloat(i) * 0.5, x))
            cloud.position = feetPoint(x.rounded(), row)
        }
        cloudRows = rows
    }
    private var cloudRows: [CGFloat] = []

    func update(delta: TimeInterval, progress: Double, look: DayLook, reduceMotion: Bool) {
        elapsed += delta
        skyFill.color = look.sky

        let nightAlpha = DayLook.starAlpha(progress: progress)
        for star in stars {
            let blink = reduceMotion ? 1 : (0.55 + 0.45 * sin(elapsed * 2.2 + star.phase))
            star.node.alpha = nightAlpha * CGFloat(blink)
        }

        placeBody(sun, arc: DayLook.sunArc(progress: progress))
        placeBody(moon, arc: DayLook.moonArc(progress: progress))

        let left = layout.leftEdge
        let right = layout.rightEdge
        for i in clouds.indices where !reduceMotion {
            clouds[i].x -= clouds[i].speed * CGFloat(delta)
            if clouds[i].x < left - 20 { clouds[i].x = right + 20 }
            clouds[i].node.position = feetPoint(clouds[i].x.rounded(), cloudRows[i])
        }
    }

    private func placeBody(_ body: SKSpriteNode, arc: CGFloat?) {
        guard let t = arc else { body.isHidden = true; return }
        body.isHidden = false
        let x = 14 + t * CGFloat(DotWorldLayout.width - 28)
        let y = 38 - sin(t * .pi) * 20
        body.position = feetPoint(x.rounded(), y.rounded())
    }
}
