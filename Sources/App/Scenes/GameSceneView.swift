import SwiftUI
import SpriteKit
import GameCore

struct GameSceneView: View {
    @EnvironmentObject var store: GameStore
    /// Space under the world reserved for the tab bar (plus the home indicator, added here).
    var bottomReserve: CGFloat = 70
    /// Global point of the HUD coin badge's centre, where flying coins land.
    var coinTarget: CGPoint?
    var isStorefrontHeld = false
    @State private var scene: DotWorldScene = {
        let s = DotWorldScene()
        s.scaleMode = .resizeFill
        return s
    }()

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene)
                .ignoresSafeArea()
                .onAppear {
                    scene.store = store
                    updateInsets(geo.safeAreaInsets)
                }
                .onChange(of: geo.safeAreaInsets) { _, insets in updateInsets(insets) }
                .onChange(of: isStorefrontHeld) { _, held in scene.isStorefrontHeld = held }
                .onChange(of: coinTarget) { _, point in
                    if let point { scene.coinTarget = point }
                }
        }
    }

    /// The HUD is a top `safeAreaInset`, so the safe-area top is exactly where it ends.
    private func updateInsets(_ insets: EdgeInsets) {
        scene.topInset = insets.top
        scene.bottomInset = insets.bottom + bottomReserve
    }
}
