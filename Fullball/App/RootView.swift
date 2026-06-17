import SwiftUI
import SwiftData

/// Anonymous-first entry: signs in anonymously (zero friction) so the player
/// lands straight in the game with a stable uid for cloud save. Apple linking is
/// optional and offered later (Agencies + a one-time soft prompt). Rebuilds the
/// uid-scoped `AppContainer` whenever the account changes (link-to-existing).
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth: any AuthService = FirebaseAuthService()
    @State private var container: AppContainer?
    @State private var didBuild = false
    @State private var builtFor: String?
    @AppStorage("didSeeIntro") private var didSeeIntro = false

    var body: some View {
        Group {
            if let container {
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
        .task { await ensureSessionAndBuild() }
        .onChange(of: auth.currentUser?.uid) { _, newUID in
            // Account changed after initial build (e.g. linked to an existing
            // Apple account → different uid). Rebuild the uid-scoped container.
            guard didBuild, builtFor != newUID else { return }
            Task { await build(uid: newUID) }
        }
    }

    private func ensureSessionAndBuild() async {
        // Anonymous-first: if there's no session, create one. On failure (offline
        // first launch) we proceed with uid == nil → local-only services; a later
        // launch retries anon and upgrades to cloud.
        if auth.currentUser == nil {
            try? await auth.signInAnonymously()
        }
        await build(uid: auth.currentUser?.uid)
    }

    private func build(uid: String?) async {
        container = nil
        let loader: any CatalogLoading = uid == nil
            ? BundledCatalogLoader()
            : FirestoreCatalogLoader(client: FirestoreClient())
        let c = await AppContainer.bootstrap(context: modelContext,
                                             uid: uid,
                                             userName: auth.currentUser?.displayName,
                                             auth: auth,
                                             loader: loader)
        // Launch-arg demo seed for UI verification only (`-seedDemo 1`).
        if UserDefaults.standard.bool(forKey: "seedDemo"), c.collection.owned().isEmpty {
            let seeded = Array(c.catalog.cards.prefix(14))
            for card in seeded { c.collection.acquire(cardID: card.id) }
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
        builtFor = uid
        didBuild = true
    }
}
