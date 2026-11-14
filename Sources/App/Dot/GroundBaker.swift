import SpriteKit
import UIKit

/// Bakes the grass field, the street strip and the yard path into one texture, so the ground is
/// a single sprite however wide or tall the screen is. Drawn 1:1 in art pixels, never resampled.
@MainActor
enum GroundBaker {

    static func makeNode(layout: DotWorldLayout, locationTier: Int) -> SKSpriteNode {
        let tile = 16
        let originX = Int((layout.leftEdge / CGFloat(tile)).rounded(.down)) * tile
        let endX = Int((layout.rightEdge / CGFloat(tile)).rounded(.up)) * tile
        let originY = layout.shopTop
        let endY = originY + Int(((layout.bottomEdge - CGFloat(originY)) / CGFloat(tile)).rounded(.up)) * tile
        let size = CGSize(width: endX - originX, height: max(endY - originY, tile))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            ctx.cgContext.interpolationQuality = .none
            func draw(_ name: String, x: Int, y: Int) {
                UIImage(named: name)?.draw(in: CGRect(x: x - originX, y: y - originY, width: tile, height: tile))
            }
            for y in stride(from: originY, to: originY + Int(size.height), by: tile) {
                for x in stride(from: originX, to: endX, by: tile) {
                    let h = dotHash(x / tile, y / tile)
                    draw(h % 9 == 0 ? "dot_ground_grass_flower_\(h / 9 % 2)" : "dot_ground_grass_\(h % 3)", x: x, y: y)
                }
            }
            let streetName = ["dot_ground_street_alley", "dot_ground_street_market", "dot_ground_street_gangnam"][min(max(locationTier, 0), 2)]
            for row in 0..<(DotWorldLayout.streetHeight / tile) {
                for x in stride(from: originX, to: endX, by: tile) {
                    let col = Int((Double(x) / Double(tile)).rounded(.down))
                    let crossing = locationTier == 2 && (6...7).contains(col)
                    draw(crossing ? "dot_ground_street_gangnam_crosswalk" : streetName, x: x, y: layout.streetTop + row * tile)
                }
            }
            let pathY = layout.yardTop + max(0, (layout.yardHeight - tile) / 2)
            for x in stride(from: originX, to: endX, by: tile) { draw("dot_ground_path", x: x, y: pathY) }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        let node = SKSpriteNode(texture: texture, size: size)
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.position = artPoint(CGFloat(originX), CGFloat(originY))
        return node
    }
}
