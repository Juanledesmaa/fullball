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
        let tactics = Tactics(
            intensity: Intensity.allCases[rng.nextInt(Intensity.allCases.count)],
            focus: Focus.allCases[rng.nextInt(Focus.allCases.count)])
        guard !players.isEmpty else {
            return MatchSide(players: [], tactics: tactics, captainID: nil)
        }
        let captain = players.filter { $0.position != .gk }.max { $0.stats.shooting < $1.stats.shooting } ?? players.first
        return MatchSide(players: players, tactics: tactics, captainID: captain?.id)
    }
}
