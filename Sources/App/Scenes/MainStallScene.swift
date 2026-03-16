import SpriteKit;
import GameCore;

final class MainStallScene: SKScene {
    weak var store: GameStore?;
    private var lastUpdateTime: TimeInterval = 0;

    override func didMove(to view: SKView) {
        backgroundColor = .init(red: 0.95, green: 0.98, blue: 0.92, alpha: 1);
        let label = SKLabelNode(text: "🥬 봄동 가게");
        label.fontSize = 36;
        label.position = CGPoint(x: frame.midX, y: frame.midY);
        addChild(label);
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime;
        lastUpdateTime = currentTime;
        Task { @MainActor [weak self] in
            self?.store?.tick(deltaTime: delta);
        }
    }
}
