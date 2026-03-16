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
        setupStall()
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

        // Display items on counter
        // Display items on the counter (ground level, in front of stall)
        let items = ["🥬", "🥗", "🥘"]
        for (i, item) in items.enumerated() {
            let label = SKLabelNode(text: item)
            label.fontSize = 20
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: frame.midX + CGFloat(i - 1) * 36, y: groundY + 18)
            label.zPosition = 2
            addChild(label)
        }
    }

    private func updateSignLabel() {
        guard let store,
              let label = childNode(withName: "signLabel") as? SKLabelNode else { return }
        label.text = "🥬 \(store.progress.shopName)"
    }

    // MARK: - HUD

    private func setupHUD() {
        let coinLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        coinLabel.fontSize = 18
        coinLabel.fontColor = SKColor(red: 0.55, green: 0.35, blue: 0.0, alpha: 1)
        coinLabel.position = CGPoint(x: frame.midX, y: hudTopY)
        coinLabel.zPosition = 10
        coinLabel.name = "coinLabel"
        addChild(coinLabel)

        let rateLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        rateLabel.fontSize = 13
        rateLabel.fontColor = SKColor(red: 0.2, green: 0.55, blue: 0.2, alpha: 1)
        rateLabel.position = CGPoint(x: frame.midX, y: hudTopY - 24)
        rateLabel.zPosition = 10
        rateLabel.name = "rateLabel"
        addChild(rateLabel)

        let stockLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        stockLabel.fontSize = 13
        stockLabel.fontColor = SKColor(red: 0.15, green: 0.50, blue: 0.15, alpha: 1)
        stockLabel.position = CGPoint(x: frame.midX, y: hudTopY - 44)
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

    private func spawnCustomer() {
        guard let store = store else { return }
        let customer = CustomerNode()
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
                label.text = "💰 \(Int(store.stall.coins))"
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
