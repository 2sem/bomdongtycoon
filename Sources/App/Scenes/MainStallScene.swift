import SpriteKit;
import GameCore;

final class MainStallScene: SKScene {

    // MARK: - Properties

    weak var store: GameStore?;

    /// Spiral-of-death guard: cap delta at 1/3 s so a long pause
    /// (background, debugger break) cannot inject hundreds of seconds
    /// of ticks in a single frame.
    private static let maxDelta: TimeInterval = 1.0 / 3.0;

    private var lastUpdateTime: TimeInterval = 0;
    private var coinBubbles: [CoinBubbleNode] = [];

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.95, green: 0.98, blue: 0.92, alpha: 1);
        setupStall();
        startCustomerSpawning();
    }

    // MARK: - Setup

    private func setupStall() {
        // Ground bar
        let ground = SKShapeNode(rectOf: CGSize(width: frame.width, height: 60));
        ground.fillColor = SKColor(red: 0.85, green: 0.75, blue: 0.6, alpha: 1);
        ground.strokeColor = .clear;
        ground.position = CGPoint(x: frame.midX, y: 80);
        addChild(ground);

        // Stall body
        let stall = SKShapeNode(rectOf: CGSize(width: 200, height: 100), cornerRadius: 12);
        stall.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1);
        stall.strokeColor = SKColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1);
        stall.lineWidth = 3;
        stall.position = CGPoint(x: frame.midX, y: frame.midY);
        stall.name = "stall";
        addChild(stall);

        // Stall name label
        let nameLabel = SKLabelNode(text: "🥬 봄동 가게");
        nameLabel.fontSize = 20;
        nameLabel.fontColor = .black;
        nameLabel.position = CGPoint(x: frame.midX, y: frame.midY);
        nameLabel.verticalAlignmentMode = .center;
        addChild(nameLabel);

        // Coin counter (HUD)
        let coinLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold");
        coinLabel.fontSize = 18;
        coinLabel.fontColor = SKColor(red: 0.6, green: 0.4, blue: 0.0, alpha: 1);
        coinLabel.position = CGPoint(x: frame.midX, y: frame.height - 80);
        coinLabel.name = "coinLabel";
        addChild(coinLabel);
    }

    // MARK: - Customer spawning

    private func startCustomerSpawning() {
        let spawn = SKAction.sequence([
            SKAction.wait(forDuration: 3.0, withRange: 1.0),
            SKAction.run { [weak self] in self?.spawnCustomer(); },
        ]);
        run(SKAction.repeatForever(spawn));
    }

    private func spawnCustomer() {
        guard let store = store else { return; }
        let customer = CustomerNode();
        customer.position = CGPoint(x: -40, y: frame.midY - 50);
        addChild(customer);

        // Walk to stall, collect coins, then walk off screen
        customer.walkTo(x: frame.midX - 60) { [weak self] in
            guard let self else { return; }
            let rate = EarningsSystem.coinsPerSecond(for: store.stall);
            let coinAmount = rate * 3.0;
            self.spawnCoinBubble(at: customer.position, amount: coinAmount);
            customer.walkTo(x: self.frame.width + 40) {
                customer.removeFromParent();
            };
        };
    }

    private func spawnCoinBubble(at position: CGPoint, amount: Double) {
        guard let store = store else { return; }
        let bubble = CoinBubbleNode(amount: amount);
        bubble.position = CGPoint(x: position.x, y: position.y + 60);
        addChild(bubble);
        coinBubbles.append(bubble);

        if store.stall.autoCollectEnabled {
            bubble.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.8),
                SKAction.run { [weak self] in
                    guard let self else { return; }
                    Task { @MainActor in
                        store.stall.pendingCoins += amount;
                        store.collectCoins();
                    };
                    bubble.pop();
                    self.coinBubbles.removeAll { $0 === bubble };
                },
            ]));
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let store = store else { return; }
        let location = touch.location(in: self);

        for bubble in coinBubbles where bubble.contains(location) {
            Task { @MainActor in
                store.stall.pendingCoins += bubble.amount;
                store.collectCoins();
            };
            bubble.pop();
            coinBubbles.removeAll { $0 === bubble };
            return;
        }
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime;
        let delta = min(rawDelta, Self.maxDelta);
        lastUpdateTime = currentTime;

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return; }
            store.tick(deltaTime: delta);
            if let label = self.childNode(withName: "coinLabel") as? SKLabelNode {
                label.text = "💰 \(Int(store.stall.coins))";
            }
        };
    }
}
