import SwiftUI

@MainActor
@Observable
final class LeaderboardViewModel {
    private let service: any LeaderboardService
    private let score: ScoreBoard

    init(container: AppContainer) {
        self.service = container.leaderboard
        self.score = container.score
    }

    var entries: [LeaderboardEntry] { service.standings(userPoints: score.points) }

    var currentUserRank: Int? {
        entries.first { $0.isCurrentUser }?.rank
    }
}
