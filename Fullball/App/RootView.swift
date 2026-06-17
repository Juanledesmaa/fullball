import SwiftUI
import SwiftData

/// Gates the app behind Sign in with Apple, then builds the `AppContainer`
/// from the environment model context and shows the tab shell.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth: any AuthService = FirebaseAuthService()
    @State private var container: AppContainer?
    @AppStorage("didSeeIntro") private var didSeeIntro = false

    var body: some View {
        Group {
            if auth.currentUser == nil {
                SignInView(auth: auth)
            } else if let container {
                MainTabView()
                    .environment(container)
                    .environment(\.playerImageStore, container.imageStore)
                    .fullScreenCover(isPresented: Binding(
                        get: { !didSeeIntro },
                        set: { if $0 { didSeeIntro = false } })) {
                        LoopIntroView { didSeeIntro = true }
                    }
            } else {
                ProgressView().tint(WC.coral)
            }
        }
        .task(id: auth.currentUser?.uid) {
            guard auth.currentUser != nil, container == nil else { return }
            let c = await AppContainer.bootstrap(context: modelContext,
                                                 uid: auth.currentUser?.uid,
                                                 userName: auth.currentUser?.displayName,
                                                 loader: FirestoreCatalogLoader(client: FirestoreClient()))
            // Launch-arg demo seed for UI verification only (`-seedDemo 1`).
            if UserDefaults.standard.bool(forKey: "seedDemo"), c.collection.owned().isEmpty {
                let seeded = Array(c.catalog.cards.prefix(14))
                for card in seeded { c.collection.acquire(cardID: card.id) }
                // Own + field clients from the first live match's nations
                // so the earners row is populated for the demo.
                if let first = c.slate.fixtures.first(where: { $0.status == .live }) {
                    let picks = c.catalog.cards.filter {
                        $0.player.nationTag == first.homeTag || $0.player.nationTag == first.awayTag
                    }.prefix(3)
                    for card in picks {
                        c.collection.acquire(cardID: card.id)
                        c.lineup.toggleField(card.id)
                    }
                }
                if c.lineup.count == 0 {
                    for card in seeded.prefix(3) { c.lineup.toggleField(card.id) }
                }
            }
            container = c
        }
    }
}
