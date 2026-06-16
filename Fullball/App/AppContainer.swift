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
    let navigator = Navigator()

    init(context: ModelContext,
         catalog: any CatalogService = BundledCatalogService(),
         rng: any RandomProvider = SystemRandomProvider()) {
        self.catalog = catalog
        let wallet = SwiftDataWalletService(context: context)
        self.wallet = wallet
        let collection = SwiftDataCollectionService(context: context, catalog: catalog, wallet: wallet)
        self.collection = collection
        self.gacha = DefaultGachaService(catalog: catalog, wallet: wallet,
                                         collection: collection, rng: rng)
        // Procedurally-generated slate (device + time-block seeded), refreshable for Gems.
        self.slate = MatchSlateService(context: context, catalog: catalog, wallet: wallet)
        self.live = MockLiveMatchService()
        self.matchStore = SwiftDataMatchStore(context: context)
        self.leaderboard = MockLeaderboardService()
        self.score = ScoreBoard(context: context)
        self.rewards = DefaultRewardsService(context: context, wallet: wallet)
        self.lineup = SwiftDataLineupService(context: context)
        self.milestones = DefaultMilestoneService(context: context, wallet: wallet)
        self.exchange = DefaultExchangeService(wallet: wallet)
        self.market = TransferMarketService(catalog: catalog, wallet: wallet, collection: collection)
    }

    /// The SwiftData model types the app persists.
    static let schema = Schema([Wallet.self, CardInstance.self, BannerPity.self,
                                LiveProgress.self, Lineup.self, MatchRecord.self])

    /// Async composition: resolve the catalog via the given loader (remote
    /// or bundled), then wire the container. Falls back to bundled JSON if
    /// the loader fails — the app always boots offline.
    static func bootstrap(context: ModelContext,
                          loader: any CatalogLoading = BundledCatalogLoader()) async -> AppContainer {
        let data: CatalogData
        if let loaded = try? await loader.load() {
            data = loaded
        } else {
            data = (try? await BundledCatalogLoader().load())
                ?? CatalogData(cards: [], banners: [], fixtures: [], nations: [])
        }
        return AppContainer(context: context, catalog: ResolvedCatalogService(data))
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
