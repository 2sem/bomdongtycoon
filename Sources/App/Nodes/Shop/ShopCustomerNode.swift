import SpriteKit

/// One pose's isorender measurement table entry (px, trimmed, 3x render):
/// native size and the feet anchor as a fraction from the *bottom* — the
/// same convention `ShopPropSpriteNode` already takes its `baseAnchor` in,
/// so no top/bottom flip is needed here unlike `ShopNode.TableItemSpec`.
/// Numbers are the chibi cast's table from art PR #120; kid (0.70) and
/// elder (0.933) scale is baked into the PNGs, so nothing scales them here.
private struct CustomerPoseSpec {
    let imageName: String
    let nativeSize: CGSize
    let anchorPoint: CGPoint
}

/// One archetype's idle/walk pair, plus the archetype's own head height.
private struct CustomerArchetypeSpec {
    let idle: CustomerPoseSpec
    let walk: CustomerPoseSpec

    /// Native px from the feet anchor to the top of the head. The chibi
    /// sprites are trimmed to the head's top edge, so this is simply
    /// `height x (1 - anchorY)`; idle and walk agree to within 0.1px
    /// (adult 138.6), so the bubble does not hop as the textures swap.
    let headHeightAboveFeet: CGFloat

    init(idle: CustomerPoseSpec, walk: CustomerPoseSpec) {
        self.idle = idle
        self.walk = walk
        headHeightAboveFeet = idle.nativeSize.height * (1 - idle.anchorPoint.y)
    }
}

/// The three sprite archetypes rendered for this cast — no face, so the
/// same sprite serves a customer walking in and walking back out.
enum CustomerArchetype: CaseIterable {
    case adult, kid, elder

    fileprivate var spec: CustomerArchetypeSpec {
        switch self {
        case .adult:
            return CustomerArchetypeSpec(
                idle: CustomerPoseSpec(imageName: "customer_adult_idle", nativeSize: CGSize(width: 83, height: 150), anchorPoint: CGPoint(x: 0.5, y: 0.07573)),
                walk: CustomerPoseSpec(imageName: "customer_adult_walk", nativeSize: CGSize(width: 83, height: 159), anchorPoint: CGPoint(x: 0.5, y: 0.12805)),
            )
        case .kid:
            return CustomerArchetypeSpec(
                idle: CustomerPoseSpec(imageName: "customer_kid_idle", nativeSize: CGSize(width: 63, height: 110), anchorPoint: CGPoint(x: 0.5, y: 0.07545)),
                walk: CustomerPoseSpec(imageName: "customer_kid_walk", nativeSize: CGSize(width: 63, height: 116), anchorPoint: CGPoint(x: 0.5, y: 0.12328))
            )
        case .elder:
            return CustomerArchetypeSpec(
                idle: CustomerPoseSpec(imageName: "customer_elder_idle", nativeSize: CGSize(width: 83, height: 143), anchorPoint: CGPoint(x: 0.5, y: 0.07406)),
                walk: CustomerPoseSpec(imageName: "customer_elder_walk", nativeSize: CGSize(width: 83, height: 151), anchorPoint: CGPoint(x: 0.5, y: 0.12311))
            )
        }
    }
}

/// A customer figure that walks to the shop counter, wants one menu item
/// (shown as an icon in its thought bubble), and pops a happy/sad reaction
/// once served or given up on. `ShopCustomerSpawner` owns spawning, the
/// walk path and the serve/wait decision; this node only knows how to draw
/// and animate itself at whatever position/zPosition it's told to hold.
final class ShopCustomerNode: SKNode {

    /// Menu glyph shown in the thought bubble, indexed the same as
    /// `UpgradeDefinitions.menu` / `ShopNode`'s bowl slots (겉절이/봄동김치/
    /// 봄동비빔밥) and mapped to art via `EmojiArt`.
    private static let menuGlyphs = ["🥬", "🥗", "🥘"]

    let wantedMenuIndex: Int

    /// Points above `position` the thought bubble/reaction sit — exposed
    /// so `ShopCustomerSpawner` can seat a coin pop at the same height
    /// without duplicating the head-height math below.
    var headTopWorldOffset: CGFloat { thoughtBubble.position.y }

    private let archetype: CustomerArchetypeSpec
    private let grid: IsoGrid
    private let figure = SKSpriteNode()

    private let thoughtBubble = SKNode()
    private let bubbleCircle: SKShapeNode
    private let reactionSprite = SKSpriteNode()

    private static let bubbleRadius: CGFloat = 14
    /// Extra clearance above the head before the bubble's own centre, so
    /// its circle doesn't touch the scalp.
    private static let bubbleHeadClearance: CGFloat = 6

    init(archetype: CustomerArchetype, wantedMenuIndex: Int, fittingTo grid: IsoGrid) {
        self.archetype = archetype.spec
        self.wantedMenuIndex = wantedMenuIndex
        self.grid = grid
        bubbleCircle = SKShapeNode(circleOfRadius: Self.bubbleRadius)
        super.init()

        addChild(figure)
        applyPose(self.archetype.idle)

        buildThoughtBubble()
        reactionSprite.position = thoughtBubble.position
        reactionSprite.alpha = 0
        addChild(reactionSprite)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopCustomerNode")
    }

    /// Swaps `figure`'s texture, size and anchor together — swapping only
    /// the texture would leave idle's anchor fraction applied to walk's
    /// (taller) frame, sinking or lifting the feet off the ground at every
    /// pose change instead of keeping them planted at `position`.
    private func applyPose(_ pose: CustomerPoseSpec) {
        figure.texture = SKTexture(imageNamed: pose.imageName)
        let width = pose.nativeSize.width * ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        figure.size = CGSize(width: width, height: width * (pose.nativeSize.height / pose.nativeSize.width))
        figure.anchorPoint = pose.anchorPoint
    }

    private func buildThoughtBubble() {
        let headHeight = archetype.headHeightAboveFeet * ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        thoughtBubble.position = CGPoint(x: 0, y: headHeight + Self.bubbleHeadClearance + Self.bubbleRadius)

        bubbleCircle.fillColor = SKColor.white.withAlphaComponent(0.92)
        bubbleCircle.strokeColor = SKColor(red: 0.65, green: 0.85, blue: 0.65, alpha: 1)
        bubbleCircle.lineWidth = 1.5
        thoughtBubble.addChild(bubbleCircle)

        let glyph = Self.menuGlyphs[safe: wantedMenuIndex] ?? Self.menuGlyphs[0]
        let icon = EmojiArt.sprite(for: glyph, size: CGSize(width: 18, height: 18))
        thoughtBubble.addChild(icon)

        addChild(thoughtBubble)

        thoughtBubble.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 3, duration: 0.55),
            .moveBy(x: 0, y: -3, duration: 0.55),
        ])), withKey: "bob")
    }

    // MARK: - Animation

    private static let strideInterval: TimeInterval = 0.25

    /// Alternates idle/walk textures every `strideInterval` for a simple
    /// two-frame gait, since neither pose has its own walk-cycle frames.
    func startWalking() {
        guard action(forKey: "stride") == nil else { return }
        let walkPose = archetype.walk
        let idlePose = archetype.idle
        run(.repeatForever(.sequence([
            .run { [weak self] in self?.applyPose(walkPose) },
            .wait(forDuration: Self.strideInterval),
            .run { [weak self] in self?.applyPose(idlePose) },
            .wait(forDuration: Self.strideInterval),
        ])), withKey: "stride")
    }

    func stopWalking() {
        removeAction(forKey: "stride")
        applyPose(archetype.idle)
    }

    /// Small impatient shuffle while waiting for stock at the counter.
    func startWaitingShuffle() {
        run(.repeatForever(.sequence([
            .moveBy(x: 4, y: 0, duration: 0.35),
            .moveBy(x: -4, y: 0, duration: 0.35),
        ])), withKey: "waiting")
    }

    func stopWaitingShuffle() {
        removeAction(forKey: "waiting")
    }

    /// Bursts the thought bubble and pops a happy/sad reaction above the
    /// head, mirroring the pre-rebuild `CustomerNode`'s reaction beat.
    func showReaction(happy: Bool) {
        thoughtBubble.removeAllActions()
        let burstColor: SKColor = happy
            ? SKColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)
            : SKColor(red: 0.90, green: 0.20, blue: 0.15, alpha: 1)
        bubbleCircle.fillColor = burstColor
        thoughtBubble.run(.sequence([
            .scale(to: 1.3, duration: 0.10),
            .fadeOut(withDuration: 0.20),
        ]))

        reactionSprite.texture = SKTexture(imageNamed: happy ? "reaction_happy" : "reaction_sad")
        reactionSprite.size = CGSize(width: 24, height: 24)
        reactionSprite.alpha = 1
        reactionSprite.setScale(0.4)
        reactionSprite.run(.sequence([
            .group([.scale(to: 1.3, duration: 0.12), .moveBy(x: 0, y: 8, duration: 0.12)]),
            .scale(to: 1.0, duration: 0.08),
            .wait(forDuration: 0.5),
            .group([.moveBy(x: 0, y: 22, duration: 0.55), .fadeOut(withDuration: 0.55)]),
        ]))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
