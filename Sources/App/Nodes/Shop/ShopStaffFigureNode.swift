import SpriteKit
import GameCore

/// A hired cashier or cook standing in the shop, idle or working. Purely
/// presentational: `ShopNode` positions it and pushes in a
/// `ShopStaffPresence.Figure`; it never takes a touch, so the bowl and field
/// hit tests are unaffected.
final class ShopStaffFigureNode: SKSpriteNode {

    enum Role {
        case cashier, cook
    }

    /// One pose's isorender measurement-table entry (3x render, trimmed):
    /// native px and the feet anchor as a fraction from the *bottom*, the
    /// same convention `ShopCustomerNode` uses. Numbers are the chibi cast's
    /// table from art PR #120.
    private struct PoseSpec {
        let imageName: String
        let nativeSize: CGSize
        let anchorPoint: CGPoint
    }

    private static func spec(_ role: Role, working: Bool) -> PoseSpec {
        switch (role, working) {
        case (.cashier, false):
            return PoseSpec(imageName: "cashier_idle", nativeSize: CGSize(width: 83, height: 151), anchorPoint: CGPoint(x: 0.5, y: 0.07907))
        case (.cashier, true):
            return PoseSpec(imageName: "cashier_working", nativeSize: CGSize(width: 105, height: 151), anchorPoint: CGPoint(x: 0.64286, y: 0.07907))
        case (.cook, false):
            return PoseSpec(imageName: "cook_idle", nativeSize: CGSize(width: 83, height: 185), anchorPoint: CGPoint(x: 0.5, y: 0.06454))
        case (.cook, true):
            return PoseSpec(imageName: "cook_working", nativeSize: CGSize(width: 123, height: 185), anchorPoint: CGPoint(x: 0.66260, y: 0.06454))
        }
    }

    /// Subtle dim for a figure under `ShopStaffPresence.lowEnergyThreshold`.
    private static let tiredBlend: CGFloat = 0.25

    private let role: Role
    private let scale: CGFloat
    private var applied: ShopStaffPresence.Figure?

    init(role: Role, fittingTo grid: IsoGrid) {
        self.role = role
        scale = ShopPropSpriteNode.isorenderScale(fittingTo: grid)
        super.init(texture: nil, color: .gray, size: .zero)
        isUserInteractionEnabled = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for ShopStaffFigureNode")
    }

    /// `nil` hides the figure. Skips all work when `figure` equals the last
    /// one applied.
    func apply(_ figure: ShopStaffPresence.Figure?) {
        guard figure != applied else { return }
        let previous = applied
        applied = figure
        guard let figure else {
            isHidden = true
            return
        }
        isHidden = false
        if previous?.isWorking != figure.isWorking {
            // Texture, size and anchor change together; swapping only the
            // texture would apply idle's anchor fraction to the wider
            // working frame and shift the feet off their cell.
            let pose = Self.spec(role, working: figure.isWorking)
            texture = SKTexture(imageNamed: pose.imageName)
            let width = pose.nativeSize.width * scale
            size = CGSize(width: width, height: width * (pose.nativeSize.height / pose.nativeSize.width))
            anchorPoint = pose.anchorPoint
        }
        colorBlendFactor = figure.isTired ? Self.tiredBlend : 0
    }
}
