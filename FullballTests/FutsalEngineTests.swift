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

    @Test func correctCounterBeatsWrongCounter() {
        let opp = Self.side(prefix: "a", base: 60, style: .physical)
        let right = Self.side(prefix: "h", base: 60, tactics: Tactics(counter: .pace))
        let wrong = Self.side(prefix: "h", base: 60, tactics: Tactics(counter: .physical))
        var rightGoals = 0, wrongGoals = 0
        for seed in UInt64(0)..<60 {
            rightGoals += FutsalEngine.play(home: right, away: opp, seed: seed).homeGoals
            wrongGoals += FutsalEngine.play(home: wrong, away: opp, seed: seed).homeGoals
        }
        #expect(rightGoals > wrongGoals)
    }

    @Test func markingTheDangerManReducesTheirGoals() {
        let home = Self.side(prefix: "h", base: 70)
        func awayMarking(_ marks: Bool) -> MatchSide {
            let strongMarker = Self.mp("ad", .def, Stats(pace: 60, shooting: 20, passing: 50, defending: 95))
            let s = Stats(pace: 60, shooting: 60, passing: 60, defending: 60)
            let players = [
                Self.mp("agk", .gk, s), strongMarker,
                Self.mp("am", .mid, s), Self.mp("af1", .fwd, s), Self.mp("af2", .fwd, s),
            ]
            let t = Tactics(markerID: marks ? "ad" : nil)
            return MatchSide(players: players, tactics: t, teamStyle: .technical,
                             dangerManID: "af1", captainID: nil)
        }
        var markedGoals = 0, freeGoals = 0
        for seed in UInt64(0)..<60 {
            markedGoals += FutsalEngine.play(home: home, away: awayMarking(true),  seed: seed).homeGoals
            freeGoals   += FutsalEngine.play(home: home, away: awayMarking(false), seed: seed).homeGoals
        }
        #expect(markedGoals < freeGoals)
    }

    @Test func attackingMentalityProducesMoreGoalsThanParkingTheBus() {
        func bothSides(_ m: Mentality) -> (MatchSide, MatchSide) {
            (Self.side(prefix: "h", base: 60, tactics: Tactics(mentality: m)),
             Self.side(prefix: "a", base: 60, tactics: Tactics(mentality: m)))
        }
        var openGoals = 0, closedGoals = 0
        for seed in UInt64(0)..<60 {
            let (ho, ao) = bothSides(.allOut)
            let openR = FutsalEngine.play(home: ho, away: ao, seed: seed)
            openGoals += openR.homeGoals + openR.awayGoals
            let (hc, ac) = bothSides(.parkBus)
            let closedR = FutsalEngine.play(home: hc, away: ac, seed: seed)
            closedGoals += closedR.homeGoals + closedR.awayGoals
        }
        #expect(openGoals > closedGoals)
    }

    @Test func favorableFormationOutscoresUnfavorable() {
        // Favorable: home defensive vs away attacking → home shape edge +1.
        // Unfavorable: home attacking vs away defensive → home shape edge -1.
        let awayAtk = Self.side(prefix: "a", base: 60, tactics: Tactics(formation: .attacking))
        let awayDef = Self.side(prefix: "a", base: 60, tactics: Tactics(formation: .defensive))
        let homeFav = Self.side(prefix: "h", base: 60, tactics: Tactics(formation: .defensive))
        let homeUnfav = Self.side(prefix: "h", base: 60, tactics: Tactics(formation: .attacking))
        var favGoals = 0, unfavGoals = 0
        for seed in UInt64(0)..<60 {
            favGoals   += FutsalEngine.play(home: homeFav,   away: awayAtk, seed: seed).homeGoals
            unfavGoals += FutsalEngine.play(home: homeUnfav, away: awayDef, seed: seed).homeGoals
        }
        #expect(favGoals > unfavGoals)
    }
}
