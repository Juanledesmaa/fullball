import Foundation

/// Assembles your `MatchSide` from already-resolved effective stats + tactics.
enum MatchSideAssembly {
    static func build(players: [(id: String, position: Position, stats: Stats)],
                      tactics: Tactics, captainID: String?) -> MatchSide {
        let mps = players.map { MatchPlayer(id: $0.id, position: $0.position, stats: $0.stats) }
        let outfield = mps.filter { $0.position != .gk }
        let dangerMan = outfield.max { $0.stats.shooting < $1.stats.shooting } ?? mps.first
        let style = OpponentGenerator.dominantStyle(outfield.isEmpty ? mps : outfield)
        return MatchSide(players: mps, tactics: tactics, teamStyle: style,
                         dangerManID: dangerMan?.id ?? "", captainID: captainID)
    }
}

/// Maps a side's match contributions to currency rewards. Captain points double.
enum FutsalReward {
    struct Payout: Equatable { var points = 0; var cash = 0; var rep = 0; var wonBonus = false }

    static func from(contributions: [PlayerContribution], captainID: String?) -> Payout {
        var points = 0, rep = 0
        for c in contributions {
            let mult = (c.playerID == captainID) ? LineupRules.captainMultiplier : 1
            points += c.points * mult
            rep += c.goals * 2 + c.assists + c.saves
        }
        return Payout(points: points, cash: AgentRules.commission(forPoints: points),
                      rep: rep, wonBonus: points >= LiveRules.winBonusTarget)
    }
}
