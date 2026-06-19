import Testing
@testable import Fullball

struct FutsalOddsTests {
    static func side(prefix: String, base: Int, tactics: Tactics = Tactics()) -> MatchSide {
        let s = Stats(pace: base, shooting: base, passing: base, defending: base)
        let players = [
            MatchPlayer(id: "\(prefix)gk", position: .gk, stats: s),
            MatchPlayer(id: "\(prefix)d", position: .def, stats: s),
            MatchPlayer(id: "\(prefix)m", position: .mid, stats: s),
            MatchPlayer(id: "\(prefix)f1", position: .fwd, stats: s),
            MatchPlayer(id: "\(prefix)f2", position: .fwd, stats: s),
        ]
        return MatchSide(players: players, tactics: tactics, captainID: "\(prefix)f1")
    }

    static let empty = MatchSide(players: [], tactics: Tactics(), captainID: nil)

    @Test func deterministicForSameInputs() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let p1 = FutsalOdds.winProbability(home: h, away: a, samples: 200, seed: 42)
        let p2 = FutsalOdds.winProbability(home: h, away: a, samples: 200, seed: 42)
        #expect(p1 == p2)
    }

    @Test func emptyHomeIsZero() {
        let a = Self.side(prefix: "a", base: 60)
        let p = FutsalOdds.winProbability(home: Self.empty, away: a, samples: 200, seed: 1)
        #expect(p == 0.0)
    }

    @Test func evenlyMatchedSidesAreAboutHalf() {
        // Identical sides: draws fold to half, so the bar reads ~50% (not the
        // punishingly-low pure win-fraction a draw-heavy sim would give).
        let h = Self.side(prefix: "h", base: 65), a = Self.side(prefix: "a", base: 65)
        let p = FutsalOdds.winProbability(home: h, away: a, samples: 600, seed: 2)
        #expect(p > 0.40 && p < 0.60)
    }

    @Test func strongHomeBeatsWeakAway() {
        let strong = Self.side(prefix: "h", base: 90)
        let weak   = Self.side(prefix: "a", base: 40)
        let p = FutsalOdds.winProbability(home: strong, away: weak, samples: 200, seed: 3)
        #expect(p > 0.5)
    }

    @Test func probabilityStaysInRange() {
        let h = Self.side(prefix: "h", base: 70), a = Self.side(prefix: "a", base: 55)
        let p = FutsalOdds.winProbability(home: h, away: a, samples: 200, seed: 9)
        #expect(p >= 0.0 && p <= 1.0)
    }

    /// Filling out the team must never reduce win odds — even adding a weak
    /// player is additive (regression for the "icon-only beat icon+bronzes" bug).
    @Test func addingWeakPlayersNeverLowersOdds() {
        let away = Self.side(prefix: "a", base: 70)
        func homeWith(_ outfieldBases: [Int]) -> MatchSide {
            var players = [MatchPlayer(id: "hgk", position: .gk,
                                       stats: Stats(pace: 80, shooting: 80, passing: 80, defending: 80))]
            let outPos: [Position] = [.def, .mid, .mid, .fwd]
            for (i, b) in outfieldBases.enumerated() {
                players.append(MatchPlayer(id: "ho\(i)", position: outPos[i],
                                           stats: Stats(pace: b, shooting: b, passing: b, defending: b)))
            }
            return MatchSide(players: players, tactics: Tactics(), captainID: "ho0")
        }
        let oneStar  = FutsalOdds.winProbability(home: homeWith([90]),          away: away, samples: 300, seed: 4)
        let plusWeak = FutsalOdds.winProbability(home: homeWith([90, 40]),      away: away, samples: 300, seed: 4)
        let full     = FutsalOdds.winProbability(home: homeWith([90, 40, 40, 40]), away: away, samples: 300, seed: 4)
        #expect(plusWeak >= oneStar)
        #expect(full >= plusWeak)
    }

    /// Midfield strength is normalized to a full outfield, so each added
    /// outfielder strictly increases it (never the diluting average).
    @Test func midfieldStrengthIsAdditive() {
        func side(_ n: Int) -> MatchSide {
            let s = Stats(pace: 60, shooting: 60, passing: 60, defending: 60)
            var players = [MatchPlayer(id: "gk", position: .gk, stats: s)]
            for i in 0..<n { players.append(MatchPlayer(id: "o\(i)", position: .mid, stats: s)) }
            return MatchSide(players: players, tactics: Tactics(), captainID: nil)
        }
        #expect(FutsalEngine.midfieldStrength(side(1)) < FutsalEngine.midfieldStrength(side(2)))
        #expect(FutsalEngine.midfieldStrength(side(2)) < FutsalEngine.midfieldStrength(side(4)))
        // A full outfield reduces to the per-player average (60).
        #expect(FutsalEngine.midfieldStrength(side(4)) == 60.0)
    }
}
