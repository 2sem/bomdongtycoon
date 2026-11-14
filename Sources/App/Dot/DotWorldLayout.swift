import CoreGraphics

/// Where every band sits, in art pixels (top-down, `y = 0` at the top of the backdrop) and in
/// scene points. Pure arithmetic so it can be reasoned about without a scene.
struct DotWorldLayout: Equatable {
    static let width = 144
    static let backdropHeight = 56
    static let shopHeight = 64
    static let streetHeight = 32
    static let farmHeight = 72
    static let fullYardHeight = 24
    static let minYardHeight = 12

    let viewSize: CGSize
    let topInset: CGFloat
    let bottomInset: CGFloat
    /// Points per art pixel; a whole number of device pixels so every art pixel lands on the grid.
    let scale: CGFloat
    /// Scene point of art (0, 0): the backdrop's top-left corner in the centred 144 px column.
    let origin: CGPoint
    let yardHeight: Int

    var shopTop: Int { Self.backdropHeight }
    var streetTop: Int { shopTop + Self.shopHeight }
    var yardTop: Int { streetTop + Self.streetHeight }
    var farmTop: Int { yardTop + yardHeight }
    var grassTop: Int { farmTop + Self.farmHeight }

    /// Art-space x of the screen's left and right edges (the column itself spans 0...144).
    var leftEdge: CGFloat { -origin.x / scale }
    var rightEdge: CGFloat { (viewSize.width - origin.x) / scale }
    /// Art-space y (top-down) of the screen's top and bottom edges.
    var topEdge: CGFloat { (origin.y - viewSize.height) / scale }
    var bottomEdge: CGFloat { origin.y / scale }

    init(viewSize: CGSize, topInset: CGFloat, bottomInset: CGFloat, screenScale: CGFloat) {
        self.viewSize = viewSize
        self.topInset = topInset
        self.bottomInset = bottomInset

        let device = max(screenScale, 1)
        let unit = floor(viewSize.width * device / CGFloat(Self.width)) / device
        let scale = max(2, unit)
        self.scale = scale


        func snapped(_ v: CGFloat) -> CGFloat { (v * device).rounded() / device }

        let usableBottom = viewSize.height - bottomInset
        func stack(_ yard: Int) -> CGFloat {
            CGFloat(Self.shopHeight + Self.streetHeight + yard + Self.farmHeight) * scale
        }
        let maxShopTop = usableBottom - stack(Self.fullYardHeight)
        let desiredShopTop = topInset + CGFloat(Self.backdropHeight) * scale
        var shopScreenTop = min(desiredShopTop, maxShopTop)
        var yard = Self.fullYardHeight
        if maxShopTop < topInset {
            let deficit = Int(((topInset - maxShopTop) / scale).rounded(.up))
            yard = max(Self.minYardHeight, Self.fullYardHeight - deficit)
            shopScreenTop = usableBottom - stack(yard)
        }
        yardHeight = yard

        let backdropScreenTop = snapped(shopScreenTop - CGFloat(Self.backdropHeight) * scale)
        origin = CGPoint(x: snapped((viewSize.width - CGFloat(Self.width) * scale) / 2),
                         y: viewSize.height - backdropScreenTop)
    }

    /// Scene point -> root space (art px, y up).
    func rootPoint(fromScene p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale)
    }
}
