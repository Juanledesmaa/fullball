import SwiftUI
import SwiftData

/// Composition root. Wires the (mock) services and hands them to views /
/// view models. Injected into the SwiftUI environment.
@MainActor
@Observable
final class AppContainer {
    let catalog: any CatalogService
    let wallet: any WalletService
    let collection: any CollectionService
    let gacha: any GachaService
    let live: any LiveMatchService
    let leaderboard: any LeaderboardService
    let score: ScoreBoard
    let rewards: any RewardsService
    let lineup: any LineupService
    let milestones: any MilestoneService
    let exchange: any ExchangeService
    let matchStore: any MatchProgressStore
    let slate: MatchSlateService
    let market: TransferMarketService
    let imageStore: any PlayerImageStore
    let auth: any AuthService
    let energy: any EnergyService
    let navigator = Navigator()

    init(context: ModelContext,
         catalog: any CatalogService = BundledCatalogService(),
         wallet injectedWallet: (any WalletService)? = nil,
         collection injectedCollection: (any CollectionService)? = nil,
         leaderboard injectedLeaderboard: (any LeaderboardService)? = nil,
         score injectedScore: ScoreBoard? = nil,
         imageStore: (any PlayerImageStore)? = nil,
         auth: (any AuthService)? = nil,
         rng: any RandomProvider = SystemRandomProvider()) {
        self.catalog = catalog
        self.imageStore = imageStore ?? MockImageStore()
        self.auth = auth ?? MockAuthService()
        let wallet = injectedWallet ?? SwiftDataWalletService(context: context)
        self.wallet = wallet
        let collection = injectedCollection
            ?? SwiftDataCollectionService(context: context, catalog: catalog, wallet: wallet)
        self.collection = collection
        self.gacha = DefaultGachaService(catalog: catalog, wallet: wallet,
                                         collection: collection, rng: rng)
        // Procedurally-generated slate (device + time-block seeded), refreshable for Gems.
        self.slate = MatchSlateService(context: context, catalog: catalog, wallet: wallet)
        self.live = MockLiveMatchService()
        self.matchStore = SwiftDataMatchStore(context: context)
        self.leaderboard = injectedLeaderboard ?? MockLeaderboardService()
        self.score = injectedScore ?? ScoreBoard(context: context)
        self.rewards = DefaultRewardsService(context: context, wallet: wallet)
        self.lineup = SwiftDataLineupService(context: context, validIDs: Set(catalog.cards.map(\.id)))
        self.milestones = DefaultMilestoneService(context: context, wallet: wallet)
        self.exchange = DefaultExchangeService(wallet: wallet)
        self.market = TransferMarketService(catalog: catalog, wallet: wallet, collection: collection)
        self.energy = DefaultEnergyService(context: context, wallet: wallet, collection: collection)
    }

    /// The SwiftData model types the app persists.
    static let schema = Schema([Wallet.self, CardInstance.self, BannerPity.self,
                                LiveProgress.self, Lineup.self, MatchRecord.self])

    /// Async composition: resolve the catalog, then — when signed in — build the
    /// Firestore-backed wallet/collection decorators and hydrate them from the
    /// cloud before returning. Signed-out (previews/tests) uses local services.
    static func bootstrap(context: ModelContext,
                          uid: String? = nil,
                          userName: String? = nil,
                          auth: (any AuthService)? = nil,
                          loader: any CatalogLoading = BundledCatalogLoader()) async -> AppContainer {
        let data: CatalogData
        if let loaded = try? await loader.load() {
            data = loaded
        } else {
            data = (try? await BundledCatalogLoader().load())
                ?? CatalogData(cards: [], banners: [], fixtures: [], nations: [])
        }
        let catalog = ResolvedCatalogService(data)

        guard let uid else {
            return AppContainer(context: context, catalog: catalog, auth: auth)
        }

        let client = FirestoreClient()
        let localWallet = SwiftDataWalletService(context: context)
        let cloudWallet = FirestoreWalletService(local: localWallet, client: client, uid: uid)
        // The local collection takes the DECORATOR wallet so training / limit-break
        // coin spends (which call wallet.debit internally) also write through.
        let localCollection = SwiftDataCollectionService(context: context, catalog: catalog, wallet: cloudWallet)
        let cloudCollection = FirestoreCollectionService(local: localCollection, context: context, client: client, uid: uid)
        await cloudWallet.hydrate()
        await cloudCollection.hydrate()

        let displayName = (userName?.isEmpty == false ? userName! : "Agent \(uid.prefix(4))")
        let leaderboard = FirestoreLeaderboardService(uid: uid, currentUserName: displayName, client: client)

        let score = ScoreBoard(context: context, client: client, uid: uid)
        await score.hydrate()

        return AppContainer(context: context, catalog: catalog,
                            wallet: cloudWallet, collection: cloudCollection,
                            leaderboard: leaderboard, score: score,
                            imageStore: FirebaseImageStore(), auth: auth)
    }
}

/// Optional runtime config. The api-football key is read from the app's
/// Info.plist (`APIFootballKey`) — absent by default, so the app stays
/// fully offline unless you supply one. Never commit a real key.
enum FullballConfig {
    static var apiFootballKey: String? {
        (Bundle.main.object(forInfoDictionaryKey: "APIFootballKey") as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    static var catalogLoader: any CatalogLoading {
        if let key = apiFootballKey {
            return APIFootballCatalogLoader(client: APIFootballClient(apiKey: key))
        }
        return BundledCatalogLoader()
    }
}
