import SpriteKit

/// Trees, bushes and a fence on the grass below the farm. Fixed offsets from the farm's bottom
/// edge, so the same screen always gets the same garden; anything that would fall below the
/// screen is skipped.
@MainActor
final class GrassDecorNode: SKNode {

    private struct Item {
        let name: String
        let x: CGFloat
        let dy: Int
    }

    private static let items: [Item] = [
        Item(name: "dot_ground_tree", x: 18, dy: 46),
        Item(name: "dot_ground_tree", x: 126, dy: 52),
        Item(name: "dot_ground_bush", x: 52, dy: 40),
        Item(name: "dot_ground_fence_h", x: 66, dy: 34),
        Item(name: "dot_ground_fence_h", x: 82, dy: 34),
        Item(name: "dot_ground_fence_h", x: 98, dy: 34),
        Item(name: "dot_ground_bush", x: 92, dy: 44),
        Item(name: "dot_ground_bush", x: 108, dy: 22),
    ]

    init(layout: DotWorldLayout) {
        super.init()
        zPosition = 350
        let farmBottom = layout.grassTop
        for item in Self.items {
            let y = farmBottom + item.dy
            guard CGFloat(y) <= layout.bottomEdge else { continue }
            let sprite = dotSprite(item.name)
            sprite.position = feetPoint(item.x, CGFloat(y))
            sprite.zPosition = -CGFloat(y) / 1000
            addChild(sprite)
        }
        let columnLeft = layout.leftEdge
        let columnRight = layout.rightEdge
        // Side margins on wide screens carry a tree each, so the garden does not stop at the column.
        if columnLeft < -20, CGFloat(farmBottom + 46) <= layout.bottomEdge {
            place("dot_ground_tree", x: columnLeft + 14, y: farmBottom + 50)
        }
        if columnRight > 164, CGFloat(farmBottom + 46) <= layout.bottomEdge {
            place("dot_ground_tree", x: columnRight - 14, y: farmBottom + 46)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func place(_ name: String, x: CGFloat, y: Int) {
        let sprite = dotSprite(name)
        sprite.position = feetPoint(x.rounded(), CGFloat(y))
        addChild(sprite)
    }
}
