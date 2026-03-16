import SpriteKit
import GameCore

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
    private let farmNode = SKNode()
    private var lastFarmUpgradeTier = -1

    // Product stack
    private let productStackNode = SKNode()
    private var stackItems: [SKLabelNode] = []
    private var lastVisualCount = -1
    private var lastMenuTierForStack = -1

    private static func formatCoins(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000     { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private static func stallEmoji(for tier: Int) -> String {
        switch tier {
        case 0:  "⛺"   // 포장마차
        case 1:  "🏪"   // 분식집
        default: "🏬"   // 봄동 전문점
        }
    }

    // Layout anchors — proportional for all iPhone sizes
    private var groundY:  CGFloat { frame.height * 0.30 }
    private var stallY:   CGFloat { groundY + 58 }   // tent base sits on grass
    private var hudTopY:  CGFloat { frame.height - 140 }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.62, green: 0.85, blue: 1.0, alpha: 1)
        setupBackground()
        setupFarm()
        setupStall()
        setupProductStack()
        setupHUD()
        startCustomerSpawning()
    }

    // MARK: - Background

    private func setupBackground() {
        // Pavement
        let pavement = SKSpriteNode(
            color: SKColor(red: 0.76, green: 0.78, blue: 0.74, alpha: 1),
            size: CGSize(width: frame.width, height: groundY * 2)
        )
        pavement.position = CGPoint(x: frame.midX, y: groundY * 0.5)
        pavement.zPosition = -5
        addChild(pavement)

        // Grass strip at pavement top
        let grass = SKSpriteNode(
            color: SKColor(red: 0.40, green: 0.72, blue: 0.28, alpha: 1),
            size: CGSize(width: frame.width, height: 18)
        )
        grass.position = CGPoint(x: frame.midX, y: groundY)
        grass.zPosition = -4
        addChild(grass)

        // Spring flowers along grass
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

        // Clouds
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

        // Slow drift
        cloud.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 25, y: 0, duration: 7),
            SKAction.moveBy(x: -25, y: 0, duration: 7)
        ])))
    }

    // MARK: - Farm

    /// Bottom of the usable area — above home indicator on Face ID iPhones.
    private var safeBottom: CGFloat {
        view?.safeAreaInsets.bottom ?? 0
    }

    private func setupFarm() {
        let safeBase  = safeBottom          // e.g. 34 pt on iPhone with home indicator
        let soilHeight: CGFloat = 72
        let soilY = safeBase + soilHeight / 2

        // Fill below safe area with matching soil colour so no gap shows
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

        // Thin divider line between pavement and soil
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

    private func syncFarmPlots(farm: FarmState, activePlots: Int) {
        // Add new plot nodes as farm expands
        while farmPlotNodes.count < activePlots {
            let node = FarmPlotNode()
            farmNode.addChild(node)
            farmPlotNodes.append(node)
        }

        // Reposition all active plots evenly
        let spacing: CGFloat = 60
        let totalWidth = CGFloat(activePlots - 1) * spacing
        for i in 0..<activePlots {
            farmPlotNodes[i].position = CGPoint(x: -totalWidth / 2 + CGFloat(i) * spacing, y: 0)
            farmPlotNodes[i].isHidden = false
            if i < farm.plots.count {
                farmPlotNodes[i].update(plot: farm.plots[i])
            }
        }
        for i in activePlots..<farmPlotNodes.count {
            farmPlotNodes[i].isHidden = true
        }
    }

    // MARK: - Stall

    private func setupStall() {
        // Main stall emoji — ⛺ gives perfect포장마차 vibe
        let stallEmoji = SKLabelNode(text: "⛺")
        stallEmoji.fontSize = 110
        stallEmoji.verticalAlignmentMode = .center
        stallEmoji.position = CGPoint(x: frame.midX, y: stallY + 10)
        stallEmoji.zPosition = 1
        stallEmoji.name = "stallEmoji"
        addChild(stallEmoji)

        // Sign board under the tent
        // Sign board — hangs ABOVE the tent so it never overlaps customers or emotions
        let signY = stallY + 80
        let signBg = SKShapeNode(rectOf: CGSize(width: 170, height: 32), cornerRadius: 8)
        signBg.fillColor = SKColor(red: 0.12, green: 0.48, blue: 0.22, alpha: 1)
        signBg.strokeColor = SKColor(red: 0.08, green: 0.32, blue: 0.15, alpha: 1)
        signBg.lineWidth = 2
        signBg.position = CGPoint(x: frame.midX, y: signY)
        signBg.zPosition = 2
        addChild(signBg)

        let signLabel = SKLabelNode(text: "🥬 봄동 가게")
        signLabel.fontName = "AppleSDGothicNeo-Bold"
        signLabel.fontSize = 15
        signLabel.fontColor = .white
        signLabel.verticalAlignmentMode = .center
        signLabel.position = CGPoint(x: frame.midX, y: signY)
        signLabel.zPosition = 3
        signLabel.name = "signLabel"
        addChild(signLabel)

    }

    private func updateSignLabel() {
        guard let store,
              let label = childNode(withName: "signLabel") as? SKLabelNode else { return }
        label.text = "🥬 \(store.progress.shopName)"
    }

    // MARK: - Product stack

    private func setupProductStack() {
        // Stack sits above the sign (stallY + 80), items grow upward
        productStackNode.position = CGPoint(x: frame.midX, y: stallY + 100)
        productStackNode.zPosition = 3
        addChild(productStackNode)
    }

    private func syncProductStack(stock: Int, menuTier: Int) {
        let visualCount = min(stock, 6)
        let emoji = Self.availableMenus(for: menuTier).last ?? "🥬"

        // Rebuild entirely when menu tier changes (new emoji)
        if menuTier != lastMenuTierForStack {
            stackItems.forEach { $0.removeFromParent() }
            stackItems.removeAll()
            lastVisualCount = 0
            lastMenuTierForStack = menuTier
        }

        guard visualCount != lastVisualCount else { return }

        if visualCount > lastVisualCount {
            // New item produced — pop in on top
            for i in lastVisualCount..<visualCount {
                let label = SKLabelNode(text: emoji)
                label.fontSize = 20
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: CGFloat.random(in: -5...5), y: CGFloat(i) * 22)
                label.alpha = 0
                label.setScale(0.3)
                productStackNode.addChild(label)
                stackItems.append(label)
                label.run(SKAction.group([
                    SKAction.fadeIn(withDuration: 0.18),
                    SKAction.scale(to: 1.0, duration: 0.18),
                ]))
            }
        } else {
            // Item sold — pop top item off with a little bounce
            for _ in visualCount..<lastVisualCount {
                guard let top = stackItems.popLast() else { break }
                top.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.scale(to: 1.4, duration: 0.08),
                        SKAction.moveBy(x: CGFloat.random(in: -10...10), y: 10, duration: 0.08),
                    ]),
                    SKAction.group([
                        SKAction.fadeOut(withDuration: 0.18),
                        SKAction.moveBy(x: 0, y: 10, duration: 0.18),
                    ]),
                    SKAction.removeFromParent(),
                ]))
            }
        }
        lastVisualCount = visualCount
    }

    // MARK: - HUD

    private func setupHUD() {
        // Frosted pill backing for the coin display
        let pill = SKShapeNode(rectOf: CGSize(width: 160, height: 38), cornerRadius: 19)
        pill.fillColor = SKColor(white: 0.0, alpha: 0.55)
        pill.strokeColor = SKColor(white: 1.0, alpha: 0.30)
        pill.lineWidth = 1
        pill.position = CGPoint(x: frame.midX, y: hudTopY + 10)
        pill.zPosition = 9
        addChild(pill)

        let coinLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinLabel.fontSize = 20
        coinLabel.fontColor = .white
        coinLabel.verticalAlignmentMode = .center
        coinLabel.position = CGPoint(x: frame.midX, y: hudTopY + 10)
        coinLabel.zPosition = 10
        coinLabel.name = "coinLabel"
        addChild(coinLabel)

        let rateLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        rateLabel.fontSize = 12
        rateLabel.fontColor = SKColor(white: 1.0, alpha: 0.80)
        rateLabel.position = CGPoint(x: frame.midX, y: hudTopY - 18)
        rateLabel.zPosition = 10
        rateLabel.name = "rateLabel"
        addChild(rateLabel)

        let stockLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        stockLabel.fontSize = 12
        stockLabel.fontColor = SKColor(white: 1.0, alpha: 0.80)
        stockLabel.position = CGPoint(x: frame.midX, y: hudTopY - 34)
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

    /// Maps menuTier to the emoji menu items the shop currently sells.
    private static func availableMenus(for menuTier: Int) -> [String] {
        let all = ["🥬", "🥗", "🥘"]
        return Array(all.prefix(menuTier + 1))
    }

    private func spawnCustomer() {
        guard let store = store else { return }
        let menus = Self.availableMenus(for: store.stall.menuTier)
        let customer = CustomerNode(availableMenus: menus)
        customer.position = CGPoint(x: -40, y: groundY + 20)
        addChild(customer)

        customer.walkTo(x: frame.midX - 70) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard store.stall.stock >= 1.0 else {
                    customer.showReaction(happy: false)
                    customer.walkTo(x: self.frame.width + 40) { customer.removeFromParent() }
                    return
                }
                store.stall.stock -= 1.0
                let price = EarningsSystem.pricePerItem(for: store.stall)
                self.spawnCoinBubble(at: customer.position, amount: price)
                customer.showReaction(happy: true)
                customer.walkTo(x: self.frame.width + 40) { customer.removeFromParent() }
            }
        }
    }

    private func spawnCoinBubble(at position: CGPoint, amount: Double) {
        guard let store = store else { return }
        let bubble = CoinBubbleNode(amount: amount)
        bubble.position = CGPoint(x: position.x, y: position.y + 80)
        addChild(bubble)
        coinBubbles.append(bubble)

        if store.stall.autoCollectEnabled {
            bubble.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.8),
                SKAction.run { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        store.stall.pendingCoins += amount
                        store.collectCoins()
                    }
                    bubble.pop()
                    self.coinBubbles.removeAll { $0 === bubble }
                },
            ]))
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let store = store else { return }
        let location = touch.location(in: self)

        for bubble in coinBubbles where bubble.contains(location) {
            Task { @MainActor in
                store.stall.pendingCoins += bubble.amount
                store.collectCoins()
            }
            bubble.pop()
            coinBubbles.removeAll { $0 === bubble }
            return
        }

        // Farm plot tap — plant seed on empty, harvest when ready
        let activePlots = FarmSystem.activePlotCount(for: store.farm)
        let nodeLocation = farmNode.convert(location, from: self)
        for i in 0..<min(activePlots, farmPlotNodes.count) {
            guard farmPlotNodes[i].contains(nodeLocation) else { continue }
            let plot = store.farm.plots[i]
            if plot.isReady {
                Task { @MainActor in store.harvest(plotIndex: i) }
                farmPlotNodes[i].animateHarvest()
            } else if !plot.isPlanted {
                Task { @MainActor in store.plantSeed(plotIndex: i) }
            }
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
                let formatted = Self.formatCoins(Int(store.stall.coins))
                label.text = "🪙 \(formatted)"
            }
            if let label = self.childNode(withName: "rateLabel") as? SKLabelNode {
                let rate = EarningsSystem.coinsPerSecond(for: store.stall)
                label.text = "⚡ \(String(format: "%.1f", rate))/s"
            }
            if let label = self.childNode(withName: "stockLabel") as? SKLabelNode {
                let stock = Int(store.stall.stock)
                let maxStock = EarningsSystem.maxStock(for: store.stall)
                label.text = "🥬 \(stock)/\(maxStock)"
            }
            self.syncProductStack(stock: Int(store.stall.stock), menuTier: store.stall.menuTier)
            let activePlots = FarmSystem.activePlotCount(for: store.farm)
            self.syncFarmPlots(farm: store.farm, activePlots: activePlots)
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
