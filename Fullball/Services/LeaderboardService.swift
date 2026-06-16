import Foundation

/// Ranked user standings. Local mock for the MVP.
protocol LeaderboardService: Sendable {
    var currentUserName: String { get }
    func standings(userPoints: Int) -> [LeaderboardEntry]
}

struct MockLeaderboardService: LeaderboardService {
    let currentUserName: String

    init(currentUserName: String = "You") { self.currentUserName = currentUserName }

    private let rivals: [(String, Int)] = [
        ("ElTri_99", 4820), ("OranjeBoss", 4310), ("SambaKing", 3960),
        ("LaAlbiceleste", 3540), ("ThreeLions", 2980), ("DieMannschaft", 2610),
        ("CR_Selecao", 2270), ("FuriaRoja", 1890), ("AzzurriClub", 1450),
        ("StarsAndStripes", 1120), ("SamuraiBlue", 760),
    ]

    func standings(userPoints: Int) -> [LeaderboardEntry] {
        var entries = rivals.map { LeaderboardEntry(userName: $0.0, points: $0.1) }
        entries.append(LeaderboardEntry(userName: currentUserName,
                                        points: userPoints, isCurrentUser: true))
        return Leaderboard.ranked(entries)
    }
}
