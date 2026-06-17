import Foundation

/// Firestore catalog payload at `catalog/current`. Mirrors the bundled
/// catalog.json shape so the same Codable types apply. Banners + fixtures
/// stay bundled and are supplied by the loader.
struct CatalogDTO: Codable, Sendable {
    struct NationDTO: Codable, Sendable { let tag: String; let name: String }
    let nations: [NationDTO]
    let cards: [Card]

    func toData(banners: [Banner], fixtures: [Fixture]) -> CatalogData {
        CatalogData(cards: cards,
                    banners: banners,
                    fixtures: fixtures,
                    nations: nations.map { Nation(tag: $0.tag, name: $0.name) })
    }
}
