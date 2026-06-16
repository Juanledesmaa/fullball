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
}
