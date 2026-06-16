import Foundation

/// Server-authoritative wallet: Firestore is the durable truth, the wrapped
/// `SwiftDataWalletService` is the local synchronous cache the UI binds to.
/// Reads delegate to local; mutations write through to Firestore (offline-queued);
/// `hydrate()` reconciles on login (cloud overwrites local, or seeds if absent).
@MainActor
final class FirestoreWalletService: WalletService {
    private let local: SwiftDataWalletService
    private let client: FirestoreClient
    private let uid: String

    init(local: SwiftDataWalletService, client: FirestoreClient, uid: String) {
        self.local = local
        self.client = client
        self.uid = uid
    }

    // Reads — pure delegation to the local cache.
    var wallet: Wallet { local.wallet }
    func balance(_ currency: Currency) -> Int { local.balance(currency) }
    func pity(for bannerID: String) -> PityState { local.pity(for: bannerID) }

    // Mutations — local first (synchronous, UI updates), then write through.
    func credit(_ currency: Currency, _ amount: Int) {
        local.credit(currency, amount)
        pushWallet()
    }

    @discardableResult
    func debit(_ currency: Currency, _ amount: Int) -> Bool {
        let ok = local.debit(currency, amount)
        if ok { pushWallet() }
        return ok
    }

    func setPity(_ state: PityState, for bannerID: String) {
        local.setPity(state, for: bannerID)
        pushPity(bannerID, state)
    }

    func save() { local.save() }

    /// Login reconciliation. Firestore wins; if no cloud doc exists yet, seed it
    /// from the local starter wallet (server-side first-run seed).
    func hydrate() async {
        do {
            if let dto = try await client.fetchWallet(uid: uid) {
                dto.apply(to: local.wallet)
                local.save()
            } else {
                try await client.putWallet(uid: uid, WalletDTO(local.wallet))
            }
            for p in try await client.fetchAllPity(uid: uid) {
                local.setPity(p.state, for: p.bannerID)
            }
        } catch {
            print("Wallet hydrate failed: \(error as NSError)")
        }
    }

    // Fire-and-forget write-through; Firestore's offline queue handles retries.
    private func pushWallet() {
        let dto = WalletDTO(local.wallet)
        let client = client, uid = uid
        Task { do { try await client.putWallet(uid: uid, dto) } catch { print("putWallet failed: \(error)") } }
    }
    private func pushPity(_ bannerID: String, _ state: PityState) {
        let dto = PityDTO(bannerID: bannerID, state: state)
        let client = client, uid = uid
        Task { do { try await client.putPity(uid: uid, dto) } catch { print("putPity failed: \(error)") } }
    }
}
