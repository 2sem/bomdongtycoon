import SpriteKit

/// A horizontal band of the world. Children use band-local art coordinates (x right, y down from
/// the band's top), expressed through `artPoint` / `feetPoint` like everything else.
@MainActor
class BandNode: SKNode {
    let top: Int

    init(top: Int) {
        self.top = top
        super.init()
        position = artPoint(0, CGFloat(top))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func rootPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: -(CGFloat(top) + y))
    }

    /// Root point -> band-local art coordinates (y down).
    func local(fromRoot p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: -p.y - CGFloat(top))
    }
}
