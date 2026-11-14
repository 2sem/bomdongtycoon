import SpriteKit
import UIKit
import GameCore

extension Notification.Name {
    /// Posted once a location purchase's transition has faded back in; `userInfo["tier"]` is the new `Int` tier.
    static let locationTransitionDidFinish = Notification.Name("locationTransitionDidFinish")
    /// Posted when the add-plot sign is tapped; `AddFarmPlotConfirmation` owns the alert and purchase.
    static let requestAddFarmPlot = Notification.Name("requestAddFarmPlot")
    /// Posted when the warehouse crate is tapped; `ExpandWarehouseConfirmation` owns the alert and purchase.
    static let requestExpandWarehouse = Notification.Name("requestExpandWarehouse")
}

/// The whole game scene as 2D pixel art. One root node is scaled by `layout.scale` points per
/// art pixel; everything inside sits on whole art pixels. Bands top to bottom: backdrop, shop,
/// street, yard, farm, grass.
@MainActor
final class DotWorldScene: SKScene {

    weak var store: GameStore? {
        didSet {
            guard let store, oldValue == nil else { return }
            DotDebug.seed(store)
            needsLayout = true
        }
    }

    /// Height covered by the SwiftUI HUD; sky and backdrop continue under it.
    var topInset: CGFloat = 0 { didSet { if oldValue != topInset { needsLayout = true } } }
    /// Height covered by the tab bar and home indicator.
    var bottomInset: CGFloat = 0 { didSet { if oldValue != bottomInset { needsLayout = true } } }
    /// Where flying coins land, in view points from the top-left; defaults to the HUD coin badge.
    var coinTarget = CGPoint(x: 56, y: 84)

    var isSoundEnabled: Bool {
        get { DotSound.shared.isEnabled }
        set { DotSound.shared.isEnabled = newValue }
    }

    private let sound = DotSound.shared
    private let root = SKNode()
    private let veil = SKSpriteNode(color: SKColor(hex: 0x2b1b2e), size: .zero)

    private var layout: DotWorldLayout?
    private var needsLayout = true
    private var lastUpdate: TimeInterval = 0

    private var backdrop: BackdropNode?
    private var groundNode: SKSpriteNode?
    private var shop: ShopNode?
    private var yard: YardNode?
    private var farm: FarmNode?
    private var director: CustomerDirector?
    private var fx: FXLayer?
    private var rain: RainNode?
    private var tint: SKSpriteNode?
    private var feverGlow: SKSpriteNode?
    private var hintArrow: HintArrowNode?
    private var lastDishFeedback: [Int: TimeInterval] = [:]

    private var appliedLocation: Int?
    private var lastPrestige: Int?
    private var isRunTransitionActive = false
    private var wasRaining = false
    private var wasFever = false
    private var feverAmount: CGFloat = 0
    private var feverClock: TimeInterval = 0
    private var sparkleClock: TimeInterval = 0
    private var tapClassifier = TapClassifier()
    private var demoClock: TimeInterval = 4
    private var demoStep = 0

    private var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = SKColor(hex: 0x62a652)
        addChild(root)
        veil.zPosition = 10_000
        veil.alpha = 0
        addChild(veil)
        view.isMultipleTouchEnabled = false
        needsLayout = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        needsLayout = true
    }

    // MARK: Build

    private func rebuildWorld() {
        needsLayout = false
        guard size.width > 0, size.height > 0 else { return }
        let scaleFactor = view?.window?.screen.scale ?? UIScreen.main.scale
        let layout = DotWorldLayout(viewSize: size, topInset: topInset, bottomInset: bottomInset, screenScale: scaleFactor)
        self.layout = layout
        veil.size = size
        veil.position = CGPoint(x: size.width / 2, y: size.height / 2)

        root.removeAllChildren()
        root.setScale(layout.scale)
        root.position = layout.origin

        let tier = store?.stall.locationTier ?? 0
        appliedLocation = tier

        let fx = FXLayer(scale: layout.scale)
        let backdrop = BackdropNode(layout: layout, locationTier: tier)
        let ground = GroundBaker.makeNode(layout: layout, locationTier: tier)
        ground.zPosition = 20
        let labels = SKNode()
        labels.zPosition = 5050
        let shop = ShopNode(layout: layout, labelLayer: labels)
        let street = StreetNode(layout: layout)
        let yard = YardNode(layout: layout, labelLayer: labels)
        let farm = FarmNode(layout: layout)
        let decor = GrassDecorNode(layout: layout)
        let director = CustomerDirector(street: street, layout: layout)
        director.onServed = { [weak self] in self?.customerServed($0) }
        director.onFailed = { [weak self] point in
            self?.fx?.reaction("dot_fx_anger", at: point)
            self?.sound.play(.error)
        }
        director.onSparkle = { [weak self] point in self?.fx?.sparkle(at: point) }
        let rain = RainNode(layout: layout, fx: fx)

        let width = layout.rightEdge - layout.leftEdge
        let height = layout.bottomEdge - layout.topEdge
        let centre = artPoint((layout.leftEdge + layout.rightEdge) / 2, (layout.topEdge + layout.bottomEdge) / 2)
        let tint = SKSpriteNode(color: .white, size: CGSize(width: width + 4, height: height + 4))
        tint.blendMode = .multiply
        tint.position = centre
        tint.zPosition = 5000
        let glow = SKSpriteNode(color: SKColor(hex: 0xff9a3c), size: tint.size)
        glow.position = centre
        glow.zPosition = 5001
        glow.alpha = 0

        let hint = HintArrowNode()
        hint.zPosition = 5900
        for node in [backdrop, ground, shop, street, yard, farm, decor, rain, tint, glow, labels, hint, fx] as [SKNode] { root.addChild(node) }
        hintArrow = hint
        self.fx = fx; self.backdrop = backdrop; groundNode = ground; self.shop = shop
        self.yard = yard; self.farm = farm; self.director = director; self.rain = rain
        self.tint = tint; feverGlow = glow
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 3.0)
        lastUpdate = currentTime
        if needsLayout, store != nil { rebuildWorld() }
        guard let store, layout != nil else { return }

        if let count = Optional(store.progress.prestigeCount) {
            if let last = lastPrestige, count != last { runNewRunTransition() }
            lastPrestige = count
        }
        guard !isRunTransitionActive else { return }

        DotDebug.keepAlive(store)
        demo(delta: delta, store: store)
        store.tick(deltaTime: delta)
        director?.update(delta: delta, store: store, isFever: store.isFeverActive, reduceMotion: reduceMotion)
        checkLocation(store.stall.locationTier)
        applyState(store, delta: delta)
    }

    /// `-dotDemo`: taps something every few seconds so effects can be reviewed without a finger.
    private func demo(delta: TimeInterval, store: GameStore) {
        #if DEBUG
        guard DotDebug.wantsDemo else { return }
        demoClock -= delta
        guard demoClock <= 0 else { return }
        demoClock = 2.5
        defer { demoStep += 1 }
        switch demoStep % 3 {
        case 0:
            if let i = store.farm.plots.firstIndex(where: { $0.stage == .ready && $0.isGolden })
                ?? store.farm.plots.firstIndex(where: { $0.stage == .ready }) { handleFarmTap(.plot(i), store: store) }
        case 1:
            if let i = store.farm.plots.firstIndex(where: { $0.stage == .empty }) { handleFarmTap(.plot(i), store: store) }
        default:
            handleDishTap(0, store: store)
        }
        #endif
    }

    private func applyState(_ store: GameStore, delta: TimeInterval) {
        guard let backdrop, let shop, let yard, let farm, let rain, let tint, let feverGlow, let fx else { return }
        let reduce = reduceMotion
        let progress = DotDebug.dayProgress ?? DayCycle.progress(playSeconds: store.progress.totalPlaySeconds)
        let look = DayLook.at(progress: progress)
        backdrop.update(delta: delta, progress: progress, look: look, reduceMotion: reduce)

        let raining = store.weather == .rain
        if raining, !wasRaining { sound.play(.rainStart) }
        wasRaining = raining
        rain.update(delta: delta, isRaining: raining, animated: !reduce)
        let drizzle = SKColor(hex: 0xb4bfd6)
        tint.color = look.tint.mixed(with: look.tint.multiplied(by: drizzle), rain.amount)

        let fever = store.isFeverActive
        if fever, !wasFever { sound.play(.feverStart) }
        wasFever = fever
        feverClock += delta
        let target: CGFloat = fever ? 1 : 0
        feverAmount += max(-CGFloat(delta) * 2, min(CGFloat(delta) * 2, target - feverAmount))
        let pulse = reduce ? 0.12 : 0.10 + 0.07 * CGFloat(sin(feverClock * 7))
        feverGlow.alpha = feverAmount * pulse
        if fever, !reduce { partyEffects(delta: delta, fx: fx) }

        for menu in shop.apply(store: store, reduceMotion: reduce) {
            fx.puff(at: shop.dishPoint(menu))
            sound.play(.cookDone)
        }
        yard.apply(count: store.stall.warehouse, capacity: store.stall.warehouseCapacity)
        let starved = isWarehouseStarved(store)
        yard.setAlert(starved, reduceMotion: reduce)
        farm.apply(farm: store.farm, canAddPlot: canAddPlot(store), pulseRipe: starved, reduceMotion: reduce)
        updateHint(store, shop: shop, farm: farm)
    }

    /// Nothing to cook with while a dish the player could sell is out of stock.
    private func isWarehouseStarved(_ store: GameStore) -> Bool {
        store.stall.warehouse == 0
            && (0...min(store.stall.menuTier, 2)).contains { store.stall.menuStock[$0] == 0 }
    }

    // MARK: First-run pointer

    /// One pointer at a time: harvest, then plant, then cook; only once both intro overlays are gone.
    private func updateHint(_ store: GameStore, shop: ShopNode, farm: FarmNode) {
        guard let arrow = hintArrow else { return }
        var tip: CGPoint?
        if !store.progress.isFirstLaunch, store.progress.isShopNameSet, !isRunTransitionActive {
            let plots = store.farm.plots
            if !FirstRunHint.harvest.isDone, let i = plots.firstIndex(where: \.isReady) {
                tip = farm.hintTip(i)
            } else if !FirstRunHint.plant.isDone,
                      let i = plots.firstIndex(where: { $0.stage == .empty && $0.workerType == .none })
                        ?? plots.firstIndex(where: { $0.stage == .empty }) {
                tip = farm.hintTip(i)
            } else if !FirstRunHint.cook.isDone, store.stall.warehouse > 0, store.stall.menuStock[0] == 0,
                      !store.isCooking(menuIndex: 0) {
                tip = shop.hintTip(0)
            }
        }
        arrow.show(tip: tip, animated: !reduceMotion)
    }

    private func partyEffects(delta: TimeInterval, fx: FXLayer) {
        guard let layout else { return }
        sparkleClock -= delta
        guard sparkleClock <= 0 else { return }
        sparkleClock = 0.18
        let x = CGFloat.random(in: 4...140)
        let y = CGFloat(layout.shopTop) + CGFloat.random(in: 10...100)
        fx.sparkle(at: feetPoint(x.rounded(), y.rounded()))
    }

    private func canAddPlot(_ store: GameStore) -> Bool {
        FarmSystem.costForNextPlot(currentCount: store.farm.plots.count) != nil
    }

    // MARK: Customers

    private func customerServed(_ event: CustomerDirector.ServeEvent) {
        guard let fx, let shop, let layout else { return }
        fx.reaction("dot_fx_heart", at: event.headPoint)
        // Low and short-lived: higher, a fever pop climbs over the counter's padlocks.
        fx.pop("+\(CoinFormat.string(event.price))", at: CGPoint(x: event.headPoint.x, y: event.headPoint.y - 2),
               color: SKColor(hex: event.isGourmet ? 0xffe680 : 0xf4b93a), rise: 6)
        fx.flyCoins(from: shop.tillRootPoint, to: layout.rootPoint(fromScene: coinTargetScenePoint),
                    count: event.isGourmet ? 6 : 3)
        sound.play(.coin)
    }

    private var coinTargetScenePoint: CGPoint { CGPoint(x: coinTarget.x, y: size.height - coinTarget.y) }

    // MARK: Transitions

    private func checkLocation(_ tier: Int) {
        guard let appliedLocation, tier != appliedLocation else { return }
        self.appliedLocation = tier
        director?.isSpawningPaused = true
        let fadeOut = reduceMotion ? 0.1 : 0.35
        let fadeIn = reduceMotion ? 0.1 : 0.45
        let out = SKAction.fadeAlpha(to: 1, duration: fadeOut)
        out.timingMode = .easeIn
        let swap = SKAction.run { [weak self] in
            guard let self, let layout = self.layout else { return }
            self.backdrop?.setLocation(tier: tier)
            self.groundNode?.removeFromParent()
            let ground = GroundBaker.makeNode(layout: layout, locationTier: tier)
            ground.zPosition = 20
            self.root.addChild(ground)
            self.groundNode = ground
            self.director?.reset()
        }
        let back = SKAction.fadeAlpha(to: 0, duration: fadeIn)
        back.timingMode = .easeOut
        let done = SKAction.run { [weak self] in
            self?.director?.isSpawningPaused = false
            NotificationCenter.default.post(name: .locationTransitionDidFinish, object: nil, userInfo: ["tier": tier])
        }
        veil.run(.sequence([out, swap, back, done]), withKey: "locationTransition")
    }

    private func runNewRunTransition() {
        isRunTransitionActive = true
        director?.isSpawningPaused = true
        let fadeOut = reduceMotion ? 0.1 : 0.35
        let fadeIn = reduceMotion ? 0.1 : 0.45
        let out = SKAction.fadeAlpha(to: 1, duration: fadeOut)
        out.timingMode = .easeIn
        let swap = SKAction.run { [weak self] in
            self?.rebuildWorld()
        }
        let back = SKAction.fadeAlpha(to: 0, duration: fadeIn)
        back.timingMode = .easeOut
        let done = SKAction.run { [weak self] in
            self?.isRunTransitionActive = false
            self?.director?.isSpawningPaused = false
            NotificationCenter.default.post(name: .newSpringDidFinish, object: nil)
        }
        // Own key: a location move must not cancel this sequence, or the game stays untappable.
        veil.removeAction(forKey: "locationTransition")
        veil.run(.sequence([out, swap, back, done]), withKey: "runTransition")
    }

    // MARK: Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { tapClassifier.begin(at: touch.location(in: view)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first { tapClassifier.move(to: touch.location(in: view)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if tapClassifier.end(at: touch.location(in: view)) { handleTap(at: touch.location(in: self)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        tapClassifier.cancel()
    }

    private func handleTap(at scenePoint: CGPoint) {
        guard !isRunTransitionActive, let store, let layout, let farm, let shop, let yard else { return }
        let p = layout.rootPoint(fromScene: scenePoint)
        if let hit = farm.hit(local: farm.local(fromRoot: p), plotCount: store.farm.plots.count, canAdd: canAddPlot(store)) {
            handleFarmTap(hit, store: store)
        } else if let menu = shop.menuIndex(atLocal: shop.local(fromRoot: p)) {
            handleDishTap(menu, store: store)
        } else if yard.hit(local: yard.local(fromRoot: p)) {
            sound.play(.tap)
            fx?.lightHaptic()
            NotificationCenter.default.post(name: .requestExpandWarehouse, object: nil)
        }
    }

    private func handleDishTap(_ menu: Int, store: GameStore) {
        guard let shop, let fx else { return }
        guard menu <= store.stall.menuTier else {
            shop.shakeLock(menu: menu, reduceMotion: reduceMotion)
            sound.play(.error)
            return
        }
        if store.startManualCook(menuIndex: menu) {
            if menu == 0 { FirstRunHint.cook.markDone() }
            shop.pulse(menu: menu, reduceMotion: reduceMotion)
            fx.puff(at: shop.dishPoint(menu))
            fx.lightHaptic()
            sound.play(.tap)
            return
        }
        // A tap that starts nothing still answers: a shake, and a sound limited so mashing stays calm.
        shop.shakeDish(menu: menu, reduceMotion: reduceMotion)
        let now = CACurrentMediaTime()
        let isCooking = store.isCooking(menuIndex: menu)
        guard now - (lastDishFeedback[menu] ?? 0) > (isCooking ? 0.8 : 0.3) else { return }
        lastDishFeedback[menu] = now
        sound.play(isCooking ? .tap : .error)
    }

    private func handleFarmTap(_ hit: FarmNode.Hit, store: GameStore) {
        guard let farm, let fx else { return }
        switch hit {
        case .addPlot:
            sound.play(.tap)
            fx.lightHaptic()
            NotificationCenter.default.post(name: .requestAddFarmPlot, object: nil)
        case .plot(let index):
            guard store.farm.plots.indices.contains(index) else { return }
            switch store.farm.plots[index].stage {
            case .empty:
                store.plantSeed(plotIndex: index)
                if store.farm.plots[index].isPlanted {
                    FirstRunHint.plant.markDone()
                    farm.apply(farm: store.farm, canAddPlot: canAddPlot(store), reduceMotion: reduceMotion)
                    farm.bump(plot: index, reduceMotion: reduceMotion)
                    fx.puff(at: farm.plotCenter(index))
                    fx.lightHaptic()
                    sound.play(.plant)
                } else {
                    farm.shake(plot: index, reduceMotion: reduceMotion)
                    sound.play(.error)
                }
            case .ready:
                harvest(index, store: store)
            case .sprout, .growing:
                farm.bump(plot: index, reduceMotion: reduceMotion)
            }
        }
    }

    private func harvest(_ index: Int, store: GameStore) {
        guard let farm, let fx, let yard, let layout else { return }
        guard let result = store.harvest(plotIndex: index) else {
            farm.shake(plot: index, reduceMotion: reduceMotion)
            yard.bump(reduceMotion: reduceMotion)
            sound.play(.error)
            return
        }
        FirstRunHint.harvest.markDone()
        farm.apply(farm: store.farm, canAddPlot: canAddPlot(store), reduceMotion: reduceMotion)
        let from = farm.plotCenter(index)
        fx.puff(at: from)
        fx.lightHaptic()
        let item = result.isGolden ? "dot_farm_cabbage_golden_item" : "dot_farm_cabbage_item"
        fx.flyItem(item, from: from, to: yard.cratePoint) { [weak self] in
            guard let self else { return }
            self.yard?.bump(reduceMotion: self.reduceMotion)
            if !result.isGolden { self.sound.play(.harvest) }
        }
        guard result.isGolden else { return }
        sound.play(.golden)
        fx.successHaptic()
        fx.sparkleBurst(at: from)
        fx.pop("+\(CoinFormat.string(result.bonusCoins))", at: CGPoint(x: from.x, y: from.y + 12),
               color: SKColor(hex: 0xffe680), rise: 20)
        fx.flyCoins(from: from, to: layout.rootPoint(fromScene: coinTargetScenePoint), count: 8)
    }
}
