import Foundation

/// One ranked user on the leaderboard. `rank` is assigned at sort time.
struct LeaderboardEntry: Codable, Sendable, Identifiable, Hashable {
    let userName: String
    var points: Int
    var rank: Int
    var isCurrentUser: Bool

    init(userName: String, points: Int, rank: Int = 0, isCurrentUser: Bool = false) {
        self.userName = userName
        self.points = points
        self.rank = rank
        self.isCurrentUser = isCurrentUser
    }

    var id: String { userName }
}
