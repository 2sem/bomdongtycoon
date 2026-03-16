import SwiftUI;
import GameCore;

@main
struct BomDongTycoonApp: App {
    @StateObject private var store = GameStore();

    init() {
        NotificationManager.requestPermission();
    }

    var body: some Scene {
        WindowGroup {
            GameRootView()
                .environmentObject(store);
        }
    }
}
