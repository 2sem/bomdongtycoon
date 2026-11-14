import SpriteKit
import UIKit

/// Every texture in the dot world goes through here so it is cached once and always `.nearest`.
@MainActor
enum DotTexture {
    private static var cache: [String: SKTexture] = [:]

    static func named(_ name: String) -> SKTexture {
        if let cached = cache[name] { return cached }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .nearest
        cache[name] = texture
        return texture
    }

    static func frames(_ base: String, count: Int) -> [SKTexture] {
        (0..<count).map { named("\(base)_\($0)") }
    }
}

/// Which art pixel of a sprite sits on its node position. `.feet` is the manifest's default:
/// bottom centre, `(w/2, h-1)`.
enum DotAnchor {
    case feet
    case topLeft
    case bottomLeft
    case pixel(Int, Int)
}

/// Positions are in root space: x right in art px, y up, so art row `y` (top-down) is `-y`.
func artPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: -y) }

/// Ground point of art pixel (px, py): the bottom-centre of that pixel, which is exactly where
/// the manifest's `anchorPoint` formula puts a sprite's anchor pixel.
func feetPoint(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: px + 0.5, y: -(py + 1)) }

@MainActor
func dotSprite(_ name: String, anchor: DotAnchor = .feet) -> SKSpriteNode {
    let texture = DotTexture.named(name)
    let sprite = SKSpriteNode(texture: texture)
    sprite.size = texture.size()
    let w = texture.size().width
    let h = texture.size().height
    switch anchor {
    case .feet:       sprite.anchorPoint = CGPoint(x: (floor(w / 2) + 0.5) / w, y: 0)
    case .topLeft:    sprite.anchorPoint = CGPoint(x: 0, y: 1)
    case .bottomLeft: sprite.anchorPoint = .zero
    case .pixel(let ax, let ay):
        sprite.anchorPoint = CGPoint(x: (CGFloat(ax) + 0.5) / w, y: 1 - CGFloat(ay + 1) / h)
    }
    return sprite
}

/// Stable per-cell pseudo-random value: decoration must not move between launches or rebuilds.
func dotHash(_ a: Int, _ b: Int, _ salt: Int = 0) -> Int {
    var h = UInt32(truncatingIfNeeded: a &* 73_856_093) ^ UInt32(truncatingIfNeeded: b &* 19_349_663)
    h ^= UInt32(truncatingIfNeeded: salt &* 83_492_791)
    h = (h ^ (h >> 13)) &* 1_274_126_177
    return Int((h ^ (h >> 16)) & 0x7fff_ffff)
}

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }

    func multiplied(by other: SKColor) -> SKColor {
        var (r1, g1, b1, a1) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        var (r2, g2, b2, a2) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(red: r1 * r2, green: g1 * g2, blue: b1 * b2, alpha: 1)
    }

    func mixed(with other: SKColor, _ t: CGFloat) -> SKColor {
        var (r1, g1, b1, a1) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        var (r2, g2, b2, a2) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return SKColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}
