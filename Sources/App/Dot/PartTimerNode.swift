import SpriteKit

/// The 전단지 알바: stands at the right end of the street, where customers come in from, waving a flyer for as long as the shift runs.
@MainActor
final class PartTimerNode: SKNode {
    private static let x: CGFloat = 136
    /// Behind the queue row (25) so a queued customer stands in front of the hire, not under it.
    private static let row: CGFloat = 23
    private let sprite = dotSprite("dot_char_flyer_alba_work_0")
    private var isOn = false

    override init() {
        super.init()
        position = feetPoint(Self.x, Self.row)
        zPosition = Self.row / 100
        addChild(sprite)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setActive(_ active: Bool, animated: Bool) {
        guard active != isOn else { return }
        isOn = active
        isHidden = !active
        sprite.removeAction(forKey: "wave")
        guard active else { return }
        let frames = DotTexture.frames("dot_char_flyer_alba_work", count: 2)
        sprite.texture = frames[0]
        if animated {
            sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.3, resize: false, restore: false)),
                       withKey: "wave")
        }
    }
}
