import SpriteKit

/// The shop's back-most footprint row, right in front of the back wall — reserved for a
/// future kitchen setup (table, cook, cooking props). Left empty for now while that visual
/// design is reworked; not wired to any gameplay/staff-hire state (see `StallState.menuCooks`).
final class KitchenLayer: SKNode {
    func layout(for size: CGSize) {
        removeAllChildren()
    }
}
