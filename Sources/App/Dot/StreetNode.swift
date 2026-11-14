import SpriteKit

/// The street band. The ground itself is baked into the shared ground texture; this node only
/// hosts customers, which stand in front of the counter, hence above the shop's z.
@MainActor
final class StreetNode: BandNode {
    init(layout: DotWorldLayout) {
        super.init(top: layout.streetTop)
        zPosition = 200
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}
