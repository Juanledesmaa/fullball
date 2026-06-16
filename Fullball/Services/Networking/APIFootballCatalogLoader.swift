import Foundation

/// Thin api-football v3 client. Fetches *structure only* (teams, player
/// positions/ratings) for a given league + season. The API key is injected
/// — never hardcoded or committed.
struct APIFootballClient: Sendable {
    let apiKey: String
    let host = "https://v3.football.api-sports.io"
    var session: URLSession = .shared

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: host + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(apiKey, forHTTPHeaderField: "x-apisports-key")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    // MARK: DTOs (only the fields we use — names are intentionally ignored)

    private struct TeamsResponse: Decodable { let response: [TeamWrap] }
    private struct TeamWrap: Decodable { let team: Team }
    private struct Team: Decodable { let name: String; let code: String? }

    private struct PlayersResponse: Decodable {
        let response: [PlayerWrap]
        let paging: Paging
    }
    private struct Paging: Decodable { let current: Int; let total: Int }
    private struct PlayerWrap: Decodable { let statistics: [Stat] }
    private struct Stat: Decodable {
        let team: TeamRef
        let games: Games
        struct TeamRef: Decodable { let name: String }
        struct Games: Decodable { let position: String?; let rating: String? }
    }

    func nations(league: Int, season: Int) async throws -> [Nation] {
        let data = try await get("/teams?league=\(league)&season=\(season)")
        let decoded = try JSONDecoder().decode(TeamsResponse.self, from: data)
        return decoded.response.map { wrap in
            let code = wrap.team.code ?? String(wrap.team.name.prefix(3)).uppercased()
            return Nation(tag: code, name: wrap.team.name)
        }
    }

    /// One page of player signals (structure only). api-football paginates;
    /// callers can loop `paging.total`.
    func playerSignals(league: Int, season: Int, page: Int,
                       teamCode: [String: String]) async throws -> (signals: [PlayerSignal], pages: Int) {
        let data = try await get("/players?league=\(league)&season=\(season)&page=\(page)")
        let decoded = try JSONDecoder().decode(PlayersResponse.self, from: data)
        let signals: [PlayerSignal] = decoded.response.compactMap { wrap in
            guard let st = wrap.statistics.first else { return nil }
            let tag = teamCode[st.team.name] ?? String(st.team.name.prefix(3)).uppercased()
            let pos = Self.position(st.games.position)
            let rating = st.games.rating.flatMap(Double.init)
            return PlayerSignal(nationTag: tag, position: pos, rating: rating)
        }
        return (signals, decoded.paging.total)
    }

    static func position(_ api: String?) -> Position {
        switch api {
        case "Goalkeeper": return .gk
        case "Defender": return .def
        case "Midfielder": return .mid
        case "Attacker": return .fwd
        default: return .mid
        }
    }
}

/// Loads cards from api-football (fictionalized), reusing bundled banners +
/// fixtures and guaranteeing any referenced card IDs exist.
struct APIFootballCatalogLoader: CatalogLoading {
    let client: APIFootballClient
    var league = 1          // World Cup
    var season = 2022       // free-tier season
    var maxPages = 2        // keep within free-tier request budget

    func load() async throws -> CatalogData {
        let nations = try await client.nations(league: league, season: season)
        let codeByName = Dictionary(nations.map { ($0.name, $0.tag) }, uniquingKeysWith: { a, _ in a })

        var signals: [PlayerSignal] = []
        var page = 1, pages = 1
        repeat {
            let result = try await client.playerSignals(league: league, season: season,
                                                        page: page, teamCode: codeByName)
            signals.append(contentsOf: result.signals)
            pages = result.pages
            page += 1
        } while page <= min(pages, maxPages)

        var cards = Fictionalizer.cards(from: signals)

        // Reuse bundled banners + fixtures; ensure referenced IDs resolve.
        let bundled = BundledCatalogService()
        let referenced = Set(bundled.banners.flatMap(\.featuredCardIDs)
            + bundled.fixtures.flatMap { $0.scriptedEvents.map(\.playerID) })
        let present = Set(cards.map(\.id))
        for id in referenced where !present.contains(id) {
            // Synthesize a fictional Icon so featured/fixture refs always work.
            let tag = String(id.split(separator: "-").first ?? "WLD")
            let num = Int(id.split(separator: "-").last ?? "0") ?? 0
            let player = Player(id: id, displayName: "\(tag) #\(num)", nationTag: tag,
                                shirtNumber: num, position: .fwd,
                                stats: Fictionalizer.stats(rarity: .icon, position: .fwd, seed: num))
            cards.append(Card(id: id, player: player, rarity: .icon, artRef: Position.fwd.symbol))
        }

        return CatalogData(cards: cards, banners: bundled.banners,
                           fixtures: bundled.fixtures,
                           nations: nations.isEmpty ? bundled.nations : nations)
    }
}
