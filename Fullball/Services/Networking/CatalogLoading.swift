import Foundation

/// A resolved catalog snapshot (cards/nations come from a source; banners
/// and fixtures are supplied alongside).
struct CatalogData: Sendable {
    let cards: [Card]
    let banners: [Banner]
    let fixtures: [Fixture]
    let nations: [Nation]
}

/// Async seam for *where* the catalog comes from. The app builds a
/// synchronous `CatalogService` from the result, so swapping bundled →
/// remote never touches ViewModels.
protocol CatalogLoading: Sendable {
    func load() async throws -> CatalogData
}

/// Wraps any `CatalogData` as the synchronous `CatalogService` the app uses.
struct ResolvedCatalogService: CatalogService {
    let cards: [Card]
    let banners: [Banner]
    let fixtures: [Fixture]
    let nations: [Nation]
    init(_ data: CatalogData) {
        cards = data.cards; banners = data.banners
        fixtures = data.fixtures; nations = data.nations
    }
}

/// Loads the catalog from the bundled JSON (default, offline).
struct BundledCatalogLoader: CatalogLoading {
    func load() async throws -> CatalogData {
        let s = BundledCatalogService()
        return CatalogData(cards: s.cards, banners: s.banners, fixtures: s.fixtures, nations: s.nations)
    }
}
