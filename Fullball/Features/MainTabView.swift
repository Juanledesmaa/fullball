import SwiftUI

/// The app shell: persistent wallet bar above a four-tab `TabView`.
struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var showBuyGems = false

    var body: some View {
        @Bindable var nav = container.navigator
        return VStack(spacing: 0) {
            WalletBar(wallet: container.wallet.wallet) { showBuyGems = true }
            TabView(selection: $nav.tab) {
                PackOpeningView(container: container)
                    .tag(0)
                    .tabItem { Label("Scout", systemImage: "binoculars.fill") }
                MarketView(container: container)
                    .tag(1)
                    .tabItem { Label("Market", systemImage: "dollarsign.circle.fill") }
                CollectionView(container: container)
                    .tag(2)
                    .tabItem { Label("Roster", systemImage: "person.3.fill") }
                LiveMatchesView(container: container)
                    .tag(3)
                    .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }
                LeaderboardView(container: container)
                    .tag(4)
                    .tabItem { Label("Agencies", systemImage: "trophy.fill") }
            }
            .tint(WC.coral)
        }
        .background(WC.screenBG.ignoresSafeArea())
        .alert("Coming soon", isPresented: $showBuyGems) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Gem purchases aren't available in this preview build. Earn Gems and Tickets through the live loop instead.")
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppContainer.preview())
}
