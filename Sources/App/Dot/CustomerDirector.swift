import SpriteKit
import GameCore

/// Spawns, walks and serves street customers. Serve semantics are the store's: sell at once if
/// the dish is in stock, otherwise poll every 0.5 s for up to 8 s, then give up.
@MainActor
final class CustomerDirector {

    struct ServeEvent {
        let headPoint: CGPoint      // root space
        let price: Double
        let isGourmet: Bool
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

    static let slotX: [CGFloat] = [46, 80, 113]
    /// Feet row of a queued customer and of the lane walkers use, in front of them (band-local).
    /// The yard's bushes and crate reach up to street row 29, so feet stay clear of that.
    private static let queueRow: CGFloat = 25
    private static let laneRow: CGFloat = 28
    private static let maxConcurrent = 3
    private static let pollInterval: TimeInterval = 0.5
    private static let maxWait: TimeInterval = 8
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
        if !isSpawningPaused {
            spawnTimer -= delta
            if spawnTimer <= 0 { trySpawn(store: store) }
        }
        let speed: CGFloat = isFever ? 46 : 30
        for session in sessions {
            advance(session, delta: delta, speed: speed, store: store)
        }
        sessions.removeAll { $0.node.parent == nil }
    }

    private func trySpawn(store: GameStore) {
        guard sessions.count < Self.maxConcurrent else { spawnTimer = 1; return }
        let menu = (0...store.stall.menuTier).randomElement() ?? 0
        let isGourmet = store.rollGourmet()
        let look = isGourmet ? "gourmet" : (Self.looks.randomElement() ?? "man")
        let node = CustomerNode(look: look, wantedDish: "dot_dish_\(Self.dishNames[menu])")
        let held = Set(sessions.map(\.slot))
        let slot = (0..<Self.maxConcurrent).first { !held.contains($0) } ?? 0
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
            s.waited += delta
            s.pollTimer += delta
            guard s.pollTimer >= Self.pollInterval else { return }
            s.pollTimer = 0
            if let price = store.sellItem(menuIndex: s.menu, isGourmet: s.isGourmet) {
                store.recordServed(waitTime: s.waited, isGourmet: s.isGourmet)
                finishServed(s, price: price)
            } else if s.waited >= Self.maxWait {
                store.recordFailed(isGourmet: s.isGourmet)
                s.node.setBubbleVisible(false)
                s.node.showFront()
                onFailed?(headPoint(s))
                startReaction(s)
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
        }
    }

    private func finishServed(_ s: Session, price: Double) {
        s.node.setBubbleVisible(false)
        s.node.showFront()
        onServed?(ServeEvent(headPoint: headPoint(s), price: price, isGourmet: s.isGourmet))
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
