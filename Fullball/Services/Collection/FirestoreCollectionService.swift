import Foundation
import SwiftData

/// Server-authoritative collection: Firestore is the durable truth, the wrapped
/// `SwiftDataCollectionService` is the local cache. Reads delegate; mutations
/// write through the affected `CardInstance`; `hydrate()` reconciles on login.
@MainActor
final class FirestoreCollectionService: CollectionService {
    private let local: SwiftDataCollectionService
    private let context: ModelContext
    private let client: FirestoreClient
    private let uid: String

    init(local: SwiftDataCollectionService, context: ModelContext,
         client: FirestoreClient, uid: String) {
        self.local = local
        self.context = context
        self.client = client
        self.uid = uid
    }

    // Reads.
    func owned() -> [OwnedCard] { local.owned() }
    func instance(forCardID id: String) -> CardInstance? { local.instance(forCardID: id) }

    // Mutations — local first, then push the affected card.
    @discardableResult
    func acquire(cardID: String) -> Bool {
        let isNew = local.acquire(cardID: cardID)
        push(cardID: cardID)
        return isNew
    }

    @discardableResult
    func train(_ instance: CardInstance) -> Bool {
        let ok = local.train(instance)
        if ok { push(cardID: instance.cardID) }
        return ok
    }

    @discardableResult
    func limitBreak(_ instance: CardInstance) -> Bool {
        let ok = local.limitBreak(instance)
        if ok { push(cardID: instance.cardID) }
        return ok
    }

    /// Login reconciliation. If the cloud has any cards, they are authoritative:
    /// clear the local cache and rebuild from cloud. If the cloud is empty, seed
    /// it from whatever is local (first-run).
    func hydrate() async {
        do {
            let cloud = try await client.fetchCollection(uid: uid)
            if cloud.isEmpty {
                for owned in local.owned() {
                    try await client.putCardInstance(uid: uid, CardInstanceDTO(owned.instance))
                }
            } else {
                // Cloud wins: wipe local instances, reinsert from cloud.
                let existing = (try? context.fetch(FetchDescriptor<CardInstance>())) ?? []
                for inst in existing { context.delete(inst) }
                for dto in cloud { context.insert(dto.makeInstance()) }
                do {
                    try context.save()
                } catch {
                    // A failed reconcile self-heals on the next hydrate (cloud is
                    // authoritative). Log rather than proceed as if it succeeded.
                    print("Collection hydrate save failed: \(error as NSError)")
                }
            }
        } catch {
            print("Collection hydrate failed: \(error as NSError)")
        }
    }

    private func push(cardID: String) {
        guard let inst = local.instance(forCardID: cardID) else { return }
        let dto = CardInstanceDTO(inst)
        let client = client, uid = uid
        Task { do { try await client.putCardInstance(uid: uid, dto) } catch { print("putCardInstance failed: \(error)") } }
    }
}
