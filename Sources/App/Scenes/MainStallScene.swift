import SpriteKit
import GameCore
import UIKit

extension Notification.Name {
    /// Posted by `MainStallScene` once a location purchase's transition has
    /// faded back in; `userInfo["tier"]` is the new `Int` tier. The toast
    /// and VoiceOver announcement key off this, not the purchase itself.
    static let locationTransitionDidFinish = Notification.Name("locationTransitionDidFinish")
    /// Posted when the `plot_add` cell is tapped. `AddFarmPlotConfirmation`
    /// owns the confirm alert and the purchase, like the location move.
    static let requestAddFarmPlot = Notification.Name("requestAddFarmPlot")
}

final class MainStallScene: SKScene {

    weak var store: GameStore?

    private static let maxDelta: TimeInterval = 1.0 / 3.0
    private var lastUpdateTime: TimeInterval = 0
    private let groundLayer = GroundLayer()
    private let fieldLayer = FieldLayer()
    private let locationBackdrop = LocationBackdropNode(fittingTo: GroundLayer.grid)

    /// Spawns, walks and serves customers at `shop`'s counter — added
    /// directly to the scene (see `update`) rather than under `shop` or
    /// `groundLayer`, so its `ShopNode.actorZPosition`-derived zPosition
    /// compares against theirs on the same unscaled `col + row` origin,
    /// with no ancestor zPosition offset (like `fieldLayer`'s `10`) to
    /// account for.
    private let customerSpawner = ShopCustomerSpawner()

    /// The shop building: a self-contained unit of ground tiles and
    /// perimeter walls covering `ShopNode.defaultPlacement` — the real
    /// shop's actual size and position on the map (see that constant's
    /// own doc comment). Replaces the four individually hand-placed wall
    /// nodes (and their hardcoded 7/8/10/11 zPosition constants) this
    /// scene used when the shop was still a single map cell; `ShopNode`
    /// derives both position and draw order from the grid itself, so it
    /// scales to the shop's now-larger 3×3 footprint without per-wall
    /// bookkeeping here.
    private let shop = ShopNode(
        originX: ShopNode.defaultPlacement.originX,
        originY: ShopNode.defaultPlacement.originY,
        fittingTo: GroundLayer.grid
    )

    /// Last tier `shop.applyMenuTier` ran with. `nil` can't match a real
    /// tier, so the first `updateShopMenuTier()` call always applies —
    /// needed even before any tier change, e.g. loading a save already at
    /// tier 2.
    private var lastAppliedMenuTier: Int?

    /// Last tier `shop.applyStallTier` ran with — same `nil`-sentinel
    /// pattern as `lastAppliedMenuTier`, so the first call always applies
    /// even for a save already past tier 0.
    private var lastAppliedStallTier: Int?

    /// Last location tier the scene art was swapped to — same
    /// `nil`-sentinel as the tiers above: the first apply (a save already
    /// at tier 2, or tier 0 on a new game) is instant, only a later change
    /// is a transition.
    private var lastAppliedLocationTier: Int?

    /// Last fill state `shop.applyCookFill` ran with, per menu index. `nil`
    /// can't match a real `Bool`, so each menu's first
    /// `updateShopCookGauge()` call always applies — same reasoning as
    /// `lastAppliedMenuTier`. Unlike a gauge's own `progress`, which
    /// changes continuously and pushes every frame, this flips rarely
    /// (crossing the 0.5 threshold), so it's worth guarding per menu
    /// rather than assigning `isHidden` on two nodes every frame for no
    /// visible change.
    private var lastAppliedCookFillByMenuIndex: [Int: Bool] = [:]

    /// Last staff presence pushed to the shop; `nil` so the first frame
    /// always applies (a save that loads with staff already hired).
    private var lastAppliedStaff: ShopStaffPresence?

    /// `prestigeCount` the scene last saw; `nil` until the store is attached. A change means the
    /// store has already replaced the whole run (and saved it), so the scene plays the new-spring
    /// transition and rebuilds from state instead of letting each `update*` snap its piece.
    private var lastSeenPrestigeCount: Int?

    /// True from the moment a new run is noticed until the fade-in ends. While set, nothing is
    /// pushed from the store and the simulation does not advance, so the old shop stays on screen
    /// until the veil covers it and the new run's first tick happens on the new shop.
    private var isRunTransitionActive = false

    /// Pans the world; `GroundLayer.worldBounds` clamps how far (see
    /// `clampCameraPosition()`) — "the map data" (`GroundLayer.map` plus
    /// its margin) is what actually limits the scrollable area, not the
    /// device screen.
    private let cameraNode = SKCameraNode()

    /// Full-screen cover in the background colour, parented to the camera
    /// so it follows any pan; the location transition fades it in and out.
    /// Oversized so no device or camera position shows its edge.
    private let transitionVeil: SKSpriteNode = {
        let veil = SKSpriteNode(color: GroundTile.fillColor, size: CGSize(width: 4000, height: 4000))
        veil.alpha = 0
        veil.zPosition = 100_000
        return veil
    }()

    /// Set on `touchesBegan`, cleared on `touchesEnded`/`touchesCancelled`
    /// — `nil` means no active drag, so `touchesMoved` has nothing to
    /// diff against yet (the first move after a touch begins establishes
    /// the baseline rather than jumping the camera).
    private var lastPanLocation: CGPoint?

    /// Tap-vs-pan is judged in **view** points: the camera follows the
    /// finger, so in scene space a pan's start and end nearly coincide and
    /// would read as a tap. The slop (10 screen points) lives in `TapClassifier`.
    private var tapClassifier = TapClassifier()

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor

        camera = cameraNode
        addChild(cameraNode)
        cameraNode.addChild(transitionVeil)
        // Start framed on the shop itself — the whole point of this
        // change — rather than `GroundLayer.mapCentroid`: that averages
        // every cell in `GroundLayer.map`, including the six field rows
        // and the grass border, so once the map grew to fit the shop's
        // (now 3×3) block, that average sat well north-east of the shop's
        // own footprint (confirmed: it left the shop's west corner ~346pt
        // off a 402pt-wide screen). `ShopPlacement.centroid(on:)` averages
        // only the shop's own cells, so the camera centers on the
        // building regardless of how the surrounding map is shaped.
        cameraNode.position = ShopNode.defaultPlacement.centroid(on: GroundLayer.grid)

        // GroundLayer draws once, in fixed world
        // space — no `size` argument anymore, and no need to call again on
        // resize (only the camera's clamp bounds depend on screen size,
        // handled in didChangeSize below).
        addChild(groundLayer)
        groundLayer.layout()

        // Sits behind everything by its own col + row z-rule (see
        // `LocationBackdropNode`), so add order does not matter.
        addChild(locationBackdrop)

        // FieldLayer is state-driven (see `updateFarm`).
        fieldLayer.zPosition = 10
        addChild(fieldLayer)
        updateFarm()

        addChild(shop)
        updateShopMenuTier()
        updateShopStallTier()
        updateLocationTier()
        updateShopCookGauge()
        updateShopStaff()

        clampCameraPosition()
    }

    /// Pushes `store.farm` into the field; `FieldLayer` diffs internally,
    /// so a frame with no stage or worker change touches no node.
    private func updateFarm() {
        guard let farm = store?.farm else { return }
        let canAddPlot = FarmSystem.costForNextPlot(currentCount: farm.plots.count) != nil
        fieldLayer.apply(farm: farm, canAddPlot: canAddPlot)
    }

    /// Toggles the prep table's items for `store.stall.menuTier`, only
    /// when it actually changed — avoids poking `isHidden` every frame.
    private func updateShopMenuTier() {
        guard let tier = store?.stall.menuTier, tier != lastAppliedMenuTier else { return }
        shop.applyMenuTier(tier)
        lastAppliedMenuTier = tier
    }

    /// Shows the hired cashier/cook figures, only when their derived
    /// presence changed.
    private func updateShopStaff() {
        guard let store else { return }
        let presence = ShopStaffPresence(stall: store.stall, cashierRecentlySold: store.cashierRecentlySold)
        guard presence != lastAppliedStaff else { return }
        shop.applyStaff(presence)
        lastAppliedStaff = presence
    }

    /// Swaps the shop's enclosure (walled shop vs. pojangmacha stall) for
    /// `store.stall.stallTier`, only when it actually changed — same
    /// guard as `updateShopMenuTier`.
    private func updateShopStallTier() {
        guard let tier = store?.stall.stallTier, tier != lastAppliedStallTier else { return }
        shop.applyStallTier(tier)
        lastAppliedStallTier = tier
    }

    /// Shows the backdrop set (and road tile) for `store.stall.locationTier`,
    /// only when it actually changed.
    private func updateLocationTier() {
        guard let tier = store?.stall.locationTier, tier != lastAppliedLocationTier else { return }
        let isFirstApply = lastAppliedLocationTier == nil
        lastAppliedLocationTier = tier
        if isFirstApply {
            applyLocationArt(tier)
        } else {
            runLocationTransition(to: tier)
        }
    }

    private func applyLocationArt(_ tier: Int) {
        locationBackdrop.apply(tier: tier)
        groundLayer.applyLocationTier(tier)
    }

    /// Purchase transition, ~0.8 s of the spec's 1.2 s budget plus the
    /// toast that follows: fade to the background colour (0.35 s,
    /// ease-in), swap art / reset camera / clear customers under the
    /// veil, fade back in (0.45 s, ease-out) with the shop settling from
    /// 0.95 to 1.0. Spawning resumes when the fade-in ends, which is also
    /// when `.locationTransitionDidFinish` fires for the toast.
    ///
    /// Reduce Motion: no scale settle and a 0.1 s + 0.1 s dissolve (0.2 s
    /// total); the camera still resets, since it is part of the swap.
    private func runLocationTransition(to tier: Int) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let fadeOutDuration: TimeInterval = reduceMotion ? 0.1 : 0.35
        let fadeInDuration: TimeInterval = reduceMotion ? 0.1 : 0.45

        customerSpawner.isSpawningPaused = true

        let fadeOut = SKAction.fadeAlpha(to: 1, duration: fadeOutDuration)
        fadeOut.timingMode = .easeIn
        let swap = SKAction.run { [weak self] in
            guard let self else { return }
            self.applyLocationArt(tier)
            self.customerSpawner.removeAllCustomers()
            self.resetCameraToShop()
            if !reduceMotion { self.settleShop(duration: fadeInDuration) }
        }
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: fadeInDuration)
        fadeIn.timingMode = .easeOut
        let finish = SKAction.run { [weak self] in
            self?.customerSpawner.isSpawningPaused = false
            NotificationCenter.default.post(
                name: .locationTransitionDidFinish, object: nil, userInfo: ["tier": tier])
        }

        // Same key on a repeat purchase replaces the running sequence.
        transitionVeil.run(.sequence([fadeOut, swap, fadeIn, finish]), withKey: "locationTransition")
    }

    /// New spring, ~0.8 s like a location move but a full rebuild under the veil: art for every
    /// tier, field, staff, customers, coin pops, camera and spawner all come back from state.
    /// Reduce Motion: the same 0.1 s + 0.1 s dissolve, no settle.
    private func runNewRunTransition() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let fadeOutDuration: TimeInterval = reduceMotion ? 0.1 : 0.35
        let fadeInDuration: TimeInterval = reduceMotion ? 0.1 : 0.45

        isRunTransitionActive = true
        customerSpawner.isSpawningPaused = true

        let fadeOut = SKAction.fadeAlpha(to: 1, duration: fadeOutDuration)
        fadeOut.timingMode = .easeIn
        let swap = SKAction.run { [weak self] in
            guard let self else { return }
            self.rebuildFromState()
            if !reduceMotion { self.settleShop(duration: fadeInDuration) }
        }
        let fadeIn = SKAction.fadeAlpha(to: 0, duration: fadeInDuration)
        fadeIn.timingMode = .easeOut
        let finish = SKAction.run { [weak self] in
            guard let self else { return }
            self.isRunTransitionActive = false
            self.customerSpawner.isSpawningPaused = false
            NotificationCenter.default.post(name: .newSpringDidFinish, object: nil)
        }
        // Same key as a location move: a spring during one replaces it, so its toast never fires.
        transitionVeil.run(.sequence([fadeOut, swap, fadeIn, finish]), withKey: "locationTransition")
    }

    /// Drops everything the old run left in the scene and re-applies every state-driven piece.
    /// The `lastApplied*` sentinels go back to `nil` so each `update*` pushes unconditionally.
    private func rebuildFromState() {
        customerSpawner.reset()
        for node in children where node.name == ShopCustomerSpawner.coinPopName { node.removeFromParent() }
        resetCameraToShop()

        lastAppliedMenuTier = nil
        lastAppliedStallTier = nil
        lastAppliedCookFillByMenuIndex = [:]
        lastAppliedStaff = nil
        if let tier = store?.stall.locationTier {
            applyLocationArt(tier)
            lastAppliedLocationTier = tier
        }
        updateFarm()
        updateShopMenuTier()
        updateShopStallTier()
        updateShopCookGauge()
        updateShopStaff()
    }

    /// Back to the launch framing (the default camera), clamped like any pan.
    private func resetCameraToShop() {
        lastPanLocation = nil
        tapClassifier.cancel()
        cameraNode.position = ShopNode.defaultPlacement.centroid(on: GroundLayer.grid)
        clampCameraPosition()
    }

    /// 0.95 -> 1.0 ease-out scale about the shop's own centroid (the shop
    /// node's origin is the grid origin, so scaling it directly would
    /// slide it instead).
    private func settleShop(duration: TimeInterval) {
        let center = ShopNode.defaultPlacement.centroid(on: GroundLayer.grid)
        let from: CGFloat = 0.95
        shop.run(.customAction(withDuration: duration) { node, elapsed in
            let progress = min(1, CGFloat(elapsed) / CGFloat(duration))
            let eased = 1 - (1 - progress) * (1 - progress)
            let scale = from + (1 - from) * eased
            node.setScale(scale)
            node.position = CGPoint(x: center.x * (1 - scale), y: center.y * (1 - scale))
        }, withKey: "locationSettle")
    }

    /// Menu indices with their own tap-to-cook bowl and gauge — the small
    /// bowl (0), the large bowl (1) and the daejeop bowl (2); see
    /// `ShopNode.tappedBowlMenuIndex`.
    private static let tappableMenuIndices = [0, 1, 2]

    /// A tappable bowl reads as "filled" once its cook is more than half
    /// done, and empty again the moment the portion completes and stock
    /// is credited (`cookProgress` resets toward 0 on completion) — a
    /// cooking vessel, not storage, so it does not stay full while stock
    /// exists. Both a hired cook and the manual (tap) cook drive
    /// `cookProgress`, so both fill the bowl. Applies to every menu in
    /// `tappableMenuIndices` — the small, large and daejeop bowls all have
    /// filled art.
    private static let cookFillThreshold: Double = 0.5

    /// Pushes each tappable bowl's cook progress into its own gauge, and
    /// its derived fill state into its own frame toggle, every frame —
    /// unlike a gauge's own `progress`, which changes continuously, the
    /// fill boolean flips rarely, so `lastAppliedCookFillByMenuIndex`
    /// guards it per menu the same way `updateShopMenuTier` guards the
    /// tier.
    private func updateShopCookGauge() {
        guard let store else { return }
        for menuIndex in Self.tappableMenuIndices {
            // Gauge shows only while this menu is actually cooking — a
            // manual tap session in flight, or a hired cook whose
            // auto-cook loop is currently producing (see
            // `GameStore.isCooking`) — not just because a cook is hired or
            // stock happens to be sitting there.
            let progress = store.cookProgress(menuIndex: menuIndex)
            shop.updateCookGauge(menuIndex: menuIndex, progress: progress, isVisible: store.isCooking(menuIndex: menuIndex))

            let isFilled = progress > Self.cookFillThreshold
            if isFilled != lastAppliedCookFillByMenuIndex[menuIndex] {
                shop.applyCookFill(isFilled, menuIndex: menuIndex)
                lastAppliedCookFillByMenuIndex[menuIndex] = isFilled
            }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Ground/field/farmer content itself doesn't depend on screen
        // size anymore — only how far the camera is allowed to pan does
        // (a bigger viewport needs tighter clamping, since more of the
        // world is visible at once around the camera's own position).
        clampCameraPosition()
    }

    /// Keeps `cameraNode` within `GroundLayer.worldBounds`, inset by half
    /// the current viewport on each axis — so the camera can approach the
    /// ground's edge but never scroll far enough to reveal empty space
    /// beyond the last tile. If the ground is narrower/shorter than the
    /// viewport on some axis (a small map on a big screen), that axis
    /// collapses to the ground's own center instead of an invalid range.
    private func clampCameraPosition() {
        cameraNode.position = GroundLayer.clampedCameraPosition(cameraNode.position, viewportSize: size)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = touches.first?.location(in: self)
        if let touch = touches.first {
            tapClassifier.begin(at: touch.location(in: view))
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let last = lastPanLocation else { return }
        tapClassifier.move(to: touch.location(in: view))
        let location = touch.location(in: self)
        // Dragging the finger right/up should reveal ground to the
        // left/below (the content follows the finger, standard map-drag
        // feel), so the camera moves *opposite* the drag delta.
        cameraNode.position = CGPoint(
            x: cameraNode.position.x - (location.x - last.x),
            y: cameraNode.position.y - (location.y - last.y)
        )
        clampCameraPosition()
        lastPanLocation = location
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first,
           tapClassifier.end(at: touch.location(in: view)) {
            // Within slop the camera has barely moved, so the end point
            // is the same place the finger landed.
            handleTap(at: touch.location(in: self))
        }
        lastPanLocation = nil
        tapClassifier.cancel()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = nil
        tapClassifier.cancel()
    }

    /// Accepts a tap on a tappable bowl: starts its timed manual cook and,
    /// only if that actually started one, plays the accept pulse — a tap
    /// while a cook is already running (or on a menu-tier-hidden bowl)
    /// does nothing, visibly as well as mechanically.
    private func handleTap(at location: CGPoint) {
        if let menuIndex = shop.tappedBowlMenuIndex(at: location) {
            guard store?.startManualCook(menuIndex: menuIndex) == true else { return }
            shop.pulseBowl(menuIndex: menuIndex)
            return
        }
        if let hit = fieldLayer.hit(at: fieldLayer.convert(location, from: self)) {
            handleFieldTap(hit)
        }
    }

    /// Empty plot plants, ready plot harvests (each a no-op the store
    /// refuses: too few coins, full warehouse), the add cell asks for a
    /// purchase confirmation. The pulse plays only when the store accepted.
    private func handleFieldTap(_ hit: FieldLayer.Hit) {
        guard let store else { return }
        switch hit {
        case .addPlot:
            NotificationCenter.default.post(name: .requestAddFarmPlot, object: nil)
        case .plot(let index):
            guard store.farm.plots.indices.contains(index) else { return }
            let before = store.farm.plots[index].stage
            switch before {
            case .empty: store.plantSeed(plotIndex: index)
            case .ready: store.harvest(plotIndex: index)
            case .sprout, .growing: return
            }
            guard store.farm.plots[index].stage != before else { return }
            updateFarm()
            fieldLayer.pulse(hit)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let delta = min(rawDelta, Self.maxDelta)
        lastUpdateTime = currentTime

        if let count = store?.progress.prestigeCount {
            if let last = lastSeenPrestigeCount, count != last { runNewRunTransition() }
            lastSeenPrestigeCount = count
        }
        guard !isRunTransitionActive else { return }

        updateShopMenuTier()
        updateShopStallTier()
        updateLocationTier()
        updateShopCookGauge()
        updateShopStaff()
        updateFarm()

        Task { @MainActor [weak self] in
            guard let self, let store = self.store, !self.isRunTransitionActive else { return }
            store.tick(deltaTime: delta)
            self.customerSpawner.update(delta: delta, store: store, grid: GroundLayer.grid, parent: self)
        }
    }
}
