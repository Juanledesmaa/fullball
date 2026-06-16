import Foundation

/// Ties the pure `GachaEngine` to the wallet, collection and pity
/// persistence. ViewModels depend on this protocol, never the engine.
@MainActor
protocol GachaService: AnyObject {
    func canAfford(_ cost: PullCost) -> Bool
    func pullCount(for bannerID: String) -> Int    // pulls since last Icon
    @discardableResult func pull(banner: Banner, multi: Bool) throws -> [PullResult]
}

enum GachaError: Error { case insufficientFunds }

@MainActor
final class DefaultGachaService: GachaService {
    private let catalog: any CatalogService
    private let wallet: any WalletService
    private let collection: any CollectionService
    private var rng: any RandomProvider

    init(catalog: any CatalogService,
         wallet: any WalletService,
         collection: any CollectionService,
         rng: any RandomProvider = SystemRandomProvider()) {
        self.catalog = catalog
        self.wallet = wallet
        self.collection = collection
        self.rng = rng
    }

    func canAfford(_ cost: PullCost) -> Bool {
        wallet.balance(cost.currency) >= cost.amount
    }

    func pullCount(for bannerID: String) -> Int {
        wallet.pity(for: bannerID).pullsSinceIcon
    }

    @discardableResult
    func pull(banner: Banner, multi: Bool) throws -> [PullResult] {
        let cost = multi ? banner.multiCost : banner.singleCost
        guard canAfford(cost) else { throw GachaError.insufficientFunds }
        wallet.debit(cost.currency, cost.amount)

        let rolls = multi ? 10 : 1
        var pity = wallet.pity(for: banner.id)
        var results: [PullResult] = []
        for _ in 0..<rolls {
            let outcome = GachaEngine.roll(banner: banner, pity: pity,
                                           pool: catalog.cards, provider: &rng)
            pity = outcome.pityAfter
            let isNew = collection.acquire(cardID: outcome.card.id)
            results.append(PullResult(card: outcome.card, isNew: isNew, pityAfter: pity))
        }
        wallet.setPity(pity, for: banner.id)
        return results
    }
}
