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
    /// Posted when the padlock of the next dish is tapped and affordable; `userInfo["menu"]` is the
    /// dish index. `UnlockDishConfirmation` owns the alert and purchase.
    static let requestUnlockDish = Notification.Name("requestUnlockDish")
    /// Posted when a plot ripens golden; the HUD shows a rate-limited toast.
    static let goldenPlotRipened = Notification.Name("goldenPlotRipened")
    /// Posted when the gift crate is tapped; the root view owns the ad offer.
    static let requestGiftOffer = Notification.Name("requestGiftOffer")
    /// A short HUD notice; `userInfo["text"]` is the line, `userInfo["announce"]` an optional VoiceOver line.
    static let requestHUDToast = Notification.Name("requestHUDToast")

    static func postHUDToast(_ text: String) {
        NotificationCenter.default.post(name: .requestHUDToast, object: nil, userInfo: ["text": text])
    }
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
    var isStorefrontHeld = false { didSet { director?.isHeld = isStorefrontHeld } }

    var isSoundEnabled: Bool {
        get { DotSound.shared.isEnabled }
        set { DotSound.shared.isEnabled = newValue }
    }

    private let sound = DotSound.shared
    private let root = SKNode()
    private let veil = SKSpriteNode(color: SKColor(hex: 0x2b1b2e), size: .zero)

    var layout: DotWorldLayout?
    private var needsLayout = true
    private var lastUpdate: TimeInterval = 0

    private var backdrop: BackdropNode?
    private var groundNode: SKSpriteNode?
    private var shop: ShopNode?
    private var yard: YardNode?
    var farm: FarmNode?
    private var director: CustomerDirector?
    private var partTimer: PartTimerNode?
    private var fx: FXLayer?
    var tipLayer: TipLayer?
    #if DEBUG
    var autoplayState = AutoplayState()
    #endif
    private let feverTally = PixelLabel(style: .bold, color: SKColor(hex: 0xffe680))
    private var knownGolden: Set<Int>?
    private var weatherFX: WeatherNode?
    private var tint: SKSpriteNode?
    private var feverGlow: SKSpriteNode?
    private var hintArrow: HintArrowNode?
    private var lastDishFeedback: [Int: TimeInterval] = [:]
    /// Consecutive hurry taps per dish, for the rising pitch: `(count, time of the last one)`.
    private var hurryStreak: [Int: (count: Int, at: TimeInterval)] = [:]
    private var lastFullNotice: TimeInterval = 0
    private var lastWakeHint: TimeInterval = 0

    private var appliedLocation: Int?
    private var lastPrestige: Int?
    private var isRunTransitionActive = false
    private var lastWeather: Weather = .clear
    private var wasFever = false
    private var wasGiftPresent = false
    private var giftSparkleClock: TimeInterval = 0
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

    private func rebuildWorld(force: Bool = false) {
        needsLayout = false
        guard size.width > 0, size.height > 0 else { return }
        let scaleFactor = view?.window?.screen.scale ?? UIScreen.main.scale
        let layout = DotWorldLayout(viewSize: size, topInset: topInset, bottomInset: bottomInset, screenScale: scaleFactor)
        if !force, let current = self.layout, current.hasSameGeometry(as: layout), !root.children.isEmpty {
            self.layout = layout
            return
        }
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
        let partTimer = PartTimerNode()
        street.addChild(partTimer)
        director.isHeld = isStorefrontHeld
        director.onServed = { [weak self] in self?.customerServed($0) }
        director.onFailed = { [weak self] point in
            self?.fx?.reaction("dot_fx_anger", at: point)
            self?.sound.play(.error)
        }
        director.onSparkle = { [weak self] point in self?.fx?.sparkle(at: point) }
        let weatherFX = WeatherNode(layout: layout, fx: fx)
        let tips = TipLayer()
        feverTally.removeFromParent()
        feverTally.position = CGPoint(x: CGFloat(DotWorldLayout.width) / 2, y: -CGFloat(layout.shopTop - 8))
        feverTally.zPosition = 20
        feverTally.isHidden = true
        fx.addChild(feverTally)

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
        for node in [backdrop, ground, shop, street, yard, farm, decor, weatherFX, tint, glow, labels, tips, hint, fx] as [SKNode] { root.addChild(node) }
        hintArrow = hint
        tipLayer = tips
        self.fx = fx; self.backdrop = backdrop; groundNode = ground; self.shop = shop
        self.yard = yard; self.farm = farm; self.director = director; self.partTimer = partTimer; self.weatherFX = weatherFX
        self.tint = tint; feverGlow = glow
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        let delta = (lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 3.0)) * DotDebug.speed
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
        autoplay(delta: delta, store: store)
        store.tick(deltaTime: delta)
        director?.update(delta: delta, store: store, isFever: store.isFeverActive, reduceMotion: reduceMotion)
        tipLayer?.update(delta: delta)
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

    private static func startSound(_ weather: Weather) -> DotSound.Effect? {
        switch weather {
        case .clear:  return nil
        case .rain:   return .rainStart
        case .snow:   return .snowStart
        case .leaves: return .leavesStart
        case .petals: return .petalsStart
        }
    }

    private func applyState(_ store: GameStore, delta: TimeInterval) {
        guard let backdrop, let shop, let yard, let farm, let weatherFX, let tint, let feverGlow, let fx else { return }
        let reduce = reduceMotion
        let progress = DotDebug.dayProgress ?? DayCycle.progress(playSeconds: store.progress.totalPlaySeconds)
        let look = DayLook.at(progress: progress)
        backdrop.update(delta: delta, progress: progress, look: look, reduceMotion: reduce)

        partTimer?.setActive(store.isPartTimerActive, animated: !reduce)

        let weather = store.weather
        if weather != lastWeather, let cue = Self.startSound(weather) { sound.play(cue) }
        lastWeather = weather
        weatherFX.update(delta: delta, weather: weather, animated: !reduce)
        tint.color = look.tint.mixed(with: look.tint.multiplied(by: weatherFX.tint.color), weatherFX.tint.amount)

        let fever = store.isFeverActive
        if fever, !wasFever { sound.play(.feverStart) }
        updateFeverTally(store, isFever: fever, fx: fx)
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
        applyGift(store, yard: yard, fx: fx, delta: delta)
        let starved = isWarehouseStarved(store)
        yard.setAlert(starved, reduceMotion: reduce)
        farm.apply(farm: store.farm, canAddPlot: canAddPlot(store), pulseRipe: starved, reduceMotion: reduce)
        announceGoldenPlots(store, farm: farm, fx: fx)
        updateHint(store, shop: shop, farm: farm)
        hintWakeIfNeeded(store)
    }

    // MARK: Gift crate

    /// The crate drops in with a chime, glitters while it waits and is tapped to open the offer.
    private func applyGift(_ store: GameStore, yard: YardNode, fx: FXLayer, delta: TimeInterval) {
        let present = store.isGiftPresent
        if present, !wasGiftPresent {
            sound.play(.golden, volume: 0.5)
            fx.sparkleBurst(at: yard.giftPoint, radius: 12)
        }
        wasGiftPresent = present
        yard.setGift(isPresent: present, remaining: store.giftRemaining, reduceMotion: reduceMotion)
        guard present, !reduceMotion else { return }
        giftSparkleClock -= delta
        if giftSparkleClock <= 0 {
            giftSparkleClock = 0.7
            let jitter = CGPoint(x: CGFloat.random(in: -8...8).rounded(), y: CGFloat.random(in: -6...6).rounded())
            fx.sparkle(at: CGPoint(x: yard.giftPoint.x + jitter.x, y: yard.giftPoint.y + jitter.y))
        }
    }

    // MARK: Fever tally

    /// Running "피버 수익" over the shop while fever lasts, then one big pop when it ends.
    private func updateFeverTally(_ store: GameStore, isFever: Bool, fx: FXLayer) {
        if isFever {
            feverTally.isHidden = false
            feverTally.text = String(format: String(localized: "dot.fever.tally"), CoinFormat.string(store.feverEarned))
        } else if wasFever {
            feverTally.isHidden = true
            guard store.feverEarned > 0, let layout else { return }
            fx.pop(String(format: String(localized: "dot.fever.tally"), CoinFormat.string(store.feverEarned)),
                   at: CGPoint(x: CGFloat(DotWorldLayout.width) / 2, y: -CGFloat(layout.shopTop + 22)),
                   color: SKColor(hex: 0xffe680), rise: 16, hold: 1.2)
            fx.successHaptic()
        }
    }

    // MARK: Golden plots

    /// A plot that has just ripened golden gets a burst, a soft chime and a HUD toast. Plots that
    /// are already golden when the scene first looks are not announced again.
    private func announceGoldenPlots(_ store: GameStore, farm: FarmNode, fx: FXLayer) {
        let current = Set(store.farm.plots.indices.filter { store.farm.plots[$0].stage == .ready && store.farm.plots[$0].isGolden })
        defer { knownGolden = current }
        guard let known = knownGolden else { return }
        let fresh = current.subtracting(known)
        guard !fresh.isEmpty else { return }
        for index in fresh.sorted() { fx.sparkleBurst(at: farm.plotCenter(index), radius: 14) }
        sound.play(.golden, volume: 0.35)
        NotificationCenter.default.post(name: .goldenPlotRipened, object: nil)
    }

    /// Nothing to cook with while a dish the player could sell is out of stock.
    private func isWarehouseStarved(_ store: GameStore) -> Bool {
        store.stall.warehouse == 0
            && (0...min(store.stall.menuTier, 2)).contains { store.stall.menuStock[$0] == 0 }
    }

    // MARK: First-run pointer

    /// One pointer at a time, only once both intro overlays are gone. A customer waiting on a dish
    /// nobody cooks comes first and is not one-time: with no ghost cooking, the tap is the only way
    /// that dish gets made, so the pointer returns every time and leaves once a session or a cook starts.
    private func updateHint(_ store: GameStore, shop: ShopNode, farm: FarmNode) {
        guard let arrow = hintArrow else { return }
        var tip: CGPoint?
        if !store.progress.isFirstLaunch, store.progress.isShopNameSet, !isRunTransitionActive {
            let plots = store.farm.plots
            let waiting = director?.waitingMenus ?? []
            let dishes = 0...min(store.stall.menuTier, 2)
            if let menu = dishes.first(where: { waiting.contains($0) && store.needsPlayerTap(menuIndex: $0) }) {
                tip = shop.hintTip(menu)
                teachHurry()
            } else if !FirstRunHint.harvest.isDone, let i = plots.firstIndex(where: \.isReady) {
                tip = farm.hintTip(i)
            } else if !FirstRunHint.plant.isDone,
                      let i = plots.firstIndex(where: { $0.stage == .empty && $0.workerType == .none })
                        ?? plots.firstIndex(where: { $0.stage == .empty }) {
                tip = farm.hintTip(i)
            } else if !FirstRunHint.cook.isDone, store.needsPlayerTap(menuIndex: 0) {
                tip = shop.hintTip(0)
                teachHurry()
            } else if !FirstRunHint.hurry.isDone, let menu = dishes.first(where: { store.isCooking(menuIndex: $0) }) {
                tip = shop.hintTip(menu)
                teachHurry()
            }
        }
        arrow.show(tip: tip, animated: !reduceMotion)
    }

    /// The words that go with the pointer on the dish, once per install.
    private func teachHurry() {
        guard !UserDefaults.standard.bool(forKey: FirstRunHint.hurryToastKey) else { return }
        UserDefaults.standard.set(true, forKey: FirstRunHint.hurryToastKey)
        Notification.Name.postHUDToast(String(localized: "dot.hint.hurry"))
    }

    /// A worker has dozed off: tell the player, twice per install, how to get the post working again.
    private func hintWakeIfNeeded(_ store: GameStore) {
        guard !store.progress.isFirstLaunch, store.progress.isShopNameSet, !isRunTransitionActive else { return }
        let count = UserDefaults.standard.integer(forKey: FirstRunHint.wakeHintKey)
        let now = CACurrentMediaTime()
        guard count < 2, now - lastWakeHint > 60 else { return }
        let sleeping = store.farm.plots.indices.contains { store.isResting(.farm(plotIndex: $0)) }
            || (0..<3).contains { store.isResting(.cook(menuIndex: $0)) } || store.isResting(.cashier)
        guard sleeping else { return }
        lastWakeHint = now
        UserDefaults.standard.set(count + 1, forKey: FirstRunHint.wakeHintKey)
        Notification.Name.postHUDToast(String(localized: "dot.hint.wake"))
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

    func canAddPlot(_ store: GameStore) -> Bool {
        FarmSystem.costForNextPlot(currentCount: store.farm.plots.count) != nil
    }

    // MARK: Customers

    private func customerServed(_ event: CustomerDirector.ServeEvent) {
        guard let fx, let shop, let layout else { return }
        fx.reaction("dot_fx_heart", at: event.headPoint)
        // Low and short-lived: higher, a fever pop climbs over the counter's padlocks.
        fx.pop("+\(CoinFormat.string(event.price))", at: CGPoint(x: event.headPoint.x, y: event.headPoint.y - 2),
               color: SKColor(hex: event.isGourmet ? 0xffe680 : 0xf4b93a), rise: 6, big: store?.isFeverActive == true)
        if let store, store.rollTip(isGourmet: event.isGourmet) || DotDebug.alwaysTips {
            tipLayer?.drop(at: event.footPoint, amount: GameStore.tipAmount(forSale: event.price, isGourmet: event.isGourmet),
                           reduceMotion: reduceMotion)
        }
        // Without an auto-collecting cashier the coins stay on the till for the player to tap.
        if store?.autoCollectsCoins == true {
            fx.flyCoins(from: shop.tillRootPoint, to: layout.rootPoint(fromScene: coinTargetScenePoint),
                        count: event.isGourmet ? 6 : 3)
        }
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
            self?.rebuildWorld(force: true)
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
        if let tip = tipLayer?.collect(at: p) {
            collectTip(tip, store: store, layout: layout)
        } else if shop.hitPile(atLocal: shop.local(fromRoot: p)) {
            collectPile(store: store, layout: layout)
        } else if let hit = farm.hit(local: farm.local(fromRoot: p), plotCount: store.farm.plots.count, canAdd: canAddPlot(store)) {
            handleFarmTap(hit, store: store)
        } else if let target = shop.workerTarget(atLocal: shop.local(fromRoot: p)),
                  store.isResting(target), handleWake(target, store: store) {
            DotDebug.tapLog("wake ok")
        } else if let menu = shop.menuIndex(atLocal: shop.local(fromRoot: p)) {
            handleDishTap(menu, store: store)
        } else if store.isGiftPresent, yard.hitGift(local: yard.local(fromRoot: p)) {
            sound.play(.tap)
            fx?.lightHaptic()
            NotificationCenter.default.post(name: .requestGiftOffer, object: nil)
        } else if yard.hit(local: yard.local(fromRoot: p)) {
            sound.play(.tap)
            fx?.lightHaptic()
            NotificationCenter.default.post(name: .requestExpandWarehouse, object: nil)
        }
    }

    /// Banks the takings piled on the till (no cashier, or she is asleep).
    func collectPile(store: GameStore, layout: DotWorldLayout) {
        guard let fx, let shop, store.stall.pendingCoins > 0 else { return }
        DotDebug.tapLog("pile ok")
        let amount = store.stall.pendingCoins
        store.collectCoins()
        fx.sparkle(at: shop.pileRootPoint)
        fx.pop("+\(CoinFormat.string(amount))", at: CGPoint(x: shop.pileRootPoint.x, y: shop.pileRootPoint.y + 6),
               color: SKColor(hex: 0xf4b93a), rise: 10)
        fx.flyCoins(from: shop.pileRootPoint, to: layout.rootPoint(fromScene: coinTargetScenePoint), count: 4)
        fx.lightHaptic()
        sound.play(.coin)
    }

    func collectTip(_ tip: (amount: Double, point: CGPoint), store: GameStore, layout: DotWorldLayout) {
        guard let fx else { return }
        DotDebug.tapLog("tip ok")
        store.collectTip(amount: tip.amount)
        fx.sparkle(at: tip.point)
        fx.pop("+\(CoinFormat.string(tip.amount))", at: CGPoint(x: tip.point.x, y: tip.point.y + 6),
               color: SKColor(hex: 0xffe680), rise: 10)
        fx.flyCoins(from: tip.point, to: layout.rootPoint(fromScene: coinTargetScenePoint), count: 2)
        fx.lightHaptic()
        sound.play(.coin)
    }

    func handleDishTap(_ menu: Int, store: GameStore) {
        guard let shop, let fx else { return }
        let result = store.tapDish(menuIndex: menu)
        switch result {
        case .locked:
            switch MenuUnlockSystem.status(for: store.stall, menuIndex: menu) {
            case .available:
                sound.play(.tap)
                fx.lightHaptic()
                NotificationCenter.default.post(name: .requestUnlockDish, object: nil, userInfo: ["menu": menu])
            case .short(_, _, let shortfall):
                shop.shakeLock(menu: menu, reduceMotion: reduceMotion)
                sound.play(.error)
                Notification.Name.postHUDToast(
                    String(format: String(localized: "dish.unlock.short"), CoinFormat.string(shortfall)))
            case .needsEarlier(_, let nextIndex):
                shop.shakeLock(menu: menu, reduceMotion: reduceMotion)
                sound.play(.error)
                Notification.Name.postHUDToast(
                    String(format: String(localized: "dish.unlock.earlier"), UpgradeDefinitions.menu[nextIndex].name))
            case .notLocked:
                shop.shakeLock(menu: menu, reduceMotion: reduceMotion)
                sound.play(.error)
            }
        case .started:
            DotDebug.tapLog("dish ok")
            if menu == 0 { FirstRunHint.cook.markDone() }
            shop.pulse(menu: menu, reduceMotion: reduceMotion)
            fx.puff(at: shop.dishPoint(menu))
            fx.lightHaptic()
            sound.play(.tap)
        case .hurried:
            DotDebug.tapLog("hurry ok")
            FirstRunHint.hurry.markDone()
            shop.pulse(menu: menu, reduceMotion: reduceMotion)
            fx.puff(at: shop.dishPoint(menu))
            fx.lightHaptic()
            sound.play(.tap, volume: 0.8, rate: hurryPitch(menu))
        case .ignored:
            break
        case .blocked:
            DotDebug.tapLog("dish none")
            // A tap that starts nothing still answers: a shake, and a sound limited so mashing stays calm.
            shop.shakeDish(menu: menu, reduceMotion: reduceMotion)
            let now = CACurrentMediaTime()
            guard now - (lastDishFeedback[menu] ?? 0) > 0.3 else { return }
            lastDishFeedback[menu] = now
            sound.play(.error)
        }
    }

    /// 1.0 on the first tap of a run, up a little with each one, back down after a pause.
    private func hurryPitch(_ menu: Int) -> Float {
        let now = CACurrentMediaTime()
        var streak = hurryStreak[menu] ?? (0, 0)
        streak.count = now - streak.at < 1.2 ? streak.count + 1 : 0
        streak.at = now
        hurryStreak[menu] = streak
        return min(1.7, 1 + 0.1 * Float(streak.count))
    }

    /// A tap on a sleeping cook, cashier or farm hand. False when the store refuses (awake, or hurried lately).
    @discardableResult
    func handleWake(_ target: GameStore.WorkerTarget, store: GameStore) -> Bool {
        guard let fx, let shop, let farm, store.wakeWorker(target) else { return false }
        let head: CGPoint
        switch target {
        case .farm(let index):
            head = farm.workerHead(index)
            farm.bumpWorker(plot: index, reduceMotion: reduceMotion)
        default:
            head = shop.headPoint(of: target)
            shop.bump(worker: target, reduceMotion: reduceMotion)
        }
        fx.reaction("dot_fx_heart", at: head)
        fx.sparkle(at: CGPoint(x: head.x + 5, y: head.y - 4))
        fx.lightHaptic()
        sound.play(.tap, volume: 0.7, rate: 1.4)
        return true
    }

    func handleFarmTap(_ hit: FarmNode.Hit, store: GameStore) {
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
                    DotDebug.tapLog("plant ok")
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
                if store.isResting(.farm(plotIndex: index)), handleWake(.farm(plotIndex: index), store: store) { return }
                water(index, store: store)
            }
        }
    }

    /// Every tap on a growing plot waters it; a tap the store debounces still bumps the bed, silently.
    private func water(_ index: Int, store: GameStore) {
        guard let farm, let fx else { return }
        guard store.waterPlot(plotIndex: index) else {
            farm.bump(plot: index, reduceMotion: reduceMotion)
            return
        }
        DotDebug.tapLog("water ok")
        farm.apply(farm: store.farm, canAddPlot: canAddPlot(store), reduceMotion: reduceMotion)
        farm.bump(plot: index, reduceMotion: reduceMotion)
        fx.water(at: farm.plotCenter(index))
        fx.lightHaptic()
        sound.play(.plant, volume: 0.45, rate: 1.3)
    }

    private func harvest(_ index: Int, store: GameStore) {
        guard let farm, let fx, let yard, let layout else { return }
        guard let result = store.harvest(plotIndex: index) else {
            DotDebug.tapLog("harvest blocked")
            farm.shake(plot: index, reduceMotion: reduceMotion)
            yard.bump(reduceMotion: reduceMotion)
            sound.play(.error)
            if store.isWarehouseFull {
                // The crop is fine; the crate is the problem. Say so, and shake the crate.
                yard.shake(reduceMotion: reduceMotion)
                let now = CACurrentMediaTime()
                if now - lastFullNotice > 3 {
                    lastFullNotice = now
                    yard.showNotice(String(localized: "dot.warehouse.full").components(separatedBy: "\n"),
                                    reduceMotion: reduceMotion)
                }
            }
            return
        }
        DotDebug.tapLog(result.isGolden ? "harvest golden ok" : "harvest ok")
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
        fx.pop(String(format: String(localized: "dot.harvest.goldenCrops"), result.cropsStored),
               at: CGPoint(x: from.x, y: from.y + 24), color: SKColor(hex: 0xb8f08c), rise: 20)
        fx.pop("+\(CoinFormat.string(result.bonusCoins))", at: CGPoint(x: from.x, y: from.y + 12),
               color: SKColor(hex: 0xffe680), rise: 20)
        fx.flyCoins(from: from, to: layout.rootPoint(fromScene: coinTargetScenePoint), count: 8)
    }
}
