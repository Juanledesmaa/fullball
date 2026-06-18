import Testing
@testable import Fullball

struct FutsalEngineTests {
    static func mp(_ id: String, _ pos: Position, _ s: Stats) -> MatchPlayer {
        MatchPlayer(id: id, position: pos, stats: s)
    }
    static func side(prefix: String, base: Int, tactics: Tactics = Tactics(),
                     style: PlayStyle = .technical) -> MatchSide {
        let s = Stats(pace: base, shooting: base, passing: base, defending: base)
        let players = [
            mp("\(prefix)gk", .gk, s), mp("\(prefix)d", .def, s),
            mp("\(prefix)m", .mid, s), mp("\(prefix)f1", .fwd, s),
            mp("\(prefix)f2", .fwd, s),
        ]
        return MatchSide(players: players, tactics: tactics, teamStyle: style,
                         dangerManID: "\(prefix)f1", captainID: "\(prefix)f1")
    }

    @Test func sameSeedIsDeterministic() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r1 = FutsalEngine.play(home: h, away: a, seed: 42)
        let r2 = FutsalEngine.play(home: h, away: a, seed: 42)
        #expect(r1 == r2)
    }

    @Test func differentSeedCanDiffer() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r1 = FutsalEngine.play(home: h, away: a, seed: 1)
        let r2 = FutsalEngine.play(home: h, away: a, seed: 2)
        #expect(r1 != r2)
    }

    @Test func eventsAreOrderedAndReferenceRealPlayers() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r = FutsalEngine.play(home: h, away: a, seed: 7)
        #expect(r.events.count == FutsalRules.possessionCount)
        #expect(r.events.map(\.index) == Array(0..<FutsalRules.possessionCount))
        let ids = Set(h.players.map(\.id) + a.players.map(\.id))
        for e in r.events { #expect(ids.contains(e.ballPlayerID)) }
    }

    @Test func goalsEqualCountedGoalEvents() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r = FutsalEngine.play(home: h, away: a, seed: 11)
        let homeGoals = r.events.filter { $0.attackingHome && $0.outcome == .goal }.count
        let awayGoals = r.events.filter { !$0.attackingHome && $0.outcome == .goal }.count
        #expect(r.homeGoals == homeGoals)
        #expect(r.awayGoals == awayGoals)
    }

    @Test func strongerTeamOutscoresOverManySeeds() {
        let strong = Self.side(prefix: "h", base: 90)
        let weak   = Self.side(prefix: "a", base: 40)
        var strongGoals = 0, weakGoals = 0
        for seed in UInt64(0)..<60 {
            let r = FutsalEngine.play(home: strong, away: weak, seed: seed)
            strongGoals += r.homeGoals; weakGoals += r.awayGoals
        }
        #expect(strongGoals > weakGoals)
    }

    @Test func poorShootersConvertLessThanGoodShooters() {
        func teamShooting(_ shoot: Int, prefix: String) -> MatchSide {
            let s = Stats(pace: 60, shooting: shoot, passing: 60, defending: 60)
            let players = [
                Self.mp("\(prefix)gk", .gk, s), Self.mp("\(prefix)d", .def, s),
                Self.mp("\(prefix)m", .mid, s), Self.mp("\(prefix)f1", .fwd, s),
                Self.mp("\(prefix)f2", .fwd, s),
            ]
            return MatchSide(players: players, tactics: Tactics(), teamStyle: .technical,
                             dangerManID: "\(prefix)f1", captainID: nil)
        }
        let opponent = Self.side(prefix: "a", base: 60)
        var goodGoals = 0, badGoals = 0
        for seed in UInt64(0)..<60 {
            goodGoals += FutsalEngine.play(home: teamShooting(90, prefix: "g"), away: opponent, seed: seed).homeGoals
            badGoals  += FutsalEngine.play(home: teamShooting(20, prefix: "b"), away: opponent, seed: seed).homeGoals
        }
        #expect(goodGoals > badGoals)
    }
}
