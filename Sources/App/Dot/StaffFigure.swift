import SpriteKit

/// A cook, cashier or farm worker: idle bob, a two-frame `work` loop, a `tired` pose with zzz.
@MainActor
final class StaffFigure: SKNode {

    enum Pose: Equatable { case idle, work, tired }

    private let bob = SKNode()
    private let sprite = dotSprite("dot_char_alba_idle_down")
    private let zzz = dotSprite("dot_fx_zzz", anchor: .pixel(0, 7))
    private var kind = ""
    private var pose: Pose?

    override init() {
        super.init()
        addChild(bob)
        bob.addChild(sprite)
        zzz.position = CGPoint(x: 5, y: 24)
        zzz.isHidden = true
        bob.addChild(zzz)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// `kind` is the sprite family (`alba`, `imo`, `chef`, `farmer`, `veteran_alba`); nil hides the figure.
    func configure(kind: String?, pose: Pose, isTired: Bool, bobs: Bool, fast: Bool) {
        guard let kind else { isHidden = true; return }
        isHidden = false
        if kind != self.kind || pose != self.pose {
            self.kind = kind
            self.pose = pose
            sprite.removeAction(forKey: "work")
            switch pose {
            case .idle:
                sprite.texture = DotTexture.named("dot_char_\(kind)_idle_down")
            case .tired:
                sprite.texture = DotTexture.named("dot_char_\(kind)_tired")
            case .work:
                let frames = DotTexture.frames("dot_char_\(kind)_work", count: 2)
                sprite.texture = frames[0]
                sprite.run(.repeatForever(.animate(with: frames, timePerFrame: 0.3, resize: false, restore: false)),
                           withKey: "work")
            }
        }
        zzz.isHidden = !isTired
        updateBob(enabled: bobs && pose != .work, fast: fast)
    }

    private func updateBob(enabled: Bool, fast: Bool) {
        if !enabled {
            bob.removeAction(forKey: "bob")
            bob.position = .zero
            return
        }
        if bob.action(forKey: "bob") == nil {
            let step = SKAction.sequence([.moveBy(x: 0, y: 1, duration: 0), .wait(forDuration: 0.55),
                                          .moveBy(x: 0, y: -1, duration: 0), .wait(forDuration: 0.55)])
            bob.run(.sequence([.wait(forDuration: Double.random(in: 0...0.5)), .repeatForever(step)]), withKey: "bob")
        }
        bob.speed = fast ? 2 : 1
    }
}
