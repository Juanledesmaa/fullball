import Foundation

/// Pure, deterministic 5-a-side match resolver. Alternates possessions between
/// the two sides, rolling chance-creation then shot outcomes from effective
/// stats modulated by the tactical layers. Injected RNG ⇒ reproducible.
enum FutsalEngine {

    static func play(home: MatchSide, away: MatchSide, seed: UInt64) -> MatchResult {
        var rng = SeededRandomProvider(seed: seed)
        guard !home.outfield.isEmpty, !away.outfield.isEmpty else {
            return MatchResult(homeGoals: 0, awayGoals: 0, events: [],
                               homeContributions: [], awayContributions: [])
        }
        var events: [PossessionEvent] = []
        var homeGoals = 0, awayGoals = 0
        var tally: [String: PlayerContribution] = [:]

        func bump(_ id: String, _ change: (inout PlayerContribution) -> Void) {
            var c = tally[id] ?? PlayerContribution(playerID: id)
            change(&c)
            tally[id] = c
        }

        for i in 0..<FutsalRules.possessionCount {
            let attackingHome = (i % 2 == 0)
            let atk = attackingHome ? home : away
            let def = attackingHome ? away : home

            let carrier = weightedPick(atk.outfield, weight: { Double($0.stats.passing) }, &rng)
                ?? atk.outfield.first!

            let pCreate = chanceProbability(atk: atk, def: def)
            if rng.nextUnit() >= pCreate {
                events.append(PossessionEvent(index: i, attackingHome: attackingHome,
                                              ballPlayerID: carrier.id, outcome: .turnover,
                                              assistID: nil))
                continue
            }

            // Your best finisher takes the chance. Picking the max (not a
            // shooting-weighted lottery) keeps adding players strictly additive:
            // bench depth never steals a shot from your star and lowers finish
            // quality — it only creates more chances and tightens defense.
            let shooter = atk.outfield.max { $0.stats.shooting < $1.stats.shooting } ?? carrier
            let assist = shooter.id == carrier.id ? nil : carrier.id

            let pGoal = goalProbability(shooter: shooter, atk: atk, def: def)
            let roll = rng.nextUnit()
            let outcome: PossessionEvent.Outcome
            if roll < pGoal {
                outcome = .goal
                if attackingHome { homeGoals += 1 } else { awayGoals += 1 }
                bump(shooter.id) { $0.goals += 1 }
                if let assist { bump(assist) { $0.assists += 1 } }
            } else if roll < pGoal + (1 - pGoal) * FutsalRules.saveBand {
                outcome = .save
                if let gk = def.goalkeeper { bump(gk.id) { $0.saves += 1 } }
            } else {
                outcome = .miss
            }
            events.append(PossessionEvent(index: i, attackingHome: attackingHome,
                                          ballPlayerID: shooter.id, outcome: outcome,
                                          assistID: assist))
        }

        for (id, _) in tally {
            bump(id) { $0.points = $0.goals * 100 + $0.assists * 40 + $0.saves * 20 }
        }
        let homeIDs = Set(home.players.map(\.id))
        let homeC = tally.values.filter { homeIDs.contains($0.playerID) }.sorted { $0.playerID < $1.playerID }
        let awayC = tally.values.filter { !homeIDs.contains($0.playerID) }.sorted { $0.playerID < $1.playerID }

        return MatchResult(homeGoals: homeGoals, awayGoals: awayGoals, events: events,
                           homeContributions: homeC, awayContributions: awayC)
    }

    // MARK: probability model

    static func chanceProbability(atk: MatchSide, def: MatchSide) -> Double {
        let atkMid = midfieldStrength(atk), defMid = midfieldStrength(def)
        let focus = atk.tactics.focus.rawValue + def.tactics.focus.rawValue
        let intensity = atk.tactics.intensity.rawValue + def.tactics.intensity.rawValue
        let p = FutsalRules.baseChance
            + FutsalRules.strengthWeight * (atkMid - defMid)
            + FutsalRules.focusWeight * Double(focus)
            + FutsalRules.intensityWeight * Double(intensity)
        return min(FutsalRules.chanceCeil, max(FutsalRules.chanceFloor, p))
    }

    static func goalProbability(shooter: MatchPlayer, atk: MatchSide, def: MatchSide) -> Double {
        let gkDef = def.goalkeeper?.stats.defending ?? 50
        let gkStyle = def.goalkeeper?.style ?? .physical
        let styleEdge = shooter.style.edge(against: gkStyle)
        let p = FutsalRules.baseGoal
            + FutsalRules.shotWeight * (Double(shooter.stats.shooting) - Double(gkDef))
            + FutsalRules.styleEdgeWeight * Double(styleEdge)
        return min(FutsalRules.goalCeil, max(FutsalRules.goalFloor, p))
    }

    /// Combined midfield strength. Normalized against a FULL outfield
    /// (`FutsalRules.fullOutfieldCount`), not the actual headcount — so empty
    /// slots count as zero and fielding more players is always additive. A team
    /// short of a full five is genuinely weaker (an undermanned side is at a
    /// real disadvantage); a full side matches the old per-player average.
    static func midfieldStrength(_ side: MatchSide) -> Double {
        let sum = side.outfield.reduce(0.0) { $0 + Double($1.stats.passing + $1.stats.pace) / 2.0 }
        return sum / Double(FutsalRules.fullOutfieldCount)
    }

    private static func weightedPick<R: RandomProvider>(
        _ items: [MatchPlayer], weight: (MatchPlayer) -> Double, _ rng: inout R
    ) -> MatchPlayer? {
        guard !items.isEmpty else { return nil }
        let weights = items.map { max(0.0001, weight($0)) }
        let total = weights.reduce(0, +)
        var r = rng.nextUnit() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items.last
    }
}
