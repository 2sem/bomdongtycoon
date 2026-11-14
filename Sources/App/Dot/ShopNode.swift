import SpriteKit
import GameCore

/// The shop band: tier building, staff between its back and front layers, dishes with stock
/// counts and cook progress bars on the counter.
/// Layers: back 0, staff 1, front 2, dishes 3, bars and labels 4, fever flames 5.
@MainActor
final class ShopNode: BandNode {

    private static let dishX: [CGFloat] = [30, 63, 96]
    private static let dishY: CGFloat = 50
    private static let cookX: [CGFloat] = [15, 48, 81]
    private static let cashierSlot = CGPoint(x: 118, y: 49)
    private static let dishNames = ["geotjeori", "kimchi", "bibimbap"]
    private static let kinds = [1: "alba", 2: "imo", 3: "chef"]

    /// Cash till on the counter; the manifest draws it at x 128-137.
    static let tillPoint = CGPoint(x: 132, y: 46)

    private struct Snapshot: Equatable {
        var stallTier = 0, menuTier = 0, cashierCount = 0, cashierTier = 0
        var cooks: [Int] = [], stock: [Int] = [], cooking: [Bool] = [], tired: [Bool] = [], barPx: [Int] = []
        var cashierTired = false, cashierWorking = false, fever = false
    }

    @MainActor
    private final class DishSlot {
        let dish = dotSprite("dot_dish_empty_bowl")
        let pot = dotSprite("dot_dish_pot_0")
        let lock = dotSprite("dot_ui_lock", anchor: .pixel(8, 8))
        let barFrame = dotSprite("dot_ui_bar_frame", anchor: .topLeft)
        let barFill = dotSprite("dot_ui_bar_fill", anchor: .topLeft)
        let count: PixelLabel
        let cook = StaffFigure()
        var dishName = ""
        init(scale: CGFloat) { count = PixelLabel(style: .tiny, scale: scale, alignment: .left) }
    }

    private let scale: CGFloat
    private let back = dotSprite("dot_shop_tier0_back", anchor: .bottomLeft)
    private let front = dotSprite("dot_shop_tier0_front", anchor: .bottomLeft)
    private let cashier = StaffFigure()
    private var slots: [DishSlot] = []
    private var flames: [SKSpriteNode] = []
    private var last: Snapshot?
    private var lastStock: [Int]?

    /// `labelLayer` sits above the day tint so stock counts do not darken at night.
    init(layout: DotWorldLayout, labelLayer: SKNode) {
        scale = layout.scale
        super.init(top: layout.shopTop)
        zPosition = 100
        let bottom = -CGFloat(DotWorldLayout.shopHeight)
        back.position = CGPoint(x: 0, y: bottom)
        front.position = CGPoint(x: 0, y: bottom)
        front.zPosition = 2
        addChild(back)
        addChild(front)
        let staffLayer = SKNode(); staffLayer.zPosition = 1; addChild(staffLayer)
        let dishLayer = SKNode(); dishLayer.zPosition = 3; addChild(dishLayer)
        let barLayer = SKNode(); barLayer.zPosition = 4; addChild(barLayer)
        let flameLayer = SKNode(); flameLayer.zPosition = 5; addChild(flameLayer)

        staffLayer.addChild(cashier)
        cashier.position = feetPoint(Self.cashierSlot.x, Self.cashierSlot.y)

        for i in 0..<3 {
            let slot = DishSlot(scale: scale)
            let x = Self.dishX[i]
            slot.dish.position = feetPoint(x, Self.dishY)
            slot.pot.position = slot.dish.position
            slot.pot.run(.repeatForever(.animate(with: DotTexture.frames("dot_dish_pot", count: 2),
                                                 timePerFrame: 0.3, resize: false, restore: false)))
            slot.lock.position = feetPoint(x, 43)
            slot.barFrame.centerRect = CGRect(x: 3 / 16, y: 3 / 8, width: 10 / 16, height: 2 / 8)
            slot.barFrame.size = CGSize(width: 20, height: 8)
            slot.barFrame.position = artPoint(x - 10, 54)
            slot.barFill.centerRect = CGRect(x: 1 / 6, y: 1 / 4, width: 4 / 6, height: 2 / 4)
            slot.barFill.position = CGPoint(x: 2, y: -2)
            slot.barFill.zPosition = 0.1
            slot.barFrame.addChild(slot.barFill)
            slot.count.position = rootPoint(x + 13, 61)
            slot.cook.position = feetPoint(Self.cookX[i], 49)

            staffLayer.addChild(slot.cook)
            dishLayer.addChild(slot.dish)
            dishLayer.addChild(slot.pot)
            dishLayer.addChild(slot.lock)
            barLayer.addChild(slot.barFrame)
            labelLayer.addChild(slot.count)
            slots.append(slot)
        }

        for (i, x) in [CGFloat(8), 136].enumerated() {
            let flame = dotSprite("dot_fx_fever_flame_0")
            flame.position = feetPoint(x, 63)
            flame.alpha = 0
            flame.run(.repeatForever(.animate(with: DotTexture.frames("dot_fx_fever_flame", count: 2),
                                              timePerFrame: 0.12 + Double(i) * 0.02, resize: false, restore: false)))
            flameLayer.addChild(flame)
            flames.append(flame)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Geometry

    func dishPoint(_ menu: Int) -> CGPoint { rootPoint(Self.dishX[menu], Self.dishY - 8) }
    var tillRootPoint: CGPoint { rootPoint(Self.tillPoint.x, Self.tillPoint.y) }

    /// Index of the dish whose counter spot contains `p` (band-local art coordinates).
    func menuIndex(atLocal p: CGPoint) -> Int? {
        guard p.y >= 28, p.y < CGFloat(DotWorldLayout.shopHeight) else { return nil }
        return Self.dishX.firstIndex { abs(p.x - $0) <= 15 }
    }

    func pulse(menu: Int, reduceMotion: Bool) {
        FXLayer.squash(slots[menu].dish, reduceMotion: reduceMotion)
        FXLayer.squash(slots[menu].pot, reduceMotion: reduceMotion)
    }

    func shakeLock(menu: Int, reduceMotion: Bool) {
        FXLayer.shake(slots[menu].lock, reduceMotion: reduceMotion)
    }

    // MARK: State

    /// Pushes store state into nodes, touching them only when the derived snapshot changed.
    /// Returns the menus whose stock just went up (a dish finished cooking).
    @discardableResult
    func apply(store: GameStore, reduceMotion: Bool) -> [Int] {
        let snapshot = makeSnapshot(store)
        var finished: [Int] = []
        if let previous = lastStock {
            for i in snapshot.stock.indices where snapshot.stock[i] > previous[i] { finished.append(i) }
        }
        lastStock = snapshot.stock
        guard snapshot != last else { return finished }
        let tierChanged = last?.stallTier != snapshot.stallTier
        last = snapshot

        if tierChanged {
            let tier = min(max(snapshot.stallTier, 0), 2)
            back.texture = DotTexture.named("dot_shop_tier\(tier)_back")
            front.texture = DotTexture.named("dot_shop_tier\(tier)_front")
        }
        let bobs = !reduceMotion
        for (i, slot) in slots.enumerated() {
            let unlocked = i <= snapshot.menuTier
            slot.lock.isHidden = unlocked
            slot.dish.isHidden = !unlocked
            slot.count.isHidden = !unlocked
            slot.pot.isHidden = !(unlocked && snapshot.cooking[i] && snapshot.stock[i] == 0)
            slot.barFrame.isHidden = !(unlocked && snapshot.cooking[i])
            if unlocked {
                let name = snapshot.stock[i] > 0 ? "dot_dish_\(Self.dishNames[i])" : "dot_dish_empty_bowl"
                if name != slot.dishName {
                    slot.dishName = name
                    slot.dish.texture = DotTexture.named(name)
                }
                slot.count.text = "\(snapshot.stock[i])"
                slot.barFill.isHidden = snapshot.barPx[i] == 0
                slot.barFill.size = CGSize(width: CGFloat(max(snapshot.barPx[i], 2)), height: 4)
            }
            let kind = unlocked ? Self.kinds[snapshot.cooks[i]] : nil
            slot.cook.configure(kind: kind, pose: pose(working: snapshot.cooking[i], tired: snapshot.tired[i]),
                                isTired: snapshot.tired[i], bobs: bobs, fast: snapshot.fever)
        }
        let cashierKind = snapshot.cashierCount > 0 ? (Self.kinds[snapshot.cashierTier] ?? "alba") : nil
        cashier.configure(kind: cashierKind,
                          pose: pose(working: snapshot.cashierWorking, tired: snapshot.cashierTired),
                          isTired: snapshot.cashierTired, bobs: bobs, fast: snapshot.fever)
        for flame in flames {
            flame.run(.fadeAlpha(to: snapshot.fever ? 1 : 0, duration: 0.3), withKey: "fade")
        }
        return finished
    }

    private func pose(working: Bool, tired: Bool) -> StaffFigure.Pose {
        working ? .work : (tired ? .tired : .idle)
    }

    private func makeSnapshot(_ store: GameStore) -> Snapshot {
        let stall = store.stall
        var s = Snapshot()
        s.stallTier = stall.stallTier
        s.menuTier = stall.menuTier
        s.cashierCount = stall.cashierCount
        s.cashierTier = stall.cashierTier
        s.fever = store.isFeverActive
        s.cashierTired = stall.cashierEnergy < ShopStaffPresence.lowEnergyThreshold
        s.cashierWorking = store.cashierRecentlySold
        for i in 0..<3 {
            s.cooks.append(stall.menuCooks[i])
            s.stock.append(stall.menuStock[i])
            let cooking = store.isCooking(menuIndex: i)
            s.cooking.append(cooking)
            s.tired.append(stall.menuCooks[i] > 0 && stall.menuCookEnergy[i] < ShopStaffPresence.lowEnergyThreshold)
            let progress = store.cookProgress(menuIndex: i)
            s.barPx.append(cooking ? Int((progress * 16).rounded()) : 0)
        }
        return s
    }
}
