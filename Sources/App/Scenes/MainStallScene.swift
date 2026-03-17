import SpriteKit
import GameCore

extension Notification.Name {
    static let openStaffSheet = Notification.Name("openStaffSheet")
}

final class MainStallScene: SKScene {

    // MARK: - Properties

    weak var store: GameStore? {
        didSet { updateSignLabel() }
    }

    private static let maxDelta: TimeInterval = 1.0 / 3.0

    private var lastUpdateTime: TimeInterval = 0
    private var coinBubbles: [CoinBubbleNode] = []
    private var lastStallTier = -1
    private var lastShopName = ""

    // Farm
    private var farmPlotNodes: [FarmPlotNode] = []
    private var addPlotCell: AddPlotCellNode?
    private let farmNode = SKNode()
    private var lastFarmUpgradeTier = -1

    // Product stack — one stack node per menu slot
    private let productStackNode = SKNode()
    private var stackItemArrays: [[SKLabelNode]] = [[], [], []]
    private var lastVisualCounts: [Int] = [-1, -1, -1]
    private var lastMenuTierForStack = -1

    // Warehouse
    private var warehouseNode: WarehouseNode?
    private var lastWarehouse = -1
    private var lastWarehouseCapacity = -1

    // Per-menu cook slots (staff area between tent and sign)
    private var menuCookSlots: [MenuCookSlotNode] = []
    private var lastCookMenuTier = -1

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

    private var groundY:  CGFloat { frame.height * 0.30 }
    private var stallY:   CGFloat { groundY + 58 }
    private var hudTopY:  CGFloat { frame.height - 180 }
    private var warehouseBarHeight: CGFloat { 76 }
    private var warehouseY: CGFloat { (view?.safeAreaInsets.bottom ?? 0) + 150 + warehouseBarHeight / 2 }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.62, green: 0.85, blue: 1.0, alpha: 1)
        setupBackground()
        setupFarm()
        setupFence()
        setupWarehouse()
        setupStall()
        setupCookSlots()
        setupProductStack()
        setupHUD()
        startCustomerSpawning()
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
        let soilHeight: CGFloat = 150
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
    private static let farmCols     = 4
    private static let farmSpacingX: CGFloat = 68
    private static let farmSpacingY: CGFloat = 68
    private static let farmRowY: [CGFloat] = [34, -34]
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

        for i in 0..<activePlots {
            farmPlotNodes[i].position = gridPosition(for: i)
            farmPlotNodes[i].isHidden = false
            if i < farm.plots.count {
                farmPlotNodes[i].update(plot: farm.plots[i], warehouseFull: warehouseFull, workerAvailable: workerAvailable)
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
    }

    // MARK: - Fence

    private func setupFence() {
        let fenceY  = safeBottom + 150   // top edge of the soil strip
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
    // Y position: between tent body and sign
    private var cookSlotsY: CGFloat { stallY + 42 }

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
            menuCookSlots[i].update(cookTier: cookTier, progress: prog,
                                    stock: stock, maxStock: maxStock)
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

        let gear = SKLabelNode(text: "⚙️")
        gear.fontSize = 16
        gear.verticalAlignmentMode = .center
        gear.horizontalAlignmentMode = .center
        gear.position  = CGPoint(x: frame.midX + 93, y: signY)
        gear.zPosition = 4
        gear.name      = "gearIcon"
        addChild(gear)
    }

    private func updateSignLabel() {
        guard let store,
              let label = childNode(withName: "signLabel") as? SKLabelNode else { return }
        label.text = "🥬 \(store.progress.shopName)"
    }

    // MARK: - Product stack

    private func setupProductStack() {
        productStackNode.position = CGPoint(x: frame.midX, y: stallY + 100)
        productStackNode.zPosition = 3
        addChild(productStackNode)
        for i in 0..<3 {
            let node = SKNode()
            node.name = "stack\(i)"
            node.position = CGPoint(x: CGFloat(i - 1) * 28, y: 0)
            productStackNode.addChild(node)
        }
        stackItemArrays = [[], [], []]
    }

    private func syncProductStack(menuStock: [Int], menuTier: Int) {
        if menuTier != lastMenuTierForStack {
            for i in 0..<3 {
                stackItemArrays[i].forEach { $0.removeFromParent() }
                stackItemArrays[i].removeAll()
                lastVisualCounts[i] = 0
                productStackNode.childNode(withName: "stack\(i)")?.isHidden = (i > menuTier)
            }
            lastMenuTierForStack = menuTier
        }

        for i in 0...menuTier {
            guard i < menuStock.count else { continue }
            let visualCount = min(menuStock[i], 6)
            guard visualCount != lastVisualCounts[i] else { continue }
            guard let stackNode = productStackNode.childNode(withName: "stack\(i)") else { continue }
            let emoji = Self.menuEmoji(for: i)

            if visualCount > lastVisualCounts[i] {
                for j in lastVisualCounts[i]..<visualCount {
                    let lbl = SKLabelNode(text: emoji)
                    lbl.fontSize = 18
                    lbl.verticalAlignmentMode = .center
                    lbl.position = CGPoint(x: CGFloat.random(in: -4...4), y: CGFloat(j) * 20)
                    lbl.alpha = 0
                    lbl.setScale(0.3)
                    stackNode.addChild(lbl)
                    stackItemArrays[i].append(lbl)
                    lbl.run(SKAction.group([
                        SKAction.fadeIn(withDuration: 0.18),
                        SKAction.scale(to: 1.0, duration: 0.18),
                    ]))
                }
            } else {
                for _ in visualCount..<lastVisualCounts[i] {
                    guard let top = stackItemArrays[i].popLast() else { break }
                    top.run(SKAction.sequence([
                        SKAction.group([
                            SKAction.scale(to: 1.4, duration: 0.08),
                            SKAction.moveBy(x: CGFloat.random(in: -8...8), y: 8, duration: 0.08),
                        ]),
                        SKAction.group([
                            SKAction.fadeOut(withDuration: 0.15),
                            SKAction.moveBy(x: 0, y: 8, duration: 0.15),
                        ]),
                        SKAction.removeFromParent(),
                    ]))
                }
            }
            lastVisualCounts[i] = visualCount
        }
    }

    // MARK: - HUD

    private func setupHUD() {
        let pill = SKShapeNode(rectOf: CGSize(width: 160, height: 38), cornerRadius: 19)
        pill.fillColor   = SKColor(white: 0.0, alpha: 0.55)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.30)
        pill.lineWidth   = 1
        pill.position    = CGPoint(x: frame.midX, y: hudTopY + 10)
        pill.zPosition   = 9
        addChild(pill)

        let coinLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinLabel.fontSize = 20
        coinLabel.fontColor = .white
        coinLabel.verticalAlignmentMode = .center
        coinLabel.position  = CGPoint(x: frame.midX, y: hudTopY + 10)
        coinLabel.zPosition = 10
        coinLabel.name = "coinLabel"
        addChild(coinLabel)

        let rateLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        rateLabel.fontSize = 12
        rateLabel.fontColor = SKColor(white: 1.0, alpha: 0.80)
        rateLabel.position  = CGPoint(x: frame.midX, y: hudTopY - 18)
        rateLabel.zPosition = 10
        rateLabel.name = "rateLabel"
        addChild(rateLabel)

        let stockLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        stockLabel.fontSize = 12
        stockLabel.fontColor = SKColor(white: 1.0, alpha: 0.80)
        stockLabel.position  = CGPoint(x: frame.midX, y: hudTopY - 34)
        stockLabel.zPosition = 10
        stockLabel.name = "stockLabel"
        addChild(stockLabel)
    }

    // MARK: - Customer spawning

    private func startCustomerSpawning() {
        let spawn = SKAction.sequence([
            SKAction.wait(forDuration: 3.0, withRange: 1.0),
            SKAction.run { [weak self] in self?.spawnCustomer() },
        ])
        run(SKAction.repeatForever(spawn))
    }

    private static func availableMenus(for menuTier: Int) -> [String] {
        let all = ["🥬", "🥗", "🥘"]
        return Array(all.prefix(menuTier + 1))
    }

    private func spawnCustomer() {
        guard let store else { return }
        let menus = Self.availableMenus(for: store.stall.menuTier)
        let customer = CustomerNode(availableMenus: menus)
        customer.position = CGPoint(x: -40, y: groundY + 20)
        addChild(customer)

        customer.walkTo(x: frame.midX - 70) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let menus = Self.availableMenus(for: store.stall.menuTier)
                let desiredIndex = menus.firstIndex(of: customer.wantedMenu) ?? 0
                guard let price = store.sellItem(menuIndex: desiredIndex) else {
                    customer.showReaction(happy: false)
                    customer.walkTo(x: self.frame.width + 40) { customer.removeFromParent() }
                    return
                }
                // sellItem() already added price to pendingCoins.
                // Always show a bubble; cashier auto-pops it, player taps without one.
                self.spawnCoinBubble(at: customer.position, amount: price,
                                     autoPop: store.stall.autoCollectEnabled)
                customer.showReaction(happy: true)
                customer.walkTo(x: self.frame.width + 40) { customer.removeFromParent() }
            }
        }
    }

    private func spawnCoinBubble(at position: CGPoint, amount: Double, autoPop: Bool = false) {
        let bubble = CoinBubbleNode(amount: amount)
        bubble.position = CGPoint(x: position.x, y: position.y + 80)
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
            if let label = self.childNode(withName: "coinLabel") as? SKLabelNode {
                label.text = "₩\(Self.formatCoins(Int(store.stall.coins)))"
            }
            if let label = self.childNode(withName: "rateLabel") as? SKLabelNode {
                let rate = EarningsSystem.coinsPerSecond(for: store.stall)
                label.text = "⚡ \(String(format: "%.1f", rate))/s"
            }
            if let label = self.childNode(withName: "stockLabel") as? SKLabelNode {
                label.text = "🥬 창고: \(store.stall.warehouse)/\(store.stall.warehouseCapacity)"
            }
            self.syncProductStack(menuStock: store.stall.menuStock, menuTier: store.stall.menuTier)
            let activePlots = FarmSystem.activePlotCount(for: store.farm)
            self.syncFarmPlots(farm: store.farm, activePlots: activePlots)
            self.syncWarehouse(store: store)
            self.syncCookSlots(store: store)
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
