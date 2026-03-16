import SwiftUI;
import SpriteKit;
import GameCore;

struct GameSceneView: View {
    @EnvironmentObject var store: GameStore;

    var body: some View {
        SpriteViewWrapper(store: store);
    }
}

private struct SpriteViewWrapper: View {
    let store: GameStore;
    @State private var scene: MainStallScene = {
        let s = MainStallScene();
        s.scaleMode = .resizeFill;
        return s;
    }();

    var body: some View {
        SpriteView(scene: scene)
            .onAppear { scene.store = store; };
    }
}
