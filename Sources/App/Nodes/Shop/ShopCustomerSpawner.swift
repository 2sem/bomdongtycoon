import SpriteKit
import GameCore

/// A spawned customer's walk state: `walkingIn` (spawn → the counter, one
/// straight leg west along `ShopNode.customerServiceRow`), `waitingForStock`
/// (parked at the counter, polling `GameStore.sellItem` every
/// `pollInterval` up to `maxWait`), and `walkingOut` (back east to spawn,
/// then removed).
private enum CustomerPhase {
    case walkingIn
    case waitingForStock
    case walkingOut
}

/// One active customer's mutable walk/serve state. A class (not a struct)
/// because `ShopCustomerSpawner.update` mutates it in place every frame
/// rather than replacing array elements.
private final class CustomerSession {
    let node: ShopCustomerNode
    let queueSlot: Int
    var path: [CGPoint]
    var phase: CustomerPhase
    var waited: TimeInterval = 0
    var pollTimer: TimeInterval = 0

    init(node: ShopCustomerNode, queueSlot: Int, path: [CGPoint], phase: CustomerPhase) {
        self.node = node
        self.queueSlot = queueSlot
        self.path = path
        self.phase = phase
    }
}

/// Owns the customer spawn loop `MainStallScene` used to run inline before
/// the scene was rebuilt for the isometric ground: a timed spawn (first
/// customer 1s after the shop opens, then `GameStore.customerSpawnInterval`
/// ±jitter), a walk in to `ShopNode.customerServicePoint`, an immediate
/// sell-or-wait-and-poll decision, and a walk back out. Customers enter and
/// leave from east of the map (screen bottom-right in this projection, the
/// side the counter already faces) rather than the south road tile — a
/// road/rail placeholder for that entrance may land there later, but
/// nothing here depends on it. `MainStallScene` owns the instance and
/// drives it once a frame from its own already-`@MainActor` update block,
/// matching how it already calls `store.tick`.
///
/// `@MainActor`, like `GameStore` itself — every method here but `init`
/// touches `store` or a scene node — with a `nonisolated init` so
/// `MainStallScene` can still create it as a plain stored-property
/// initializer.
@MainActor
final class ShopCustomerSpawner {

    /// Customers actively spawned/walking/waiting/leaving at once. Caps
    /// spawning rather than modelling an unbounded queue — simpler, and
    /// `ShopNode.customerServicePoint`'s per-slot offset only needs to
    /// cover this many positions.
    private static let maxConcurrentCustomers = 3

    /// How long a full spawn slot waits before checking again, once the
    /// scheduled spawn time has already passed — short enough that a
    /// customer leaving is noticed promptly, without re-rolling the timer
    /// (and its jitter) on every frame while full.
    private static let retryDelayWhenFull: TimeInterval = 1.0

    private static let walkSpeed: CGFloat = 90
    private static let minLegDuration: TimeInterval = 0.15
    private static let pollInterval: TimeInterval = 0.5
    private static let maxWait: TimeInterval = 8.0

    /// Columns east of `GroundLayer.eastMapEdgeColumn` a customer
    /// spawns/exits at — enough to sit off whatever's rendered at the
    /// map's own edge, without being an arbitrary absolute column.
    private static let spawnColumnsPastMapEdge = 4

    /// Fade-in at spawn / fade-out at exit, so a customer doesn't just pop
    /// in or out if its spawn point happens to be on screen.
    private static let fadeDuration: TimeInterval = 0.3

    /// Counts down to the next spawn attempt; only decremented once the
    /// shop is open (see `update`), so it always reads as "1s after the
    /// shop opens" for the very first customer, the same as the
    /// pre-rebuild scene's `scheduleNextCustomer(firstCustomer: true)`.
    private var spawnTimer: TimeInterval = 1.0

    private var sessions: [CustomerSession] = []

    nonisolated init() {}

    /// Set during a location transition: existing customers keep walking,
    /// but no new one spawns and the spawn timer does not run down.
    var isSpawningPaused = false

    /// Node name of the floating "+N" pops, so a rebuild can sweep them.
    static let coinPopName = "coinPop"

    /// Customers gone and the first-customer delay restarted: what a new run starts from.
    func reset() {
        removeAllCustomers()
        spawnTimer = 1.0
    }

    /// Drops every in-flight customer. They are only visuals — coins were
    /// credited when the sale happened — so this is safe mid-walk.
    func removeAllCustomers() {
        for session in sessions {
            session.node.removeAllActions()
            session.node.removeFromParent()
        }
        sessions.removeAll()
    }

    /// Advances every active customer by `delta` and, once due, spawns a
    /// new one — called once a frame from `MainStallScene.update`. No-op
    /// until `store.progress.isShopNameSet`: there's no other shop-open
    /// gate in the rebuilt scene, and this is the same gate the
    /// pre-rebuild scene used (customers start once the naming/tutorial
    /// flow finishes, not before).
    func update(delta: TimeInterval, store: GameStore, grid: IsoGrid, parent: SKNode) {
        guard store.progress.isShopNameSet, !store.isSimulationPaused else { return }

        if !isSpawningPaused {
            spawnTimer -= delta
        }
        if spawnTimer <= 0, !isSpawningPaused {
            trySpawnCustomer(store: store, grid: grid, parent: parent)
        }

        for session in sessions {
            advance(session, delta: delta, store: store, grid: grid)
            if session.node.parent != nil {
                session.node.zPosition = ShopNode.actorZPosition(atWorldY: session.node.position.y, on: grid)
            }
        }
        sessions.removeAll { $0.node.parent == nil }
    }

    private func trySpawnCustomer(store: GameStore, grid: IsoGrid, parent: SKNode) {
        guard sessions.count < Self.maxConcurrentCustomers else {
            spawnTimer = Self.retryDelayWhenFull
            return
        }

        let menuIndex = (0...store.stall.menuTier).randomElement() ?? 0
        let archetype = CustomerArchetype.allCases.randomElement() ?? .adult
        let node = ShopCustomerNode(archetype: archetype, wantedMenuIndex: menuIndex, fittingTo: grid)
        node.position = spawnPoint(on: grid)
        node.zPosition = ShopNode.actorZPosition(atWorldY: node.position.y, on: grid)
        node.alpha = 0
        node.run(.fadeIn(withDuration: Self.fadeDuration))
        parent.addChild(node)

        // The lowest slot no current session holds — not sessions.count,
        // which reassigns a slot still held by an earlier customer once
        // someone ahead of it leaves (e.g. slot 0 exits while slot 1 is
        // still waiting: count drops to 1, so the next spawn would also
        // claim slot 1 and stack on the waiting customer). A session keeps
        // its slot until its node is removed — walking out still holds it —
        // so slots never get reused mid-exit.
        let heldSlots = Set(sessions.map(\.queueSlot))
        let queueSlot = (0..<Self.maxConcurrentCustomers).first { !heldSlots.contains($0) } ?? sessions.count
        let session = CustomerSession(
            node: node,
            queueSlot: queueSlot,
            path: [ShopNode.customerServicePoint(on: grid, queueSlot: queueSlot)],
            phase: .walkingIn
        )
        sessions.append(session)
        spawnTimer = nextSpawnInterval(store: store)
    }

    /// `store.customerSpawnInterval` ± a fifth of itself either way — the
    /// same jitter fraction the pre-rebuild scene applied via
    /// `SKAction.wait(forDuration:withRange:)`, reproduced by hand since
    /// this timer is a plain per-frame countdown, not an `SKAction`.
    private func nextSpawnInterval(store: GameStore) -> TimeInterval {
        let interval = store.customerSpawnInterval
        let jitter = interval * 0.2
        return TimeInterval.random(in: (interval - jitter / 2)...(interval + jitter / 2))
    }

    private func advance(_ session: CustomerSession, delta: TimeInterval, store: GameStore, grid: IsoGrid) {
        switch session.phase {
        case .walkingIn:
            advanceWalk(session) { self.beginServing(session, store: store, grid: grid) }
        case .waitingForStock:
            advanceWaiting(session, delta: delta, store: store, grid: grid)
        case .walkingOut:
            advanceWalk(session, fadesOut: true) {
                session.node.stopWalking()
                session.node.removeFromParent()
            }
        }
    }

    /// Steps `session.path` one leg at a time via `SKAction.move`,
    /// polling `action(forKey: "walk") == nil` rather than a completion
    /// closure — this whole call chain already runs inside
    /// `MainStallScene`'s per-frame `@MainActor` block, and a completion
    /// closure fired from SpriteKit's own action-evaluation pass would
    /// step outside that same call frame for no benefit. `onArrival` runs
    /// once `path` is empty and the customer is standing still. `fadesOut`
    /// grouped onto the move (not a separate fixed-length action) so the
    /// fade finishes exactly when the leg — and the walk-out — does.
    private func advanceWalk(_ session: CustomerSession, fadesOut: Bool = false, onArrival: () -> Void) {
        guard session.node.action(forKey: "walk") == nil else { return }
        guard let next = session.path.first else {
            onArrival()
            return
        }
        session.path.removeFirst()
        let dx = next.x - session.node.position.x
        let dy = next.y - session.node.position.y
        let distance = (dx * dx + dy * dy).squareRoot()
        let duration = max(TimeInterval(distance / Self.walkSpeed), Self.minLegDuration)
        session.node.startWalking()
        let move = SKAction.move(to: next, duration: duration)
        session.node.run(fadesOut ? .group([move, .fadeOut(withDuration: duration)]) : move, withKey: "walk")
    }

    /// First sell attempt on arrival at the counter: served immediately
    /// (waitTime 0) if stock allows it, otherwise starts the
    /// `waitingForStock` poll loop.
    private func beginServing(_ session: CustomerSession, store: GameStore, grid: IsoGrid) {
        session.node.stopWalking()
        session.node.stage = .waiting
        if let price = store.sellItem(menuIndex: session.node.wantedMenuIndex) {
            store.recordServed(waitTime: 0)
            session.node.showReaction(happy: true)
            spawnCoinPop(amount: price, from: session.node, grid: grid)
            beginWalkingOut(session, grid: grid)
        } else {
            session.phase = .waitingForStock
            session.node.startWaitingShuffle()
        }
    }

    private func advanceWaiting(_ session: CustomerSession, delta: TimeInterval, store: GameStore, grid: IsoGrid) {
        session.waited += delta
        session.pollTimer += delta
        guard session.pollTimer >= Self.pollInterval else { return }
        session.pollTimer = 0

        if let price = store.sellItem(menuIndex: session.node.wantedMenuIndex) {
            store.recordServed(waitTime: session.waited)
            session.node.stopWaitingShuffle()
            session.node.showReaction(happy: true)
            spawnCoinPop(amount: price, from: session.node, grid: grid)
            beginWalkingOut(session, grid: grid)
        } else if session.waited >= Self.maxWait {
            store.recordFailed()
            session.node.stopWaitingShuffle()
            session.node.showReaction(happy: false)
            beginWalkingOut(session, grid: grid)
        }
    }

    private func beginWalkingOut(_ session: CustomerSession, grid: IsoGrid) {
        session.phase = .walkingOut
        session.node.stage = .leaving
        session.path = [spawnPoint(on: grid)]
    }

    /// A small "+N" `money_bag` pop above the customer's head, floating up
    /// and fading on its own — unlike the pre-rebuild `CoinBubbleNode`,
    /// this isn't tap-to-collect (there's no on-screen bubble queue to
    /// manage here: `GameStore.sellItem` already credited `pendingCoins`
    /// directly), so it's a fire-and-forget node instead of a tracked one.
    private func spawnCoinPop(amount: Double, from node: ShopCustomerNode, grid: IsoGrid) {
        guard let parent = node.parent else { return }
        let pop = SKNode()
        pop.name = Self.coinPopName
        pop.position = CGPoint(x: node.position.x, y: node.position.y + node.headTopWorldOffset)
        pop.zPosition = node.zPosition + 0.01

        let icon = EmojiArt.sprite(for: "💰", size: CGSize(width: 18, height: 18))
        icon.position = CGPoint(x: -12, y: 0)
        pop.addChild(icon)

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "+\(Int(amount))"
        label.fontSize = 13
        label.fontColor = SKColor(red: 0.55, green: 0.28, blue: 0.0, alpha: 1)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 2, y: 0)
        pop.addChild(label)

        parent.addChild(pop)
        pop.run(.sequence([
            .group([.moveBy(x: 0, y: 26, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent(),
        ]))
    }

    /// East of the whole map, on `ShopNode.customerServiceRow` — a
    /// customer appears here, walks the one straight leg west to its
    /// queue slot, and (leaving) disappears back out here the same way.
    private func spawnPoint(on grid: IsoGrid) -> CGPoint {
        let col = GroundLayer.eastMapEdgeColumn + Self.spawnColumnsPastMapEdge
        return grid.point(col: CGFloat(col), row: ShopNode.customerServiceRow)
    }
}
