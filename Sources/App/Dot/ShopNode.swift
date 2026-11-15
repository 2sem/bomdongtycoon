import SpriteKit
import GameCore

/// The shop band: tier building, staff between its back and front layers, dishes with stock
/// counts and cook progress bars on the counter.
/// Layers: back 0, name board 0.5, staff 1, front 2, dishes 3, bars and labels 4, fever flames 5.
@MainActor
final class ShopNode: BandNode {

    private static let dishX: [CGFloat] = [30, 63, 96]
    private static let dishY: CGFloat = 50
    /// Stock badge baseline, in band-local art px: right of the bowl's rim and above the bubbles' top (y 44).
    private static let badgeDX: CGFloat = 6
    private static let badgeY: CGFloat = 40
    private static let cookX: [CGFloat] = [15, 48, 81]
    private static let cashierSlot = CGPoint(x: 118, y: 49)
    private static let dishNames = ["geotjeori", "kimchi", "bibimbap"]
    private static let kinds = [1: "alba", 2: "imo", 3: "chef"]

    /// Cash till on the counter; the manifest draws it at x 128-137.
    static let tillPoint = CGPoint(x: 132, y: 46)

    /// Free text area of each tier's roof signboard in the shop image (x, y, w, h; y down),
    /// measured in tools/dotart/MANIFEST.md, section "Shop name board".
    private static let nameBoards: [CGRect] = [
        CGRect(x: 40, y: 5, width: 64, height: 10),
        CGRect(x: 38, y: 8, width: 68, height: 12),
        CGRect(x: 35, y: 3, width: 74, height: 16),
    ]

    /// The largest style whose ink box fits `area`, trying bold, small, then tiny; if even tiny is too
    /// wide, characters are cut from the end and "…" appended until it fits.
    static func fitName(_ name: String, in area: CGSize,
                        measure: (String, PixelLabel.Style) -> PixelLabel.Measure = PixelLabel.measure)
        -> (text: String, style: PixelLabel.Style, measure: PixelLabel.Measure) {
        func fits(_ m: PixelLabel.Measure) -> Bool { CGFloat(m.width) <= area.width && CGFloat(m.height) <= area.height }
        for style in [PixelLabel.Style.bold, .small, .tiny] {
            let m = measure(name, style)
            if fits(m) { return (name, style, m) }
        }
        var kept = Array(name)
        while !kept.isEmpty {
            kept.removeLast()
            let text = String(kept) + "…"
            let m = measure(text, .tiny)
            if fits(m) { return (text, .tiny, m) }
        }
        return ("", .tiny, PixelLabel.Measure())
    }

    private struct Snapshot: Equatable {
        var shopName = ""
        var stallTier = 0, menuTier = 0, cashierCount = 0, cashierTier = 0
        var cooks: [Int] = [], stock: [Int] = [], cooking: [Bool] = [], resting: [Bool] = [], barPx: [Int] = []
        var cashierResting = false, cashierWorking = false, fever = false
    }

    @MainActor
    private final class DishSlot {
        let dish = dotSprite("dot_dish_empty_bowl")
        let pot = dotSprite("dot_dish_pot_0")
        let lock = dotSprite("dot_ui_lock", anchor: .pixel(8, 8))
        let barFrame = dotSprite("dot_ui_bar_frame", anchor: .topLeft)
        let barFill = dotSprite("dot_ui_bar_fill", anchor: .topLeft)
        let count: PixelLabel
        /// Ink plate behind the stock count; sized to the digits in `apply`.
        let plate = SKSpriteNode(color: SKColor(hex: 0x2b1b2e), size: CGSize(width: 8, height: 10))
        let cook = StaffFigure()
        var dishName = ""
        init(scale: CGFloat) { count = PixelLabel(style: .tiny, scale: scale, alignment: .left) }
    }

    private let scale: CGFloat
    private let back = dotSprite("dot_shop_tier0_back", anchor: .bottomLeft)
    private let front = dotSprite("dot_shop_tier0_front", anchor: .bottomLeft)
    private let nameLabel = PixelLabel(style: .small, color: SKColor(hex: 0x2b1b2e), shadowColor: nil, alignment: .left)
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
        nameLabel.zPosition = 0.5
        addChild(nameLabel)
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
            // Stock badge at the dish's upper right on the back wall: customers' order bubbles and the
            // "+N" pops live over the counter front below it, so nothing ever overlaps the number.
            let badge = rootPoint(x + Self.badgeDX, Self.badgeY)
            slot.plate.anchorPoint = CGPoint(x: 0, y: 0)
            slot.plate.alpha = 0.8
            slot.plate.position = CGPoint(x: badge.x - 1, y: badge.y - 2)
            slot.count.position = badge
            slot.cook.position = feetPoint(Self.cookX[i], 49)

            staffLayer.addChild(slot.cook)
            dishLayer.addChild(slot.dish)
            dishLayer.addChild(slot.pot)
            dishLayer.addChild(slot.lock)
            barLayer.addChild(slot.barFrame)
            labelLayer.addChild(slot.plate)
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

    /// The post a tap at `p` (band-local art px) lands on: a cook's or the cashier's figure. The caller
    /// decides whether that worker is asleep, so the tap can hurry the nap.
    func workerTarget(atLocal p: CGPoint) -> GameStore.WorkerTarget? {
        guard p.y >= 24, p.y < 52 else { return nil }
        if abs(p.x - Self.cashierSlot.x) <= 9 { return .cashier }
        guard let i = Self.cookX.firstIndex(where: { abs(p.x - $0) <= 9 }) else { return nil }
        return .cook(menuIndex: i)
    }

    /// Head height of a worker's figure, for the heart that rises when they are woken.
    func headPoint(of target: GameStore.WorkerTarget) -> CGPoint {
        switch target {
        case .cook(let i): return rootPoint(Self.cookX[i], Self.cashierSlot.y - 26)
        case .cashier, .farm: return rootPoint(Self.cashierSlot.x, Self.cashierSlot.y - 26)
        }
    }

    func bump(worker target: GameStore.WorkerTarget, reduceMotion: Bool) {
        switch target {
        case .cook(let i): FXLayer.squash(slots[i].cook, reduceMotion: reduceMotion)
        case .cashier: FXLayer.squash(cashier, reduceMotion: reduceMotion)
        case .farm: break
        }
    }

    func pulse(menu: Int, reduceMotion: Bool) {
        FXLayer.squash(slots[menu].dish, reduceMotion: reduceMotion)
        FXLayer.squash(slots[menu].pot, reduceMotion: reduceMotion)
    }

    /// Tip of the first-run pointer: just above the dish's rim.
    func hintTip(_ menu: Int) -> CGPoint { rootPoint(Self.dishX[menu], Self.dishY - 10) }

    func shakeDish(menu: Int, reduceMotion: Bool) {
        FXLayer.shake(slots[menu].dish, reduceMotion: reduceMotion)
        FXLayer.shake(slots[menu].pot, reduceMotion: reduceMotion)
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
        let nameChanged = tierChanged || last?.shopName != snapshot.shopName
        last = snapshot

        if tierChanged {
            let tier = min(max(snapshot.stallTier, 0), 2)
            back.texture = DotTexture.named("dot_shop_tier\(tier)_back")
            front.texture = DotTexture.named("dot_shop_tier\(tier)_front")
        }
        if nameChanged { placeName(snapshot.shopName, tier: min(max(snapshot.stallTier, 0), 2)) }
        let bobs = !reduceMotion
        for (i, slot) in slots.enumerated() {
            let unlocked = i <= snapshot.menuTier
            slot.lock.isHidden = unlocked
            slot.dish.isHidden = !unlocked
            slot.count.isHidden = !unlocked
            slot.plate.isHidden = !unlocked
            slot.pot.isHidden = !(unlocked && snapshot.cooking[i] && snapshot.stock[i] == 0)
            slot.barFrame.isHidden = !(unlocked && snapshot.cooking[i])
            if unlocked {
                let name = snapshot.stock[i] > 0 ? "dot_dish_\(Self.dishNames[i])" : "dot_dish_empty_bowl"
                if name != slot.dishName {
                    slot.dishName = name
                    slot.dish.texture = DotTexture.named(name)
                }
                slot.count.text = "\(snapshot.stock[i])"
                slot.plate.size.width = CGFloat(String(snapshot.stock[i]).count * 5 + 2)
                slot.barFill.isHidden = snapshot.barPx[i] == 0
                slot.barFill.size = CGSize(width: CGFloat(max(snapshot.barPx[i], 2)), height: 4)
            }
            let kind = unlocked ? Self.kinds[snapshot.cooks[i]] : nil
            slot.cook.configure(kind: kind, pose: pose(working: snapshot.cooking[i], resting: snapshot.resting[i]),
                                isResting: snapshot.resting[i], bobs: bobs, fast: snapshot.fever)
        }
        let cashierKind = snapshot.cashierCount > 0 ? (Self.kinds[snapshot.cashierTier] ?? "alba") : nil
        cashier.configure(kind: cashierKind,
                          pose: pose(working: snapshot.cashierWorking, resting: snapshot.cashierResting),
                          isResting: snapshot.cashierResting, bobs: bobs, fast: snapshot.fever)
        for flame in flames {
            flame.run(.fadeAlpha(to: snapshot.fever ? 1 : 0, duration: 0.3), withKey: "fade")
        }
        return finished
    }

    private func placeName(_ name: String, tier: Int) {
        let board = Self.nameBoards[tier]
        let fit = Self.fitName(name, in: board.size)
        nameLabel.style = fit.style
        nameLabel.text = fit.text
        let m = fit.measure
        let inkX = board.minX + ((board.width - CGFloat(m.width)) / 2).rounded(.down)
        let inkY = board.minY + ((board.height - CGFloat(m.height)) / 2).rounded(.down)
        nameLabel.position = artPoint(inkX - CGFloat(m.left), inkY + CGFloat(m.ascent))
    }

    private func pose(working: Bool, resting: Bool) -> StaffFigure.Pose {
        resting ? .tired : (working ? .work : .idle)
    }

    private func makeSnapshot(_ store: GameStore) -> Snapshot {
        let stall = store.stall
        var s = Snapshot()
        s.shopName = store.progress.shopName
        s.stallTier = stall.stallTier
        s.menuTier = stall.menuTier
        s.cashierCount = stall.cashierCount
        s.cashierTier = stall.cashierTier
        s.fever = store.isFeverActive
        s.cashierResting = store.isResting(.cashier)
        s.cashierWorking = store.cashierRecentlySold
        for i in 0..<3 {
            s.cooks.append(stall.menuCooks[i])
            s.stock.append(stall.menuStock[i])
            let cooking = store.isCooking(menuIndex: i)
            s.cooking.append(cooking)
            s.resting.append(store.isResting(.cook(menuIndex: i)))
            let progress = store.cookProgress(menuIndex: i)
            s.barPx.append(cooking ? Int((progress * 16).rounded()) : 0)
        }
        return s
    }
}
