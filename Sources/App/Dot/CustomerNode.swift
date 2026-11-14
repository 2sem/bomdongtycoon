import SpriteKit

/// One customer: sprite, ground shadow and an order bubble. Poses come from the manifest's
/// `idle_down` / `walk_{down,side,up}` frames; `walk_side` faces left and is flipped for right.
@MainActor
final class CustomerNode: SKNode {

    enum Facing { case up, down, left, right }

    let look: String
    private let body: SKSpriteNode
    private let bubble = SKNode()
    private var frameClock: TimeInterval = 0
    private var currentKey = ""

    init(look: String, wantedDish: String) {
        self.look = look
        body = dotSprite("dot_char_\(look)_idle_down")
        super.init()
        let shadow = dotSprite("dot_fx_shadow", anchor: .pixel(6, 2))
        shadow.alpha = 0.25
        shadow.position = CGPoint(x: 0, y: 1)
        addChild(shadow)
        addChild(body)

        // Bubble tail tip is 24 px above the feet, just over the hair; the dish sits at bubble px (3, 2).
        bubble.position = CGPoint(x: 0, y: 24)
        bubble.zPosition = 50
        bubble.addChild(dotSprite("dot_fx_bubble", anchor: .pixel(10, 21)))
        let dish = dotSprite(wantedDish)
        dish.position = CGPoint(x: 1, y: 4)
        dish.zPosition = 0.1
        bubble.addChild(dish)
        bubble.isHidden = true
        addChild(bubble)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setBubbleVisible(_ visible: Bool) { bubble.isHidden = !visible }

    /// Faces the viewer, standing still.
    func showFront() { setTexture("dot_char_\(look)_idle_down", flip: false) }

    /// Standing with their back to the viewer, facing the counter.
    func showBack() { setTexture("dot_char_\(look)_walk_up_0", flip: false) }

    func walk(facing: Facing, delta: TimeInterval) {
        frameClock += delta
        let frame = Int(frameClock / 0.18) % 2
        switch facing {
        case .up:    setTexture("dot_char_\(look)_walk_up_\(frame)", flip: false)
        case .down:  setTexture("dot_char_\(look)_walk_down_\(frame)", flip: false)
        case .left:  setTexture("dot_char_\(look)_walk_side_\(frame)", flip: false)
        case .right: setTexture("dot_char_\(look)_walk_side_\(frame)", flip: true)
        }
    }

    private func setTexture(_ name: String, flip: Bool) {
        let key = name + (flip ? "|f" : "")
        guard key != currentKey else { return }
        currentKey = key
        body.texture = DotTexture.named(name)
        body.xScale = flip ? -1 : 1
    }
}
