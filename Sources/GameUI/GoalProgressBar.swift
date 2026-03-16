import SwiftUI;

public struct GoalProgressBar: View {
    @Binding var showUpgrades: Bool;

    public init(showUpgrades: Binding<Bool>) {
        self._showUpgrades = showUpgrades;
    }

    public var body: some View {
        EmptyView();
    }
}
