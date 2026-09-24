import SpriteKit
import GameCore
import UIKit

extension Notification.Name {
    static let openStaffSheet = Notification.Name("openStaffSheet")
    static let openJobSheet = Notification.Name("openJobSheet")
}

final class MainStallScene: SKScene {

    weak var store: GameStore?

    private static let maxDelta: TimeInterval = 1.0 / 3.0
    private var lastUpdateTime: TimeInterval = 0
    private let groundLayer = GroundLayer()
    private let fieldLayer = FieldLayer()
    private let farmerLayer = FarmerLayer()
    private let shopWallLayer = ShopWallLayer()
    private let kitchenLayer = KitchenLayer()

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

    /// Last fill state `shop.applyCookFill` ran with. `nil` can't match a
    /// real `Bool`, so the first `updateShopCookGauge()` call always
    /// applies — same reasoning as `lastAppliedMenuTier`. Unlike the
    /// gauge's own `progress`, which changes continuously and pushes every
    /// frame, this flips rarely (crossing the 0.5 threshold), so it's
    /// worth guarding rather than assigning `isHidden` on two nodes every
    /// frame for no visible change.
    private var lastAppliedCookFill: Bool?

    /// Pans the world; `GroundLayer.worldBounds` clamps how far (see
    /// `clampCameraPosition()`) — "the map data" (`GroundLayer.map` plus
    /// its margin) is what actually limits the scrollable area, not the
    /// device screen.
    private let cameraNode = SKCameraNode()

    /// Set on `touchesBegan`, cleared on `touchesEnded`/`touchesCancelled`
    /// — `nil` means no active drag, so `touchesMoved` has nothing to
    /// diff against yet (the first move after a touch begins establishes
    /// the baseline rather than jumping the camera).
    private var lastPanLocation: CGPoint?

    /// The touch's location when it began — unlike `lastPanLocation`,
    /// which chases the finger on every move, this stays put so
    /// `touchesEnded` can measure the touch's *total* travel and tell a
    /// tap from a pan, even though the same touch drives both.
    private var touchStartLocation: CGPoint?

    /// Below this much total movement, a touch counts as a tap rather
    /// than a pan — small enough not to swallow real drags, large enough
    /// to absorb a finger's natural wobble while resting on the glass.
    private static let tapSlop: CGFloat = 10

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor

        camera = cameraNode
        addChild(cameraNode)
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

        // GroundLayer/FieldLayer/FarmerLayer all draw once, in fixed world
        // space — no `size` argument anymore, and no need to call again on
        // resize (only the camera's clamp bounds depend on screen size,
        // handled in didChangeSize below).
        addChild(groundLayer)
        groundLayer.layout()

        // FieldLayer/FarmerLayer are ported onto GroundLayer's IsoGrid (see
        // FieldLayerNode.swift/FarmerNode.swift) and restored here.
        // ShopWallLayer/KitchenLayer stay disabled — their art hasn't been
        // redone for the new isometric style yet, so adding them now would
        // sit a placeholder building next to the new watercolor ground.
        fieldLayer.zPosition = 10
        addChild(fieldLayer)
        fieldLayer.layout()

        // Same base zPosition as fieldLayer so FarmerLayer's local row-based zPosition
        // (see FarmerLayer.layout) compares directly against FieldLayer's plot zPositions.
        farmerLayer.zPosition = 10
        addChild(farmerLayer)
        farmerLayer.layout()

        // shopWallLayer.zPosition = 10
        // addChild(shopWallLayer)
        // shopWallLayer.layout(for: frame.size)
        //
        // kitchenLayer.zPosition = 10
        // addChild(kitchenLayer)
        // kitchenLayer.layout(for: frame.size)

        addChild(shop)
        updateShopMenuTier()
        updateShopCookGauge()

        clampCameraPosition()
    }

    /// Toggles the prep table's items for `store.stall.menuTier`, only
    /// when it actually changed — avoids poking `isHidden` every frame.
    private func updateShopMenuTier() {
        guard let tier = store?.stall.menuTier, tier != lastAppliedMenuTier else { return }
        shop.applyMenuTier(tier)
        lastAppliedMenuTier = tier
    }

    /// The small bowl reads as "filled" once a cook is more than half
    /// done, and empty again the moment the portion completes and stock
    /// is credited (`cookProgress` resets toward 0 on completion) — a
    /// cooking vessel, not storage, so it does not stay full while stock
    /// exists. Both a hired cook and the manual (tap) cook drive
    /// `cookProgress`, so both fill the bowl.
    private static let cookFillThreshold: Double = 0.5

    /// Pushes menu-0 cook progress into the small-bowl gauge every frame,
    /// and the derived fill state into the small bowl's frame toggle —
    /// unlike the gauge's own `progress`, which changes continuously, the
    /// fill boolean flips rarely, so `lastAppliedCookFill` guards it the
    /// same way `updateShopMenuTier` guards the tier.
    private func updateShopCookGauge() {
        guard let store else { return }
        // Gauge shows only while menu 0 is actually cooking — a manual tap
        // session in flight, or a hired cook whose auto-cook loop is
        // currently producing (see `GameStore.isCooking`) — not just
        // because a cook is hired or stock happens to be sitting there.
        let progress = store.cookProgress(menuIndex: 0)
        shop.updateCookGauge(progress: progress, isVisible: store.isCooking(menuIndex: 0))

        let isFilled = progress > Self.cookFillThreshold
        if isFilled != lastAppliedCookFill {
            shop.applyCookFill(isFilled)
            lastAppliedCookFill = isFilled
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
        let location = touches.first?.location(in: self)
        lastPanLocation = location
        touchStartLocation = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let last = lastPanLocation else { return }
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
        if let touch = touches.first, let start = touchStartLocation {
            let location = touch.location(in: self)
            let dx = location.x - start.x
            let dy = location.y - start.y
            if dx * dx + dy * dy <= Self.tapSlop * Self.tapSlop {
                handleTap(at: location)
            }
        }
        lastPanLocation = nil
        touchStartLocation = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanLocation = nil
        touchStartLocation = nil
    }

    /// Accepts a tap on the small bowl (menu index 0): starts its timed
    /// manual cook and, only if that actually started one, plays the
    /// accept pulse — a tap while a cook is already running does nothing,
    /// visibly as well as mechanically.
    private func handleTap(at location: CGPoint) {
        guard shop.smallBowlContains(location) else { return }
        guard store?.startManualCook(menuIndex: 0) == true else { return }
        shop.pulseSmallBowl()
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let delta = min(rawDelta, Self.maxDelta)
        lastUpdateTime = currentTime

        updateShopMenuTier()
        updateShopCookGauge()

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            store.tick(deltaTime: delta)
        }
    }
}
