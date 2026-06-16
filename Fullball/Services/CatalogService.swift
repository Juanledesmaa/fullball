import Foundation

/// Read-only static catalog: cards, banners, fixtures, nations.
/// Protocol-first so a remote catalog can drop in later.
protocol CatalogService: Sendable {
    var cards: [Card] { get }
    var banners: [Banner] { get }
    var fixtures: [Fixture] { get }
    var nations: [Nation] { get }
}

extension CatalogService {
    func card(id: String) -> Card? { cards.first { $0.id == id } }
    func nationName(_ tag: String) -> String { nations.first { $0.tag == tag }?.name ?? tag }
    func banner(id: String) -> Banner? { banners.first { $0.id == id } }
    var standardBanner: Banner? { banners.first { $0.type == .standard } }
    var featuredBanner: Banner? { banners.first { $0.type == .featured } }
}

/// Loads the catalog from bundled JSON.
struct BundledCatalogService: CatalogService {
    let cards: [Card]
    let banners: [Banner]
    let fixtures: [Fixture]
    let nations: [Nation]

    private struct CatalogFile: Decodable { let nations: [Nation]; let cards: [Card] }

    init(bundle: Bundle = .main) {
        let dec = JSONDecoder()
        func load<T: Decodable>(_ name: String, as: T.Type) -> T {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let value = try? dec.decode(T.self, from: data) else {
                fatalError("Missing or invalid bundled resource: \(name).json")
            }
            return value
        }
        let catalog = load("catalog", as: CatalogFile.self)
        self.cards = catalog.cards
        self.nations = catalog.nations
        self.banners = load("banners", as: [Banner].self)
        self.fixtures = load("fixtures", as: [Fixture].self)
    }
}
