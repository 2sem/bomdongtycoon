import SpriteKit
import GameCore

/// Spawns, walks and serves street customers. Serve semantics are the store's: sell at once if
/// the dish is in stock, otherwise poll every 0.5 s for up to 12 s, then give up.
@MainActor
final class CustomerDirector {

    struct ServeEvent {
        let headPoint: CGPoint      // root space
        let price: Double
        let isGourmet: Bool
        let footPoint: CGPoint      // root space, on the ground where a tip coin can lie
    }

    private enum Phase { case walkingIn, ordering, waiting, reacting, walkingOut }

    private final class Session {
        let node: CustomerNode
        let slot: Int
        let menu: Int
        let isGourmet: Bool
        var position: CGPoint        // band-local art px: x, feet row
        var path: [CGPoint]
        var phase: Phase = .walkingIn
        var waited: TimeInterval = 0
        var pollTimer: TimeInterval = 0
        var reactTimer: TimeInterval = 0
        var sparkleTimer: TimeInterval = 0
        init(node: CustomerNode, slot: Int, menu: Int, isGourmet: Bool, position: CGPoint, path: [CGPoint]) {
            self.node = node; self.slot = slot; self.menu = menu
            self.isGourmet = isGourmet; self.position = position; self.path = path
        }
    }

    /// Five queue places 27 px apart: a bubble is ~21 px wide, so neighbours never overlap. Normal
    /// play fills the middle three; fever opens the outer two.
    static let slotX: [CGFloat] = [20, 47, 74, 101, 128]
    private static let slotOrder = [2, 1, 3, 0, 4]
    /// Feet row of a queued customer and of the lane walkers use, in front of them (band-local).
    /// The yard's bushes and crate reach up to street row 29, so feet stay clear of that.
    private static let queueRow: CGFloat = 25
    private static let laneRow: CGFloat = 28
    /// Where a tip coin lies: just in front of the queue, under the lane.
    private static let tipRow: CGFloat = 30
    private static let maxConcurrent = 3
    private static let maxConcurrentFever = 5
    private static let pollInterval: TimeInterval = 0.5
    private static let basePatience: TimeInterval = 12
    private static let reactionPause: TimeInterval = 0.6
    /// Bubble shows this long on arrival before the first sale attempt, so an order is always seen.
    private static let orderingPause: TimeInterval = 0.7
    private static let looks = ["man", "woman", "kid_boy", "kid_girl", "elder_man", "elder_woman"]
    private static let dishNames = ["geotjeori", "kimchi", "bibimbap"]

    private let street: BandNode
    private let layer = SKNode()
    private let leftExit: CGFloat
    private let rightEntry: CGFloat
    private var sessions: [Session] = []
    private var spawnTimer: TimeInterval = 1
    var isSpawningPaused = false
    /// A game sheet or alert is up: queued customers stop losing patience and nobody new arrives.
    var isHeld = false

    var onServed: ((ServeEvent) -> Void)?
    var onFailed: ((CGPoint) -> Void)?
    var onSparkle: ((CGPoint) -> Void)?

    init(street: BandNode, layout: DotWorldLayout) {
        self.street = street
        leftExit = layout.leftEdge - 16
        rightEntry = layout.rightEdge + 16
        street.addChild(layer)
    }

    func reset() {
        for session in sessions { session.node.removeFromParent() }
        sessions.removeAll()
        spawnTimer = 1
    }

    func update(delta: TimeInterval, store: GameStore, isFever: Bool, reduceMotion: Bool) {
        guard store.progress.isShopNameSet, !store.isSimulationPaused else { return }
        if store.hasFlyerRequest { answerFlyer(store: store, isFever: isFever) }
        if !isSpawningPaused, !isHeld {
            spawnTimer -= delta
            if spawnTimer <= 0 { trySpawn(store: store, isFever: isFever) }
        }
        let speed: CGFloat = (isFever ? 56 : 30) * CGFloat(store.customerWalkSpeedMultiplier)
        for session in sessions {
            advance(session, delta: delta, speed: speed, store: store)
        }
        sessions.removeAll { $0.node.parent == nil }
    }

    private func hasRoom(isFever: Bool) -> Bool {
        sessions.count < (isFever ? Self.maxConcurrentFever : Self.maxConcurrent)
    }

    private func trySpawn(store: GameStore, isFever: Bool) {
        guard hasRoom(isFever: isFever) else { spawnTimer = 1; return }
        spawn(store: store)
    }

    /// A flyer tap brings one customer in now and restarts the natural timer (`spawn` does), so the
    /// tap never adds to the pace: a full queue or a held street turns it down without a cooldown.
    private func answerFlyer(store: GameStore, isFever: Bool) {
        guard !isSpawningPaused, !isHeld, hasRoom(isFever: isFever) else { store.declineFlyer(); return }
        guard store.completeFlyer() else { return }
        spawn(store: store)
    }

    private func spawn(store: GameStore) {
        let menu = store.rollOrderedMenu()
        let isGourmet = store.rollGourmet()
        let base = isGourmet ? "gourmet" : (Self.looks.randomElement() ?? "man")
        let look = Self.outfit(base, weather: store.weather)
        let node = CustomerNode(look: look, wantedDish: "dot_dish_\(Self.dishNames[menu])")
        let held = Set(sessions.map(\.slot))
        let slot = Self.slotOrder.first { !held.contains($0) } ?? 0
        let start = CGPoint(x: rightEntry, y: Self.laneRow)
        let session = Session(node: node, slot: slot, menu: menu, isGourmet: isGourmet, position: start,
                              path: [CGPoint(x: Self.slotX[slot], y: Self.laneRow),
                                     CGPoint(x: Self.slotX[slot], y: Self.queueRow)])
        render(session)
        layer.addChild(node)
        sessions.append(session)
        let interval = store.customerSpawnInterval
        spawnTimer = TimeInterval.random(in: (interval * 0.9)...(interval * 1.1))
    }

    /// The weather's outfit, worn from spawn to exit even if the weather ends meanwhile.
    private static func outfit(_ look: String, weather: Weather) -> String {
        switch weather {
        case .clear:  return look
        case .rain:   return look + "_rain"
        case .snow:   return look + "_snow"
        case .leaves: return look + "_leaves"
        case .petals: return look + "_petals"
        }
    }

    private func advance(_ s: Session, delta: TimeInterval, speed: CGFloat, store: GameStore) {
        switch s.phase {
        case .walkingIn:
            if walk(s, delta: delta, speed: speed) {
                s.node.showBack()
                s.node.setBubbleVisible(true)
                s.phase = .ordering
                s.reactTimer = Self.orderingPause
            }
        case .ordering:
            s.reactTimer -= delta
            if s.reactTimer <= 0 { beginServing(s, store: store) }
        case .waiting:
            s.node.showBack()
            if !isHeld { s.waited += delta }
            s.pollTimer += delta
            guard s.pollTimer >= Self.pollInterval else { return }
            s.pollTimer = 0
            if let price = store.sellItem(menuIndex: s.menu, isGourmet: s.isGourmet) {
                store.recordServed(waitTime: s.waited, isGourmet: s.isGourmet)
                finishServed(s, price: price)
            } else if s.waited >= Self.basePatience * store.customerPatienceMultiplier {
                store.recordFailed(isGourmet: s.isGourmet)
                s.node.setBubbleVisible(false)
                s.node.showFront()
                onFailed?(headPoint(s))
                startReaction(s)
            } else {
                store.requestSelfServe(menuIndex: s.menu)
            }
        case .reacting:
            s.reactTimer -= delta
            if s.reactTimer <= 0 {
                s.phase = .walkingOut
                s.path = [CGPoint(x: s.position.x, y: Self.laneRow), CGPoint(x: leftExit, y: Self.laneRow)]
            }
        case .walkingOut:
            if walk(s, delta: delta, speed: speed) { s.node.removeFromParent() }
        }
        if s.isGourmet, s.phase == .walkingIn || s.phase == .walkingOut {
            s.sparkleTimer -= delta
            if s.sparkleTimer <= 0 {
                s.sparkleTimer = 0.25
                onSparkle?(street.rootPoint(s.position.x.rounded(), s.position.y.rounded() - 6))
            }
        }
    }

    private func beginServing(_ s: Session, store: GameStore) {
        if let price = store.sellItem(menuIndex: s.menu, isGourmet: s.isGourmet) {
            store.recordServed(waitTime: 0, isGourmet: s.isGourmet)
            finishServed(s, price: price)
        } else {
            s.phase = .waiting
            store.requestSelfServe(menuIndex: s.menu)
        }
    }

    private func finishServed(_ s: Session, price: Double) {
        s.node.setBubbleVisible(false)
        s.node.showFront()
        onServed?(ServeEvent(headPoint: headPoint(s), price: price, isGourmet: s.isGourmet,
                             footPoint: street.rootPoint(s.position.x.rounded(), Self.tipRow)))
        startReaction(s)
    }

    private func startReaction(_ s: Session) {
        s.phase = .reacting
        s.reactTimer = Self.reactionPause
    }

    private func headPoint(_ s: Session) -> CGPoint {
        street.rootPoint(s.position.x.rounded(), s.position.y.rounded() - 25)
    }

    /// Moves towards the next path point; true once the path is exhausted.
    private func walk(_ s: Session, delta: TimeInterval, speed: CGFloat) -> Bool {
        guard let target = s.path.first else { return true }
        let dx = target.x - s.position.x
        let dy = target.y - s.position.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let step = speed * CGFloat(delta)
        if distance <= step {
            s.position = target
            s.path.removeFirst()
            render(s)
            return s.path.isEmpty
        }
        s.position.x += dx / distance * step
        s.position.y += dy / distance * step
        let facing: CustomerNode.Facing = abs(dx) >= abs(dy) ? (dx < 0 ? .left : .right) : (dy < 0 ? .up : .down)
        s.node.walk(facing: facing, delta: delta)
        render(s)
        return false
    }

    private func render(_ s: Session) {
        let row = s.position.y.rounded()
        s.node.position = feetPoint(s.position.x.rounded(), row)
        s.node.zPosition = row / 100
    }
}
