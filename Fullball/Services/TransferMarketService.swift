import Foundation

/// A marquee client available to sign outright (deterministic, vs scouting).
struct TransferListing: Identifiable {
    let card: Card
    let price: Int
    var id: String { card.id }
}

/// The transfer market: a rotating board of specific clients you can sign
/// with Cash. Deterministic per device + day (like the match slate), so the
/// shortlist is stable then refreshes.
@MainActor
@Observable
final class TransferMarketService {
    private let catalog: any CatalogService
    private let wallet: any WalletService
    private let collection: any CollectionService

    private(set) var listings: [TransferListing]

    init(catalog: any CatalogService, wallet: any WalletService, collection: any CollectionService) {
        self.catalog = catalog
        self.wallet = wallet
        self.collection = collection
        self.listings = Self.generate(catalog: catalog)
    }

    func canAfford(_ listing: TransferListing) -> Bool {
        wallet.balance(.coins) >= listing.price
    }

    func owned(_ listing: TransferListing) -> Bool {
        collection.instance(forCardID: listing.id) != nil
    }

    /// Sign a client: debit Cash, add to the roster, pull the listing.
    @discardableResult
    func sign(_ listing: TransferListing) -> Bool {
        guard wallet.balance(.coins) >= listing.price else { return false }
        guard wallet.debit(.coins, listing.price) else { return false }
        collection.acquire(cardID: listing.id)
        listings.removeAll { $0.id == listing.id }
        return true
    }

    private static func generate(catalog: any CatalogService) -> [TransferListing] {
        var rng = SeededRandomProvider(seed: DeviceSeed.seed(for: "market-" + DeviceSeed.slateID()))
        let byRarity = Dictionary(grouping: catalog.cards, by: { $0.rarity })
        // Marquee shortlist: a couple of each high tier, deterministic.
        let plan: [(Rarity, Int)] = [(.icon, 2), (.epic, 2), (.gold, 2), (.silver, 1)]
        var listings: [TransferListing] = []
        for (rarity, n) in plan {
            let pool = FixtureGenerator.shuffle(byRarity[rarity] ?? [], &rng)
            for card in pool.prefix(n) {
                let price = TransferRules.price(rarity: rarity, overall: card.player.stats.overall)
                listings.append(TransferListing(card: card, price: price))
            }
        }
        return listings
    }
}
