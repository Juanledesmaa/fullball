import Foundation

/// Builds a deterministic opponent `MatchSide` for a fixture. Prefers the away
/// nation's players; backfills from the global catalog so a thin nation still
/// fields a full 5. Pure + seedable (mirrors `FixtureGenerator`).
enum OpponentGenerator {

    static func opponent(awayTag: String, cards: [Card], seed: UInt64) -> MatchSide {
        var rng = SeededRandomProvider(seed: seed)
        let nationPool = FixtureGenerator.shuffle(cards.filter { $0.player.nationTag == awayTag }, &rng)
        let restPool   = FixtureGenerator.shuffle(cards.filter { $0.player.nationTag != awayTag }, &rng)
        let ordered = nationPool + restPool

        let gkCard = ordered.first { $0.player.position == .gk } ?? ordered.first
        var chosen: [Card] = []
        if let gkCard { chosen.append(gkCard) }
        for c in ordered where c.id != gkCard?.id {
            if chosen.count >= 5 { break }
            chosen.append(c)
        }
        let players: [MatchPlayer] = chosen.map {
            MatchPlayer(id: $0.id, position: $0.player.position, stats: $0.player.stats)
        }
        guard !players.isEmpty else {
            return MatchSide(players: [], tactics: Tactics(), teamStyle: .technical,
                             dangerManID: "", captainID: nil)
        }
        let formations = Formation.allCases
        let mentalities = Mentality.allCases
        let tactics = Tactics(
            formation: formations[rng.nextInt(formations.count)],
            mentality: mentalities[rng.nextInt(mentalities.count)])

        let outfield = players.filter { $0.position != .gk }
        let dangerMan = outfield.max { $0.stats.shooting < $1.stats.shooting } ?? players.first!
        let teamStyle = dominantStyle(outfield.isEmpty ? players : outfield)
        return MatchSide(players: players, tactics: tactics, teamStyle: teamStyle,
                         dangerManID: dangerMan.id, captainID: dangerMan.id)
    }

    /// Most common derived style (ties → technical > physical > pace).
    static func dominantStyle(_ players: [MatchPlayer]) -> PlayStyle {
        var counts: [PlayStyle: Int] = [:]
        for p in players { counts[p.style, default: 0] += 1 }
        let order: [PlayStyle] = [.technical, .physical, .pace]
        return order.max { (counts[$0] ?? 0, -order.firstIndex(of: $0)!) < (counts[$1] ?? 0, -order.firstIndex(of: $1)!) } ?? .technical
    }
}
