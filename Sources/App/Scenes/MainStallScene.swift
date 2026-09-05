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
    private let groundLayer = GroundLayer()
    private let fieldLayer = FieldLayer()
    private let farmerLayer = FarmerLayer()
    private let shopWallLayer = ShopWallLayer()
    private let kitchenLayer = KitchenLayer()

    override func didMove(to view: SKView) {
        backgroundColor = GroundTile.fillColor
        addChild(groundLayer)
        groundLayer.layout(for: frame.size)

        fieldLayer.zPosition = 10
        addChild(fieldLayer)
        fieldLayer.layout(for: frame.size)

        // Same base zPosition as fieldLayer so FarmerLayer's local row-based zPosition
        // (see FarmerLayer.layout) compares directly against FieldLayer's plot zPositions.
        farmerLayer.zPosition = 10
        addChild(farmerLayer)
        farmerLayer.layout(for: frame.size)

        // Same base zPosition as fieldLayer/farmerLayer; ShopWallLayer's own zPosition
        // formula (see ShopWallNode.swift) shares FieldLayer's row-based scale, so the
        // shop's walls — which now stack directly in front of the field along the row axis
        // and share its column range — sort correctly against the field's plots.
        shopWallLayer.zPosition = 10
        addChild(shopWallLayer)
        shopWallLayer.layout(for: frame.size)

        // Same base zPosition as the other shop-area layers; KitchenLayer's own zPosition
        // formula (see KitchenNode.swift) shares ShopWallLayer's row-based scale, so the
        // kitchen sorts correctly against the shop's walls and the field behind it.
        kitchenLayer.zPosition = 10
        addChild(kitchenLayer)
        kitchenLayer.layout(for: frame.size)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        groundLayer.layout(for: size)
        fieldLayer.layout(for: size)
        farmerLayer.layout(for: size)
        shopWallLayer.layout(for: size)
        kitchenLayer.layout(for: size)
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
