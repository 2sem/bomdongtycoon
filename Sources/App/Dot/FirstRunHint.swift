import SpriteKit
import SwiftUI
import UIKit
import GameCore

/// The first-time actions the pointer teaches. Done-flags live in UserDefaults, not the save,
/// so a prestige or a restored save never replays them.
enum FirstRunHint: String, CaseIterable {
    case harvest, plant, cook
    /// A second tap on a cooking dish; the pointer stays on the dish until the player has tapped it once more.
    case hurry
    /// The first full fever gauge of an install (pointer on the button plus a toast).
    case fever

    private var key: String { "dot.hint.done.\(rawValue)" }
    var isDone: Bool { UserDefaults.standard.bool(forKey: key) }
    func markDone() { UserDefaults.standard.set(true, forKey: key) }

    /// The one-line toast that goes with the cook/hurry pointer, and how many times the sleeping-worker
    /// tip has been shown. Kept with the hints so a restored save never replays them.
    static let hurryToastKey = "dot.hint.hurryToast"
    static let wakeHintKey = "dot.hint.wakeCount"

    /// Accepted flyers on this install. The appear hint and the use toast stop at `flyerHintLimit`;
    /// the button pulses until the first.
    static let flyerUseKey = "dot.hint.flyerUseCount"
    static let flyerHintLimit = 3

    /// DEBUG `-dotResetHints` replays them on a seeded save.
    static func resetForDebug() {
        for hint in allCases { UserDefaults.standard.removeObject(forKey: hint.key) }
        UserDefaults.standard.removeObject(forKey: "dot.hint.missionPointerCount")
        UserDefaults.standard.removeObject(forKey: hurryToastKey)
        UserDefaults.standard.removeObject(forKey: wakeHintKey)
        UserDefaults.standard.removeObject(forKey: flyerUseKey)
    }
}

/// A small procedural pixel arrow that bobs over what to tap next; static under Reduce Motion.
@MainActor
final class HintArrowNode: SKNode {

    static let rows = [
        ".#######.",
        "#ggggggg#",
        "#ggggggg#",
        ".#ggggg#.",
        "..#ggg#..",
        "...#g#...",
        "....#....",
    ]

    private static let texture: SKTexture = {
        let ink = UIColor(red: 0x2b / 255, green: 0x1b / 255, blue: 0x2e / 255, alpha: 1)
        let gold = UIColor(red: 0xf4 / 255, green: 0xb9 / 255, blue: 0x3a / 255, alpha: 1)
        let size = CGSize(width: 9, height: rows.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            for (y, row) in rows.enumerated() {
                for (x, c) in row.enumerated() where c != "." {
                    (c == "#" ? ink : gold).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }()

    private let bob = SKNode()

    override init() {
        super.init()
        let sprite = SKSpriteNode(texture: Self.texture)
        sprite.size = Self.texture.size()
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        bob.addChild(sprite)
        addChild(bob)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// `tip` is where the arrow's point lands, in root space; nil hides it.
    func show(tip: CGPoint?, animated: Bool) {
        guard let tip else {
            isHidden = true
            bob.removeAllActions()
            return
        }
        isHidden = false
        position = CGPoint(x: tip.x.rounded(.down) + 0.5, y: tip.y.rounded())
        if animated {
            guard bob.action(forKey: "bob") == nil else { return }
            bob.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.3), .wait(forDuration: 0.15),
                                              .moveBy(x: 0, y: -2, duration: 0.3), .wait(forDuration: 0.15)])),
                    withKey: "bob")
        } else {
            bob.removeAllActions()
            bob.position = .zero
        }
    }
}

/// The same arrow for SwiftUI, pointing down at a button; bobs unless Reduce Motion is on.
struct HintArrowView: View {
    var pixel: CGFloat = 4
    @State private var isUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, _ in
            let p = pixel
            for (y, row) in HintArrowNode.rows.enumerated() {
                for (x, c) in row.enumerated() where c != "." {
                    let color: Color = c == "#" ? Color(red: 0x2b / 255, green: 0x1b / 255, blue: 0x2e / 255)
                                                : Color(red: 0xf4 / 255, green: 0xb9 / 255, blue: 0x3a / 255)
                    context.fill(Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: p, height: p)), with: .color(color))
                }
            }
        }
        .frame(width: 9 * pixel, height: CGFloat(HintArrowNode.rows.count) * pixel)
        .offset(y: isUp && !reduceMotion ? -6 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { isUp = true }
        }
        .accessibilityHidden(true)
    }
}
