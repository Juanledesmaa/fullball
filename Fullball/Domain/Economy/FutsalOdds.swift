import Foundation

/// Estimates a side's win probability by Monte-Carlo simulation. The actual
/// match is deterministic (one fixed seed); this runs the same pure engine over
/// many *varied* seeds to estimate odds for the configured lineup + tactics
/// WITHOUT revealing the single predetermined result. Pure + deterministic:
/// identical inputs → identical probability (no flicker between renders).
enum FutsalOdds {

    /// Win-chance for `home`, in `0...1`. Futsal over 14 possessions is
    /// draw-heavy, so a pure win-fraction reads punishingly low even for a
    /// favored side; we fold draws as **half a win** (an even contest ≈ 0.5,
    /// the way a 1X2 favourite is judged) so the bar tracks real favouritism.
    /// An empty home side (degenerate UI state) is special-cased to `0.0`.
    static func winProbability(home: MatchSide, away: MatchSide,
                               samples: Int, seed: UInt64) -> Double {
        guard samples > 0, !home.outfield.isEmpty else { return 0.0 }
        var score = 0.0
        for i in 0..<samples {
            let r = FutsalEngine.play(home: home, away: away, seed: seed &+ UInt64(i))
            if r.homeGoals > r.awayGoals { score += 1 }
            else if r.homeGoals == r.awayGoals { score += 0.5 }
        }
        return score / Double(samples)
    }
}
