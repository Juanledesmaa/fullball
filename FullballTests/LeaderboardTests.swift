import Testing
@testable import Fullball

struct LeaderboardTests {
    @Test func ranksByPointsThenName() {
        let entries = [
            LeaderboardEntry(userName: "Zed", points: 100),
            LeaderboardEntry(userName: "Ana", points: 100),   // tie → name asc
            LeaderboardEntry(userName: "Max", points: 250),
        ]
        let ranked = Leaderboard.ranked(entries)
        #expect(ranked[0].userName == "Max" && ranked[0].rank == 1)
        #expect(ranked[1].userName == "Ana" && ranked[1].rank == 2)
        #expect(ranked[2].userName == "Zed" && ranked[2].rank == 3)
    }

    @Test func dedupeKeepsCurrentUserOnNameCollision() {
        let entries = [
            LeaderboardEntry(userName: "Rival", points: 100),
            LeaderboardEntry(userName: "You", points: 50),
            LeaderboardEntry(userName: "You", points: 999, isCurrentUser: true),
        ]
        let ranked = Leaderboard.dedupedRanked(entries)
        let yous = ranked.filter { $0.userName == "You" }
        #expect(yous.count == 1)
        #expect(yous.first?.isCurrentUser == true)
        #expect(yous.first?.points == 999)
        #expect(yous.first?.rank == 1)
    }

    @Test func dedupeKeepsHigherPointsForNonUserCollision() {
        let entries = [
            LeaderboardEntry(userName: "Rival", points: 100),
            LeaderboardEntry(userName: "Rival", points: 300),
        ]
        let ranked = Leaderboard.dedupedRanked(entries)
        #expect(ranked.count == 1)
        #expect(ranked.first?.points == 300)
    }

    @Test func dedupedRankedAssignsContiguousRanks() {
        let entries = [
            LeaderboardEntry(userName: "A", points: 10),
            LeaderboardEntry(userName: "B", points: 30),
            LeaderboardEntry(userName: "C", points: 20),
        ]
        let ranked = Leaderboard.dedupedRanked(entries)
        #expect(ranked.map(\.userName) == ["B", "C", "A"])
        #expect(ranked.map(\.rank) == [1, 2, 3])
    }
}
