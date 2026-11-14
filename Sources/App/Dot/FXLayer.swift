import SpriteKit
import UIKit

/// Short-lived effects: puffs, hearts, flying coins and cabbages, floating "+N". Sits above the
/// day tint so labels and coins are never darkened. All positions are root space.
@MainActor
final class FXLayer: SKNode {

    private let scale: CGFloat
    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notifier = UINotificationFeedbackGenerator()

    init(scale: CGFloat) {
        self.scale = scale
        super.init()
        zPosition = 6000
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func lightHaptic() { impact.impactOccurred() }
    func successHaptic() { notifier.notificationOccurred(.success) }

    func puff(at point: CGPoint) {
        play(frames: "dot_fx_puff", count: 3, anchor: .pixel(6, 9), at: point, perFrame: 0.08)
    }

    func sparkle(at point: CGPoint) {
        play(frames: "dot_fx_sparkle", count: 4, anchor: .pixel(3, 3), at: point, perFrame: 0.09)
    }

    func rainSplash(at point: CGPoint) {
        play(frames: "dot_backdrop_rain_splash", count: 2, anchor: .pixel(3, 3), at: point, perFrame: 0.08)
    }

    private func play(frames base: String, count: Int, anchor: DotAnchor, at point: CGPoint, perFrame: TimeInterval) {
        let sprite = dotSprite("\(base)_0", anchor: anchor)
        sprite.position = snapped(point)
        addChild(sprite)
        sprite.run(.sequence([.animate(with: DotTexture.frames(base, count: count), timePerFrame: perFrame,
                                       resize: false, restore: false), .removeFromParent()]))
    }

    func sparkleBurst(at point: CGPoint, count: Int = 8, radius: CGFloat = 16) {
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            let target = CGPoint(x: point.x + cos(angle) * radius, y: point.y + sin(angle) * radius)
            let sprite = dotSprite("dot_fx_sparkle_0", anchor: .pixel(3, 3))
            sprite.position = snapped(point)
            addChild(sprite)
            let frames = SKAction.animate(with: DotTexture.frames("dot_fx_sparkle", count: 4),
                                          timePerFrame: 0.1, resize: false, restore: false)
            let move = SKAction.move(to: snapped(target), duration: 0.4)
            move.timingMode = .easeOut
            sprite.run(.sequence([.group([frames, move]), .removeFromParent()]))
        }
    }

    /// Heart or anger mark rising over a customer's head.
    func reaction(_ name: String, at point: CGPoint) {
        let sprite = dotSprite(name, anchor: .pixel(3, 3))
        sprite.position = snapped(point)
        addChild(sprite)
        let rise: CGFloat = reduceMotion ? 0 : 6
        sprite.run(.sequence([
            .group([.moveBy(x: 0, y: rise, duration: 0.7), .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.25)])]),
            .removeFromParent(),
        ]))
    }

    /// Floating label; `bold` is the larger pop used for money. `big` doubles it (whole art pixels,
    /// so glyphs stay on the grid) for fever sales and the fever summary.
    func pop(_ text: String, at point: CGPoint, color: SKColor, bold: Bool = true, rise: CGFloat = 14,
             big: Bool = false, hold: TimeInterval = 0) {
        let label = PixelLabel(style: bold ? .bold : .small, scale: scale, color: color)
        label.text = text
        label.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        label.zPosition = 10
        if big {
            label.setScale(2)
            // A doubled "+3,750" is ~80 art px wide: keep it inside the 144 px column instead of off the screen edge.
            let half = CGFloat(text.count) * 7
            label.position.x = min(max(label.position.x, half), 144 - half)
        }
        addChild(label)
        let lift: CGFloat = reduceMotion ? 0 : rise
        label.run(.sequence([
            .group([.moveBy(x: 0, y: lift, duration: 0.9 + hold),
                    .sequence([.wait(forDuration: 0.55 + hold), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent(),
        ]))
    }

    /// Coins arc from `start` to `end`; `completion` fires when the last one lands.
    func flyCoins(from start: CGPoint, to end: CGPoint, count: Int, completion: (() -> Void)? = nil) {
        guard !reduceMotion else { completion?(); return }
        for i in 0..<count {
            let coin = dotSprite("dot_fx_coin_0", anchor: .pixel(4, 4))
            coin.position = snapped(start)
            coin.alpha = 0
            addChild(coin)
            let spin = SKAction.repeatForever(.animate(with: DotTexture.frames("dot_fx_coin", count: 4),
                                                       timePerFrame: 0.08, resize: false, restore: false))
            coin.run(spin)
            let jitter = CGFloat(i - count / 2) * 5
            let isLast = i == count - 1
            coin.run(.sequence([
                .wait(forDuration: Double(i) * 0.07),
                .fadeIn(withDuration: 0),
                arc(from: start, to: end, lift: 26 + jitter, duration: 0.75),
                .run { if isLast { completion?() } },
                .removeFromParent(),
            ]))
        }
    }

    /// One icon arcing to a target, e.g. a cabbage into the crate.
    func flyItem(_ name: String, from start: CGPoint, to end: CGPoint, lift: CGFloat = 18,
                 duration: TimeInterval = 0.45, completion: @escaping () -> Void) {
        guard !reduceMotion else { completion(); return }
        let item = dotSprite(name, anchor: .pixel(6, 6))
        item.position = snapped(start)
        addChild(item)
        item.run(.sequence([arc(from: start, to: end, lift: lift, duration: duration),
                            .run(completion), .removeFromParent()]))
    }

    private func arc(from start: CGPoint, to end: CGPoint, lift: CGFloat, duration: TimeInterval) -> SKAction {
        .customAction(withDuration: duration) { [weak self] node, elapsed in
            guard let self else { return }
            let t = min(1, CGFloat(elapsed) / CGFloat(duration))
            let eased = t * t * (3 - 2 * t)
            let x = start.x + (end.x - start.x) * eased
            let y = start.y + (end.y - start.y) * eased + sin(t * .pi) * lift
            node.position = self.snapped(CGPoint(x: x, y: y))
        }
    }

    /// Sprites are positioned on whole art pixels (`.pixel` anchors add the half-pixel themselves).
    private func snapped(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x.rounded(.down) + 0.5, y: p.y.rounded())
    }

    /// Quick squash-and-stretch about the sprite's own anchor; reduced to nothing under Reduce Motion.
    static func squash(_ node: SKNode, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        node.removeAction(forKey: "squash")
        node.run(.sequence([
            .scaleX(to: 1.125, y: 0.875, duration: 0.06),
            .scaleX(to: 0.9375, y: 1.0625, duration: 0.07),
            .scaleX(to: 1, y: 1, duration: 0.06),
        ]), withKey: "squash")
    }

    static func shake(_ node: SKNode, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        node.removeAction(forKey: "shake")
        // Rest position is remembered once: a shake cut short by another would otherwise leave the node off-centre.
        let x = (node.userData?["restX"] as? CGFloat) ?? node.position.x
        if node.userData == nil { node.userData = [:] }
        node.userData?["restX"] = x
        node.position.x = x
        node.run(.sequence([
            .moveTo(x: x - 2, duration: 0.04), .moveTo(x: x + 2, duration: 0.04),
            .moveTo(x: x - 2, duration: 0.04), .moveTo(x: x, duration: 0.04),
        ]), withKey: "shake")
    }
}
