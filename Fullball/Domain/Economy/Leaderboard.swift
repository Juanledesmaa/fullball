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

    /// Merge entries that may share a `userName`, keeping the current-user entry
    /// on any collision (else the higher-points entry), then rank. Used to fold
    /// the rival floor + real entries + the live current-user entry into one board.
    static func dedupedRanked(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        var byName: [String: LeaderboardEntry] = [:]
        for entry in entries {
            if let existing = byName[entry.userName] {
                if entry.isCurrentUser {
                    byName[entry.userName] = entry
                } else if !existing.isCurrentUser, entry.points > existing.points {
                    byName[entry.userName] = entry
                }
            } else {
                byName[entry.userName] = entry
            }
        }
        return ranked(Array(byName.values))
    }
}
