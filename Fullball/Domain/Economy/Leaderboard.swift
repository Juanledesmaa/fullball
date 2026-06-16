import Foundation

/// Pure leaderboard ranking. Sorts by points descending, breaking ties by
/// user name ascending, then assigns 1-based ranks.
enum Leaderboard {
    static func ranked(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        let sorted = entries.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.userName < $1.userName
        }
        return sorted.enumerated().map { idx, entry in
            var e = entry
            e.rank = idx + 1
            return e
        }
    }
}
