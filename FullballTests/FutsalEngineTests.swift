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
}
