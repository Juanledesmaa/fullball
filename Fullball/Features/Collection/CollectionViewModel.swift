import SwiftUI

enum RosterSort: String, CaseIterable {
    case quality = "Quality"
    case name    = "Name"
}

@MainActor
@Observable
final class CollectionViewModel {
    private let collection: any CollectionService
    private let catalog: any CatalogService
    private let energyService: any EnergyService
    var items: [OwnedCard] = []
    var rarityFilter: Rarity?
    var positionFilter: Position?
    var sort: RosterSort = .quality

    init(container: AppContainer) {
        self.collection = container.collection
        self.catalog = container.catalog
        self.energyService = container.energy
    }

    func reload() { items = collection.owned() }

    /// Current energy for a card, used to drive the roster energy bar.
    func energy(_ id: String) -> Int {
        guard let inst = collection.instance(forCardID: id) else { return EnergyRules.maxEnergy }
        return energyService.current(inst)
    }

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

    /// Filtered items with the current sort applied.
    var sortedItems: [OwnedCard] {
        switch sort {
        case .quality:
            return filtered.sorted { $0.effectiveStats.overall > $1.effectiveStats.overall }
        case .name:
            return filtered.sorted {
                $0.card.displayName.localizedCaseInsensitiveCompare($1.card.displayName) == .orderedAscending
            }
        }
    }

    var totalCount: Int { items.count }

    func toggleRarity(_ r: Rarity) { rarityFilter = (rarityFilter == r) ? nil : r }
    func togglePosition(_ p: Position) { positionFilter = (positionFilter == p) ? nil : p }
}
