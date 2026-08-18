import SpriteKit
import GameCore

extension Notification.Name {
    static let openStaffSheet = Notification.Name("openStaffSheet")
    static let openJobSheet = Notification.Name("openJobSheet")
}

final class MainStallScene: SKScene {

    weak var store: GameStore?

    private static let maxDelta: TimeInterval = 1.0 / 3.0
    private var lastUpdateTime: TimeInterval = 0

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.85, alpha: 1)
    }

    override func update(_ currentTime: TimeInterval) {
        let rawDelta = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        let delta = min(rawDelta, Self.maxDelta)
        lastUpdateTime = currentTime

        Task { @MainActor [weak self] in
            guard let self, let store = self.store else { return }
            store.tick(deltaTime: delta)
        }
    }
}
