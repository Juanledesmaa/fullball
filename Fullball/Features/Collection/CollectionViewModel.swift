import SwiftUI

@MainActor
@Observable
final class CollectionViewModel {
    private let collection: any CollectionService
    private let catalog: any CatalogService
    var items: [OwnedCard] = []
    var rarityFilter: Rarity?
    var positionFilter: Position?

    init(container: AppContainer) {
        self.collection = container.collection
        self.catalog = container.catalog
    }

    func reload() { items = collection.owned() }

    var catalogTotal: Int { catalog.cards.count }
    var completion: Double { catalogTotal > 0 ? Double(items.count) / Double(catalogTotal) : 0 }

    /// Squad rating = average effective overall of the best 11 owned cards.
    var squadRating: Int {
        let tops = items.map(\.effectiveStats.overall).sorted(by: >).prefix(11)
        guard !tops.isEmpty else { return 0 }
        return Int((Double(tops.reduce(0, +)) / Double(tops.count)).rounded())
    }

    var filtered: [OwnedCard] {
        items.filter { owned in
            (rarityFilter == nil || owned.card.rarity == rarityFilter)
            && (positionFilter == nil || owned.card.player.position == positionFilter)
        }
    }

    var totalCount: Int { items.count }

    func toggleRarity(_ r: Rarity) { rarityFilter = (rarityFilter == r) ? nil : r }
    func togglePosition(_ p: Position) { positionFilter = (positionFilter == p) ? nil : p }
}
