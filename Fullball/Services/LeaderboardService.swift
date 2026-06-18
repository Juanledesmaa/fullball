import Foundation

/// Ranked agency standings. `@MainActor` because the Firestore-backed impl
/// holds an observable cache the UI reads on the main actor.
@MainActor
protocol LeaderboardService {
    var currentUserName: String { get }
    /// Synchronous board for the given live user points (reads cached entries).
    func standings(userPoints: Int) -> [LeaderboardEntry]
    /// Publish the user's entry and re-fetch the top players. No-op in the mock.
    func refresh(userPoints: Int) async
    /// Persist a new agency name locally and to Firestore.
    func updateName(_ name: String, userPoints: Int) async
}

/// Fixed local board for previews/offline. No cloud.
@MainActor
final class MockLeaderboardService: LeaderboardService {
    private(set) var currentUserName: String

    init(currentUserName: String = "You") { self.currentUserName = currentUserName }

    private let rivals: [(String, Int)] = LeaderboardRivals.floor

    func standings(userPoints: Int) -> [LeaderboardEntry] {
        var entries = rivals.map { LeaderboardEntry(userName: $0.0, points: $0.1) }
        entries.append(LeaderboardEntry(userName: currentUserName,
                                        points: userPoints, isCurrentUser: true))
        return Leaderboard.dedupedRanked(entries)
    }

    func refresh(userPoints: Int) async {}

    func updateName(_ name: String, userPoints: Int) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            currentUserName = trimmed
            UserDefaults.standard.set(trimmed, forKey: "agencyName")
        }
    }
}

/// Shared, real leaderboard. Publishes the user's entry to `leaderboard/{uid}`
/// and caches the top real entries; merges them with a cosmetic rival floor and
/// the live current-user entry for display. The cache is `@Observable` so the
/// board updates when a refresh lands.
@MainActor
@Observable
final class FirestoreLeaderboardService: LeaderboardService {
    private(set) var currentUserName: String
    private let uid: String
    private let client: FirestoreClient
    private let topLimit: Int
    private var others: [LeaderboardEntry] = []   // cached real entries (excludes self)

    init(uid: String, currentUserName: String, client: FirestoreClient, topLimit: Int = 50) {
        self.uid = uid
        self.currentUserName = currentUserName
        self.client = client
        self.topLimit = topLimit
    }

    func standings(userPoints: Int) -> [LeaderboardEntry] {
        var entries = LeaderboardRivals.floor.map { LeaderboardEntry(userName: $0.0, points: $0.1) }
        entries += others
        entries.append(LeaderboardEntry(userName: currentUserName,
                                        points: userPoints, isCurrentUser: true))
        return Leaderboard.dedupedRanked(entries)
    }

    func refresh(userPoints: Int) async {
        do {
            try await client.putLeaderboardEntry(uid: uid, name: currentUserName, points: userPoints)
            let top = try await client.fetchTopLeaderboard(limit: topLimit)
            others = top
                .filter { $0.uid != uid }
                .map { LeaderboardEntry(userName: $0.name, points: $0.points) }
        } catch {
            print("Leaderboard refresh failed: \(error as NSError)")
        }
    }

    func updateName(_ name: String, userPoints: Int) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentUserName = trimmed
        UserDefaults.standard.set(trimmed, forKey: "agencyName")
        do {
            try await client.putLeaderboardEntry(uid: uid, name: trimmed, points: userPoints)
            await refresh(userPoints: userPoints)
        } catch {
            print("updateName failed: \(error as NSError)")
        }
    }
}

/// Cosmetic rival floor so the board looks alive before the real player base
/// grows. Purely client-side; real players come from Firestore.
enum LeaderboardRivals {
    static let floor: [(String, Int)] = [
        ("ElTri_99", 4820), ("OranjeBoss", 4310), ("SambaKing", 3960),
        ("LaAlbiceleste", 3540), ("ThreeLions", 2980), ("DieMannschaft", 2610),
        ("CR_Selecao", 2270), ("FuriaRoja", 1890), ("AzzurriClub", 1450),
        ("StarsAndStripes", 1120), ("SamuraiBlue", 760),
    ]
}
