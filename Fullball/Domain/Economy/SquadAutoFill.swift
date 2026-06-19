import Foundation

/// Picks the strongest available squad for a set of positional slots. Pure +
/// deterministic so it's unit-testable and reusable from the ViewModel.
///
/// Two greedy passes over candidates sorted by rating (desc):
///   1. fill each slot with the best *natural-position* candidate (no
///      off-position penalty wasted on a player who fits elsewhere);
///   2. fill any slot still empty with the best remaining candidate of any
///      position (accepting the off-position penalty in play).
/// Each candidate is used at most once.
enum SquadAutoFill {
    struct Candidate { let id: String; let position: Position; let rating: Int }

    /// Returns one `cardID?` per slot (same order/length as `slots`).
    static func pick(slots: [Position], from candidates: [Candidate]) -> [String?] {
        var pool = candidates.sorted { $0.rating > $1.rating }
        var result = [String?](repeating: nil, count: slots.count)

        func take(where match: (Candidate) -> Bool) -> String? {
            guard let idx = pool.firstIndex(where: match) else { return nil }
            return pool.remove(at: idx).id
        }

        // Pass 1: exact position match.
        for (i, slot) in slots.enumerated() {
            result[i] = take { $0.position == slot }
        }
        // Pass 2: backfill empties with the best remaining of any position.
        for i in slots.indices where result[i] == nil {
            result[i] = take { _ in true }
        }
        return result
    }
}
