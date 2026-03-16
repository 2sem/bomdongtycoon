import SwiftUI;

public struct UpgradeSheet: View {
    @Binding var isPresented: Bool;

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented;
    }

    public var body: some View {
        EmptyView();
    }
}
