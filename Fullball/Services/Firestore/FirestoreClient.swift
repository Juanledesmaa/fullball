import Foundation
import FirebaseFirestore

/// Thin wrapper over Firestore. The single place the rest of the app reaches
/// the database; later phases add typed read/write helpers here. Offline
/// persistence is on by default in the Firebase SDK, set explicitly for clarity.
@MainActor
final class FirestoreClient {
    let db: Firestore

    init() {
        let store = Firestore.firestore()
        let settings = store.settings
        settings.cacheSettings = PersistentCacheSettings()   // offline persistence
        store.settings = settings
        self.db = store
    }

    /// Per-user document root: `users/{uid}`.
    func userDoc(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: Document refs

    private func walletDoc(_ uid: String) -> DocumentReference {
        userDoc(uid).collection("state").document("wallet")
    }
    private func collectionRef(_ uid: String) -> CollectionReference {
        userDoc(uid).collection("collection")
    }
    private func pityRef(_ uid: String) -> CollectionReference {
        userDoc(uid).collection("pity")
    }

    // MARK: Wallet

    func fetchWallet(uid: String) async throws -> WalletDTO? {
        let snap = try await walletDoc(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: WalletDTO.self)
    }
    func putWallet(uid: String, _ dto: WalletDTO) async throws {
        try walletDoc(uid).setData(from: dto)
    }

    // MARK: Collection

    func fetchCollection(uid: String) async throws -> [CardInstanceDTO] {
        let snap = try await collectionRef(uid).getDocuments()
        return try snap.documents.map { try $0.data(as: CardInstanceDTO.self) }
    }
    func putCardInstance(uid: String, _ dto: CardInstanceDTO) async throws {
        try collectionRef(uid).document(dto.cardID).setData(from: dto)
    }

    // MARK: Pity

    func fetchAllPity(uid: String) async throws -> [PityDTO] {
        let snap = try await pityRef(uid).getDocuments()
        return try snap.documents.map { try $0.data(as: PityDTO.self) }
    }
    func putPity(uid: String, _ dto: PityDTO) async throws {
        try pityRef(uid).document(dto.bannerID).setData(from: dto)
    }

    // MARK: Leaderboard

    private func leaderboardRef() -> CollectionReference {
        db.collection("leaderboard")
    }

    func putLeaderboardEntry(uid: String, name: String, points: Int) async throws {
        try leaderboardRef().document(uid)
            .setData(from: LeaderboardEntryDTO(name: name, points: points))
    }

    /// Top entries by points descending. Returns each doc's id (the player uid)
    /// alongside the decoded name/points.
    func fetchTopLeaderboard(limit: Int) async throws -> [(uid: String, name: String, points: Int)] {
        let snap = try await leaderboardRef()
            .order(by: "points", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snap.documents.map { doc in
            let dto = try doc.data(as: LeaderboardEntryDTO.self)
            return (uid: doc.documentID, name: dto.name, points: dto.points)
        }
    }

    // MARK: Progress

    private func progressDoc(_ uid: String) -> DocumentReference {
        userDoc(uid).collection("state").document("progress")
    }

    func fetchProgress(uid: String) async throws -> ProgressDTO? {
        let snap = try await progressDoc(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: ProgressDTO.self)
    }
    func putProgress(uid: String, _ dto: ProgressDTO) async throws {
        try progressDoc(uid).setData(from: dto)
    }
}
