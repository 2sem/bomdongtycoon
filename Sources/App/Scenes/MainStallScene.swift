import SpriteKit
import GameCore

extension Notification.Name {
    static let openStaffSheet = Notification.Name("openStaffSheet")
    static let openJobSheet = Notification.Name("openJobSheet")
}

final class MainStallScene: SKScene {

    // MARK: - Properties

    weak var store: GameStore? {
        didSet { updateSignLabel() }
    }

    private static let maxDelta: TimeInterval = 1.0 / 3.0

    private var lastUpdateTime: TimeInterval = 0
    private var coinBubbles: [CoinBubbleNode] = []
    private var lastPendingCoins: Double = 0
    private var lastStallTier = -1
    private var lastShopName = ""
    private var lastAvailableWorkers = -1

    // Farm
    private var farmPlotNodes: [FarmPlotNode] = []
    private var addPlotCell: AddPlotCellNode?
    private let farmNode = SKNode()
    private var lastFarmUpgradeTier = -1


    // Warehouse
    private var warehouseNode: WarehouseNode?
    private var lastWarehouse = -1
    private var lastWarehouseCapacity = -1

    // Per-menu cook slots (staff area between tent and sign)
    private var menuCookSlots: [MenuCookSlotNode] = []
    private var lastCookMenuTier = -1

    // Cashier at the shop counter
    private var cashierEmojiNode:   SKLabelNode?
    private var cashierWarningNode: SKLabelNode?
    private var lastCashierCount  = -1
    private var lastCashierTier   = -1
    private var lastCashierEnergy = -1.0

    private static func formatCoins(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000     { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private static func stallEmoji(for tier: Int) -> String {
        switch tier {
        case 0:  "⛺"
        case 1:  "🏪"
        default: "🏬"
        }
    }

    private static func menuEmoji(for index: Int) -> String {
        let all = ["🥬", "🥗", "🥘"]
        return index < all.count ? all[index] : "🥬"
    }

    private static let tier1Emojis = ["🧑", "👦", "👧", "👱‍♂️", "👱‍♀️", "🧑‍💼"]
    private static let tier3Emojis = ["👨‍🍳", "👩‍🍳"]

    private func staffEmoji(tier: Int, indexInTier: Int) -> String {
        switch tier {
        case 1:  Self.tier1Emojis[indexInTier % Self.tier1Emojis.count]
        case 2:  "👵"
        case 3:  Self.tier3Emojis[indexInTier % Self.tier3Emojis.count]
        default: "🧑"
        }
    }

    /// Emoji for the cook assigned to menu slot i (tier > 0).
    private func cookEmoji(menuIndex i: Int, store: GameStore) -> String {
        let tier = i < store.stall.menuCooks.count ? store.stall.menuCooks[i] : 0
        guard tier > 0 else { return "" }
        let slotsForTier = store.stall.menuCooks.enumerated()
            .filter { $0.element == tier }.map { $0.offset }.sorted()
        let indexInTier = slotsForTier.firstIndex(of: i) ?? 0
        return staffEmoji(tier: tier, indexInTier: indexInTier)
    }

    // Bottom-up layout: stack zones from safe bottom, sky fills the rest naturally.
    private static let soilZoneH:      CGFloat = 130   // farm plots (2 rows × 62pt ≈ 128)
    private static let warehouseZoneH: CGFloat = 90    // warehouse cells (76pt + margin)
    private static let pavementZoneH:  CGFloat = 80    // pavement between grass and stall

    private var soilHeight:  CGFloat { Self.soilZoneH }
    private var groundY:     CGFloat { safeBottom + soilHeight + Self.warehouseZoneH }
    private var stallY:      CGFloat { groundY + Self.pavementZoneH / 2 }
    // Anchored from top: adapts to SE (small safe area) vs Pro (large Dynamic Island)
    private var hudTopY: CGFloat {
        frame.height - (view?.safeAreaInsets.top ?? 44) - 90
    }
    private var warehouseBarHeight: CGFloat { 76 }
    private var warehouseY: CGFloat { safeBottom + soilHeight + Self.warehouseZoneH / 2 }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.62, green: 0.85, blue: 1.0, alpha: 1)
        guard frame.width > 0, frame.height > 0 else { return }
        clearAndRebuild()
    }

    /// Called when the scene is resized — fires with the correct frame after
    /// SwiftUI's layout pass settles, catching any stale frame from didMove.
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard frame.width > 0, frame.height > 0, oldSize != size else { return }
        clearAndRebuild()
    }

    private func clearAndRebuild() {
        removeAllChildren()
        coinBubbles.removeAll()
        farmPlotNodes.removeAll()
        addPlotCell        = nil
        menuCookSlots.removeAll()
        warehouseNode      = nil
        cashierEmojiNode   = nil
        cashierWarningNode = nil
        lastStallTier      = -1
        lastCookMenuTier   = -1
        lastWarehouse      = -1
        lastWarehouseCapacity = -1
        lastCashierCount   = -1
        lastCashierTier    = -1
        lastCashierEnergy  = -1.0
        lastFarmUpgradeTier  = -1
        lastAvailableWorkers = -1
        lastShopName       = ""
        lastPendingCoins   = 0
        setupBackground()
        setupFarm()
        setupFence()
        setupWarehouse()
        setupStall()
        setupCookSlots()
        setupCashier()
        setupHUD()
        updateSignLabel()
    }

    // MARK: - Background

    private func setupBackground() {
        let pavement = SKSpriteNode(
            color: SKColor(red: 0.76, green: 0.78, blue: 0.74, alpha: 1),
            size: CGSize(width: frame.width, height: groundY * 2)
        )
        pavement.position = CGPoint(x: frame.midX, y: groundY * 0.5)
        pavement.zPosition = -5
        addChild(pavement)

        let grass = SKSpriteNode(
            color: SKColor(red: 0.40, green: 0.72, blue: 0.28, alpha: 1),
            size: CGSize(width: frame.width, height: 18)
        )
        grass.position = CGPoint(x: frame.midX, y: groundY)
        grass.zPosition = -4
        addChild(grass)

        let flowers = ["🌸", "🌺", "🌼", "🌸", "🌺", "🌼"]
        for (i, flower) in flowers.enumerated() {
            let label = SKLabelNode(text: flower)
            label.fontSize = 13
            label.position = CGPoint(
                x: frame.width * 0.05 + CGFloat(i) * (frame.width * 0.18),
                y: groundY + 6
            )
            label.zPosition = -3
            addChild(label)
        }

        addCloud(at: CGPoint(x: frame.width * 0.18, y: frame.height * 0.82), scale: 1.0)
        addCloud(at: CGPoint(x: frame.width * 0.72, y: frame.height * 0.88), scale: 0.65)
        addCloud(at: CGPoint(x: frame.width * 0.48, y: frame.height * 0.93), scale: 0.8)
    }

    private func addCloud(at position: CGPoint, scale: CGFloat) {
        let cloud = SKNode()
        let parts: [(CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 26), (-28, -5, 19), (28, -5, 19), (-13, 11, 15), (13, 11, 15)
        ]
        for (x, y, r) in parts {
            let circle = SKShapeNode(circleOfRadius: r * scale)
            circle.fillColor = SKColor.white.withAlphaComponent(0.92)
            circle.strokeColor = .clear
            circle.position = CGPoint(x: x * scale, y: y * scale)
            cloud.addChild(circle)
        }
        cloud.position = position
        cloud.zPosition = -6
        addChild(cloud)
        cloud.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 25, y: 0, duration: 7),
            SKAction.moveBy(x: -25, y: 0, duration: 7)
        ])))
    }

    // MARK: - Farm

    private var safeBottom: CGFloat { view?.safeAreaInsets.bottom ?? 0 }

    private func setupFarm() {
        let safeBase   = safeBottom
        let soilHeight = self.soilHeight
        let soilY      = safeBase + soilHeight / 2

        let underSoil = SKSpriteNode(
            color: SKColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 1),
            size: CGSize(width: frame.width, height: safeBase + 4)
        )
        underSoil.position = CGPoint(x: frame.midX, y: (safeBase + 4) / 2)
        underSoil.zPosition = -3
        addChild(underSoil)

        let soil = SKSpriteNode(
            color: SKColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 1),
            size: CGSize(width: frame.width, height: soilHeight)
        )
        soil.position = CGPoint(x: frame.midX, y: soilY)
        soil.zPosition = -3
        addChild(soil)

        let divider = SKSpriteNode(
            color: SKColor(red: 0.35, green: 0.55, blue: 0.20, alpha: 1),
            size: CGSize(width: frame.width, height: 4)
        )
        divider.position = CGPoint(x: frame.midX, y: safeBase + soilHeight)
        divider.zPosition = -3
        addChild(divider)

        farmNode.position = CGPoint(x: frame.midX, y: soilY)
        farmNode.zPosition = 2
        addChild(farmNode)
    }

    // MARK: - Farm grid layout constants
    private static let farmCols     = 5
    private static let farmSpacingX: CGFloat = 62
    private static let farmSpacingY: CGFloat = 62
    private static let farmRowY: [CGFloat] = [32, -32]
    private static let farmOriginX: CGFloat = -CGFloat(farmCols - 1) * farmSpacingX / 2

    private func gridPosition(for index: Int) -> CGPoint {
        let col = index % Self.farmCols
        let row = index / Self.farmCols
        let x   = Self.farmOriginX + CGFloat(col) * Self.farmSpacingX
        let y   = row < Self.farmRowY.count
            ? Self.farmRowY[row]
            : Self.farmRowY.last! - CGFloat(row - Self.farmRowY.count + 1) * Self.farmSpacingY
        return CGPoint(x: x, y: y)
    }

    private func syncFarmPlots(farm: FarmState, activePlots: Int) {
        while farmPlotNodes.count < activePlots {
            let node = FarmPlotNode()
            farmNode.addChild(node)
            farmPlotNodes.append(node)
        }

        let nextCost = FarmSystem.costForNextPlot(currentCount: activePlots)
        let warehouseFull = (store?.stall.warehouse ?? 0) >= (store?.stall.warehouseCapacity ?? 1)
        let workerAvailable = (store?.availableForFarm ?? 0) > 0

        let tier1InMenus = store?.stall.menuCooks.filter { $0 == 1 }.count ?? 0
        var farmWorkerIdx = 0
        for i in 0..<activePlots {
            farmPlotNodes[i].position = gridPosition(for: i)
            farmPlotNodes[i].isHidden = false
            if i < farm.plots.count {
                let plot = farm.plots[i]
                let assignedEmoji: String? = plot.hasWorker
                    ? staffEmoji(tier: 1, indexInTier: tier1InMenus + farmWorkerIdx)
                    : nil
                if plot.hasWorker { farmWorkerIdx += 1 }
                farmPlotNodes[i].update(plot: plot, warehouseFull: warehouseFull,
                                        assignedEmoji: assignedEmoji, workerAvailable: workerAvailable,
                                        workerEnergy: plot.workerEnergy);
            }
        }
        for i in activePlots..<farmPlotNodes.count {
            farmPlotNodes[i].isHidden = true
        }

        if let cost = nextCost {
            if addPlotCell == nil {
                let cell = AddPlotCellNode()
                farmNode.addChild(cell)
                addPlotCell = cell
            }
            addPlotCell?.position = gridPosition(for: activePlots)
            addPlotCell?.isHidden = false
            addPlotCell?.update(cost: cost, canAfford: (store?.stall.coins ?? 0) >= cost)
        } else {
            addPlotCell?.isHidden = true
        }

        // Center the visible cells: shift farmNode so the active columns are centered.
        let totalVisible = activePlots + (nextCost != nil ? 1 : 0)
        let visibleCols  = min(max(totalVisible, 1), Self.farmCols)
        farmNode.position.x = frame.midX - Self.farmOriginX - CGFloat(visibleCols - 1) * Self.farmSpacingX / 2
    }

    // MARK: - Fence

    private func setupFence() {
        let fenceY  = safeBottom + soilHeight   // top edge of the soil strip
        let postW:  CGFloat = 8
        let postH:  CGFloat = 24
        let railH:  CGFloat = 4
        let postColor = SKColor(red: 0.42, green: 0.24, blue: 0.09, alpha: 1)
        let railColor = SKColor(red: 0.58, green: 0.36, blue: 0.14, alpha: 1)

        // Two horizontal rails spanning full width
        for offsetY in [-4.0, 8.0] as [CGFloat] {
            let rail = SKSpriteNode(
                color: railColor,
                size: CGSize(width: frame.width, height: railH)
            )
            rail.position  = CGPoint(x: frame.midX, y: fenceY + offsetY)
            rail.zPosition = 1
            addChild(rail)
        }

        // Vertical posts every 20pt
        let spacing: CGFloat = 20
        let count = Int(frame.width / spacing) + 1
        for i in 0...count {
            let post = SKSpriteNode(
                color: postColor,
                size: CGSize(width: postW, height: postH)
            )
            post.position  = CGPoint(x: CGFloat(i) * spacing - postW / 2, y: fenceY + 2)
            post.zPosition = 1
            addChild(post)
        }
    }

    // MARK: - Warehouse

    private func setupWarehouse() {
        let node = WarehouseNode()
        node.position  = CGPoint(x: frame.midX, y: warehouseY)
        node.zPosition = 2
        addChild(node)
        warehouseNode = node

        let divider = SKSpriteNode(
            color: SKColor(red: 0.20, green: 0.12, blue: 0.04, alpha: 1),
            size: CGSize(width: frame.width, height: 2)
        )
        divider.position = CGPoint(x: frame.midX, y: warehouseY - warehouseBarHeight / 2)
        divider.zPosition = 2
        addChild(divider)
    }

    private func syncWarehouse(store: GameStore) {
        let w   = store.stall.warehouse
        let cap = store.stall.warehouseCapacity
        let expandCost = WarehouseSystem.costForNextExpansion(current: cap)
        let canAfford  = expandCost.map { store.stall.coins >= $0 } ?? false
        warehouseNode?.update(warehouse: w, capacity: cap, expandCostValue: expandCost, canAfford: canAfford)
        lastWarehouse = w
        lastWarehouseCapacity = cap
    }

    // MARK: - Cook slots (staff area)

    private static let cookSlotSpacing: CGFloat = 68
    // Y position: above product stack (~stallY+150 max), well below HUD
    private var cookSlotsY: CGFloat { stallY + 200 }

    private func setupCookSlots() {}   // slots are built lazily in syncCookSlots

    private func syncCookSlots(store: GameStore) {
        let tier = store.stall.menuTier

        // Rebuild row when menu count changes
        if tier != lastCookMenuTier {
            menuCookSlots.forEach { $0.removeFromParent() }
            menuCookSlots.removeAll()

            let count  = tier + 1
            let originX = frame.midX - CGFloat(count - 1) * Self.cookSlotSpacing / 2
            for i in 0...tier {
                let slot = MenuCookSlotNode()
                slot.setup(menuEmoji: Self.menuEmoji(for: i))
                slot.position = CGPoint(x: originX + CGFloat(i) * Self.cookSlotSpacing,
                                        y: cookSlotsY)
                slot.zPosition = 4
                addChild(slot)
                menuCookSlots.append(slot)
            }
            lastCookMenuTier = tier
        }

        // Update each slot
        let maxStock  = EarningsSystem.maxStock(for: store.stall)
        let progress  = store.cookProgress
        for i in 0...tier {
            guard i < menuCookSlots.count else { continue }
            let cookTier = i < store.stall.menuCooks.count ? store.stall.menuCooks[i] : 0
            let stock    = i < store.stall.menuStock.count ? store.stall.menuStock[i] : 0
            let prog     = i < progress.count ? progress[i] : 0
            let energy   = i < store.stall.menuCookEnergy.count ? store.stall.menuCookEnergy[i] : 1.0
            menuCookSlots[i].update(cookTier: cookTier, cookEmoji: cookEmoji(menuIndex: i, store: store),
                                    progress: prog, stock: stock, maxStock: maxStock, cookEnergy: energy)
        }
    }

    // MARK: - Cashier

    private func setupCashier() {
        let node = SKLabelNode(text: "🧑")
        node.fontSize = 30
        node.verticalAlignmentMode   = .center
        node.horizontalAlignmentMode = .center
        node.position  = CGPoint(x: frame.midX, y: groundY + 38)
        node.zPosition = 3
        node.name      = "cashierEmoji"
        node.isHidden  = true
        addChild(node)
        cashierEmojiNode = node

        let warning = SKLabelNode(text: "⚠️")
        warning.fontSize = 13
        warning.verticalAlignmentMode   = .center
        warning.horizontalAlignmentMode = .center
        warning.position  = CGPoint(x: frame.midX + 16, y: groundY + 52)
        warning.zPosition = 4
        warning.isHidden  = true
        addChild(warning)
        cashierWarningNode = warning
    }

    private func syncCashier(store: GameStore) {
        let count  = store.stall.cashierCount
        let tier   = store.stall.cashierTier
        let energy = store.stall.cashierEnergy
        guard count != lastCashierCount || tier != lastCashierTier || energy != lastCashierEnergy else { return }
        lastCashierCount  = count
        lastCashierTier   = tier
        lastCashierEnergy = energy

        let visible = count > 0
        cashierEmojiNode?.isHidden  = !visible
        cashierWarningNode?.isHidden = !(visible && energy < 0.05)
        if visible {
            cashierEmojiNode?.text = staffEmoji(tier: tier, indexInTier: 0)
        }
    }

    // MARK: - Stall

    private func setupStall() {
        let stallEmoji = SKLabelNode(text: "⛺")
        stallEmoji.fontSize = 110
        stallEmoji.verticalAlignmentMode = .center
        stallEmoji.position = CGPoint(x: frame.midX, y: stallY + 10)
        stallEmoji.zPosition = 1
        stallEmoji.name = "stallEmoji"
        addChild(stallEmoji)

        let signY = stallY + 80
        let signBg = SKShapeNode(rectOf: CGSize(width: 170, height: 32), cornerRadius: 8)
        signBg.fillColor   = SKColor(red: 0.12, green: 0.48, blue: 0.22, alpha: 1)
        signBg.strokeColor = SKColor(red: 0.08, green: 0.32, blue: 0.15, alpha: 1)
        signBg.lineWidth   = 2
        signBg.position    = CGPoint(x: frame.midX, y: signY)
        signBg.zPosition   = 2
        addChild(signBg)

        let signLabel = SKLabelNode(text: "🥬 봄동 가게")
        signLabel.fontName = "AppleSDGothicNeo-Bold"
        signLabel.fontSize = 15
        signLabel.fontColor = .white
        signLabel.verticalAlignmentMode = .center
        signLabel.position  = CGPoint(x: frame.midX, y: signY)
        signLabel.zPosition = 3
        signLabel.name = "signLabel"
        addChild(signLabel)

        // Gear icon — attached to the right end of the shop sign
        let gearBg = SKShapeNode(circleOfRadius: 13)
        gearBg.fillColor   = SKColor(red: 0.08, green: 0.32, blue: 0.15, alpha: 1)
        gearBg.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        gearBg.lineWidth   = 1
        gearBg.position    = CGPoint(x: frame.midX + 93, y: signY)
        gearBg.zPosition   = 3
        gearBg.name        = "gearIcon"
        addChild(gearBg)

        let gear = SKLabelNode(text: "👤")
        gear.fontSize = 16
        gear.verticalAlignmentMode = .center
        gear.horizontalAlignmentMode = .center
        gear.position  = CGPoint(x: frame.midX + 93, y: signY)
        gear.zPosition = 4
        gear.name      = "gearIcon"
        addChild(gear)

        // Dish icon — placed on the left end of the sign (mirrors staff icon on right)
        let dishBg = SKShapeNode(circleOfRadius: 13)
        dishBg.fillColor   = SKColor(red: 0.08, green: 0.32, blue: 0.15, alpha: 1)
        dishBg.strokeColor = SKColor(white: 1.0, alpha: 0.25)
        dishBg.lineWidth   = 1
        dishBg.position    = CGPoint(x: frame.midX - 93, y: signY)
        dishBg.zPosition   = 3
        dishBg.name        = "dishIcon"
        addChild(dishBg)

        let dishLabel = SKLabelNode(text: "🍽")
        dishLabel.fontSize = 16
        dishLabel.verticalAlignmentMode = .center
        dishLabel.horizontalAlignmentMode = .center
        dishLabel.position  = dishBg.position
        dishLabel.zPosition = 4
        dishLabel.name      = "dishIcon"
        addChild(dishLabel)

        // Notification badge — shown when availableWorkers > 0
        let badge = SKShapeNode(circleOfRadius: 8)
        badge.fillColor   = SKColor(red: 0.95, green: 0.25, blue: 0.20, alpha: 1)
        badge.strokeColor = .white
        badge.lineWidth   = 1.5
        badge.position    = CGPoint(x: frame.midX + 103, y: signY + 10)
        badge.zPosition   = 5
        badge.name        = "gearBadge"
        badge.isHidden    = true
        addChild(badge)

        let badgeLabel = SKLabelNode(text: "1")
        badgeLabel.fontName = "AppleSDGothicNeo-Bold"
        badgeLabel.fontSize = 9
        badgeLabel.fontColor = .white
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.horizontalAlignmentMode = .center
        badgeLabel.position  = CGPoint(x: frame.midX + 103, y: signY + 10)
        badgeLabel.zPosition = 6
        badgeLabel.name      = "gearBadgeLabel"
        badgeLabel.isHidden  = true
        addChild(badgeLabel)
    }

    private func updateSignLabel() {
        guard let store,
              let label = childNode(withName: "signLabel") as? SKLabelNode else { return }
        label.text = "🥬 \(store.progress.shopName)"
    }

    private func syncGearBadge(store: GameStore) {
        let count = store.availableWorkers
        guard count != lastAvailableWorkers else { return }
        lastAvailableWorkers = count

        let show = count > 0
        childNode(withName: "gearBadge")?.isHidden = !show
        childNode(withName: "gearBadgeLabel")?.isHidden = !show
        if let lbl = childNode(withName: "gearBadgeLabel") as? SKLabelNode {
            lbl.text = "\(count)"
        }
    }

    // MARK: - Product stack

    // MARK: - HUD

    private func setupHUD() {
        // Coin display moved to SwiftUI top bar (CoinBadge)
    }

    // MARK: - Customer spawning

    private func startCustomerSpawning() {
        scheduleNextCustomer()
    }

    private func scheduleNextCustomer(firstCustomer: Bool = false) {
        let interval = firstCustomer ? 1.0 : (store?.customerSpawnInterval ?? 4.0)
        let jitter   = firstCustomer ? 0.0 : interval * 0.2
        run(SKAction.sequence([
            SKAction.wait(forDuration: interval, withRange: jitter),
            SKAction.run { [weak self] in
                self?.spawnCustomer()
                self?.scheduleNextCustomer()
            },
        ]), withKey: "customerSpawn")
    }

    private static func availableMenus(for menuTier: Int) -> [String] {
        let all = ["🥬", "🥗", "🥘"]
        return Array(all.prefix(menuTier + 1))
    }

    private func spawnCustomer() {
        guard let store else { return }
        let menus = Self.availableMenus(for: store.stall.menuTier)
        let customer = CustomerNode(availableMenus: menus)

        let streetY   = groundY - 18
        let counterPt = CGPoint(x: frame.midX - 70, y: groundY + 22)
        let exitPt    = CGPoint(x: frame.width + 50, y: streetY)

        customer.position = CGPoint(x: -50, y: streetY)
        addChild(customer)

        customer.walkTo(counterPt) { [weak self] in
            guard let self else { return }
            self.serveOrWait(customer: customer, store: store, exitPt: exitPt)
        }
    }

    private func serveOrWait(customer: CustomerNode, store: GameStore, exitPt: CGPoint) {
        let menus = Self.availableMenus(for: store.stall.menuTier)
        let idx   = menus.firstIndex(of: customer.wantedMenu) ?? 0

        // Try to serve immediately
        if let price = store.sellItem(menuIndex: idx) {
            store.recordServed(waitTime: 0)
            spawnCoinBubble(at: customer.position, amount: price,
                            autoPop: store.stall.autoCollectEnabled)
            customer.showReaction(happy: true)
            customer.walkTo(exitPt) { customer.removeFromParent() }
            return
        }

        // No stock — wait up to 8 s, polling every 0.5 s
        customer.startWaiting()
        var waited = 0.0
        let maxWait  = 8.0
        let interval = 0.5

        let poll = SKAction.sequence([
            SKAction.wait(forDuration: interval),
            SKAction.run { [weak self, weak customer] in
                guard let self, let customer else { return }
                waited += interval
                if let price = store.sellItem(menuIndex: idx) {
                    customer.stopWaiting()
                    customer.removeAction(forKey: "poll")
                    store.recordServed(waitTime: waited)
                    self.spawnCoinBubble(at: customer.position, amount: price,
                                        autoPop: store.stall.autoCollectEnabled)
                    customer.showReaction(happy: true)
                    customer.walkTo(exitPt) { customer.removeFromParent() }
                } else if waited >= maxWait {
                    customer.stopWaiting()
                    customer.removeAction(forKey: "poll")
                    store.recordFailed()
                    customer.showReaction(happy: false)
                    customer.walkTo(exitPt) { customer.removeFromParent() }
                }
            }
        ])
        customer.run(SKAction.repeatForever(poll), withKey: "poll")
    }

    private func spawnCoinBubble(at position: CGPoint, amount: Double, autoPop: Bool = false) {
        let bubble = CoinBubbleNode(amount: amount)
        bubble.position = CGPoint(x: position.x, y: position.y + 80)
        bubble.zPosition = 6   // above sign (z=3) and cook slots (z=4), below HUD (z=9)
        addChild(bubble)
        coinBubbles.append(bubble)

        if autoPop {
            bubble.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.7),
                SKAction.run { [weak self] in
                    bubble.pop()
                    self?.coinBubbles.removeAll { $0 === bubble }
                },
            ]))
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let store else { return }
        let location = touch.location(in: self)

        for bubble in coinBubbles where bubble.contains(location) {
            Task { @MainActor in store.collectCoins() }
            bubble.pop()
            coinBubbles.removeAll { $0 === bubble }
            return
        }

        let activePlots  = FarmSystem.activePlotCount(for: store.farm)
        let nodeLocation = farmNode.convert(location, from: self)

        if let cell = addPlotCell, !cell.isHidden, cell.contains(nodeLocation) {
            Task { @MainActor in store.purchaseUpgrade(.farm) }
            return
        }

        for i in 0..<min(activePlots, farmPlotNodes.count) {
            guard farmPlotNodes[i].contains(nodeLocation) else { continue }
            let plot = store.farm.plots[i]
            let localInPlot = farmPlotNodes[i].convert(nodeLocation, from: farmNode)
            let workerBadgeDist = hypot(localInPlot.x - 20, localInPlot.y - 22)
            if workerBadgeDist <= 18 {
                Task { @MainActor in store.toggleWorker(plotIndex: i) }
            } else if plot.isReady {
                Task { @MainActor in store.harvest(plotIndex: i) }
                farmPlotNodes[i].animateHarvest()
            } else if !plot.isPlanted {
                Task { @MainActor in store.plantSeed(plotIndex: i) }
            }
            return
        }

        if let wNode = warehouseNode {
            let wLocal = wNode.convert(location, from: self)
            if wNode.expandCellContains(wLocal) {
                Task { @MainActor in store.expandWarehouse() }
                return
            }
        }

        for (i, slot) in menuCookSlots.enumerated() {
            if slot.contains(location) {
                slot.animateCook()
                Task { @MainActor in store.manualCook(menuIndex: i) }
                return
            }
        }

        let dishCenter = CGPoint(x: frame.midX - 93, y: stallY + 80)
        if hypot(location.x - dishCenter.x, location.y - dishCenter.y) <= 22 {
            NotificationCenter.default.post(name: .openJobSheet, object: nil)
            return
        }

        let gearCenter = CGPoint(x: frame.midX + 93, y: stallY + 80)
        if hypot(location.x - gearCenter.x, location.y - gearCenter.y) <= 22 {
            NotificationCenter.default.post(name: .openStaffSheet, object: nil)
            return
        }
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let delta = min(rawDelta, Self.maxDelta)
        lastUpdateTime = currentTime

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            store.tick(deltaTime: delta)

            // Pop any lingering bubbles when pendingCoins reaches 0 (cashier collected)
            let pending = store.stall.pendingCoins
            if pending == 0 && self.lastPendingCoins > 0 {
                self.coinBubbles.forEach { $0.pop() }
                self.coinBubbles.removeAll()
            }
            self.lastPendingCoins = pending

            let activePlots = FarmSystem.activePlotCount(for: store.farm)
            self.syncFarmPlots(farm: store.farm, activePlots: activePlots)
            self.syncWarehouse(store: store)
            self.syncCookSlots(store: store)
            self.syncCashier(store: store)
            self.syncGearBadge(store: store)

            // Customers only spawn once the shop name is set (tutorial complete)
            if store.progress.isShopNameSet && self.action(forKey: "customerSpawn") == nil {
                self.scheduleNextCustomer(firstCustomer: true)
            }
            let shopName = store.progress.shopName
            if shopName != self.lastShopName {
                self.lastShopName = shopName
                if let label = self.childNode(withName: "signLabel") as? SKLabelNode {
                    label.text = "🥬 \(shopName)"
                }
            }
            let tier = store.stall.stallTier
            if tier != self.lastStallTier {
                self.lastStallTier = tier
                if let label = self.childNode(withName: "stallEmoji") as? SKLabelNode {
                    label.text = Self.stallEmoji(for: tier)
                    label.run(SKAction.sequence([
                        SKAction.scale(to: 1.25, duration: 0.15),
                        SKAction.scale(to: 1.0,  duration: 0.15),
                    ]))
                }
            }
        }
    }
}
