import Foundation

/// Resolves the catalog from Firestore (`catalog/current`); falls back to the
/// bundled JSON on miss/offline/error. Banners + fixtures stay bundled. This is
/// the live-ops seam: edit the Firestore doc to retune players without a release.
@MainActor
struct FirestoreCatalogLoader: CatalogLoading {
    let client: FirestoreClient

    func load() async throws -> CatalogData {
        let bundled = try await BundledCatalogLoader().load()
        do {
            guard let dto = try await client.fetchCatalog() else { return bundled }
            return dto.toData(banners: bundled.banners, fixtures: bundled.fixtures)
        } catch {
            return bundled   // offline / permission / decode → bundled identity
        }
    }
}
