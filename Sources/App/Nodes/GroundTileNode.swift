import SpriteKit

enum GroundTile {
    static let width: CGFloat = 64
    static let height: CGFloat = 32
    static let skew: CGFloat = width / 4

    static let fillColor = SKColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 1)
    static let strokeColor = SKColor(red: 0.2, green: 0.19, blue: 0.16, alpha: 1)

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width + skew, y: height))
        path.addLine(to: CGPoint(x: skew, y: height))
        path.closeSubpath()
        return path
    }()
}

final class GroundLayer: SKNode {

    func layout(for size: CGSize) {
        removeAllChildren()

        let marginColumns = 2
        let marginRows = 1

        let columnCount = Int(ceil(size.width / GroundTile.width)) + marginColumns * 2
        let rowCount = Int(ceil(size.height / GroundTile.height)) + marginRows * 2
        let startColumn = -marginColumns
        let startRow = -marginRows

        for row in 0..<rowCount {
            for column in 0..<columnCount {
                let tile = SKShapeNode(path: GroundTile.path)
                tile.fillColor = GroundTile.fillColor
                tile.strokeColor = GroundTile.strokeColor
                tile.lineWidth = 1.5
                tile.position = CGPoint(
                    x: CGFloat(startColumn + column) * GroundTile.width,
                    y: CGFloat(startRow + row) * GroundTile.height
                )
                addChild(tile)
            }
        }
    }
}
