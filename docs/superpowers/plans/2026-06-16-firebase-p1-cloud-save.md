# Firebase P1 — Cloud Save (wallet + collection) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist the player's wallet (balances + per-banner pity) and collection (owned `CardInstance`s) to Firestore per authenticated user, so progress survives reinstall and syncs across devices — without changing any ViewModel, View, or service protocol.

**Architecture:** Firestore is the durable source of truth; SwiftData stays the local synchronous cache the UI binds to. New Firestore-backed **decorators** (`FirestoreWalletService`, `FirestoreCollectionService`) wrap the existing `SwiftDataWalletService`/`SwiftDataCollectionService`: reads delegate to the local cache; every mutation writes through to Firestore asynchronously (fire-and-forget `Task`, offline-queued by the Firestore SDK); on login the decorator **hydrates** from Firestore (cloud overwrites local; seeds a starter doc if none exists). The `WalletService`/`CollectionService` protocols stay synchronous and unchanged, so nothing downstream is touched. The composition root (`AppContainer.bootstrap`) threads the authenticated `uid` and constructs the decorators only when signed in; previews/offline use the local services directly.

**Tech Stack:** Swift 6 strict concurrency, FirebaseFirestore 11.15 (built-in Codable: `setData(from:)` / `data(as:)`), SwiftData, XcodeGen.

**Why decorators / write-through (not an async protocol):** The spec's core principle is "no ViewModel/View changes." The existing services are synchronous (`debit(_:_:) -> Bool` is called inline in gacha/market/train flows). Making the protocols `async` would ripple into every call site and ViewModel. Write-through keeps the sync surface intact; Firestore's offline persistence + the next-login hydrate make it durable and server-authoritative-on-read. True transactional anti-forgery is scoped to **P5** (gacha pulls); P1 cloud-save only needs durability + owner-scoped rules.

**Testing note (project rule):** Per CLAUDE.md, only deterministic logic is unit-tested. The pure, testable seam here is the **DTO ↔ model mapping** (Task 1, TDD). The Firestore decorators and wiring are integration/wiring code — build-verified, not unit-tested (matches "no view/navigation/wiring tests"). Existing 45 tests must stay green.

---

## Firestore document layout (P1 subset)

```
users/{uid}/state/wallet            ← single doc: {coins, gems, tickets, formTokens}
users/{uid}/collection/{cardID}     ← one doc per owned card: {cardID, level, stars, xp, copies, dateAcquired}
users/{uid}/pity/{bannerID}         ← one doc per banner: {bannerID, pullsSinceIcon, guaranteeFeatured}
```

(`progress`, `lineup`, `matches`, `leaderboard`, `config/*` arrive in later phases.)

## File structure (P1)

- Create: `Fullball/Services/Firestore/CloudDTOs.swift` — `WalletDTO`, `CardInstanceDTO`, `PityDTO` (Codable) + pure mapping to/from models.
- Test: `FullballTests/CloudDTOTests.swift` — DTO ↔ model round-trips.
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift` — typed read/write helpers for wallet/collection/pity.
- Create: `Fullball/Services/Wallet/FirestoreWalletService.swift` — decorator (hydrate + write-through).
- Create: `Fullball/Services/Collection/FirestoreCollectionService.swift` — decorator (hydrate + write-through).
- Modify: `Fullball/App/AppContainer.swift` — `init` accepts injected wallet/collection; `bootstrap` threads `uid`, builds decorators, hydrates.
- Modify: `Fullball/App/RootView.swift` — pass `auth.currentUser?.uid` into `bootstrap`.
- Create: `firestore.rules` — owner-scoped security rules (repo reference; deployed manually).

---

## Task 1: Cloud DTOs + pure mapping (TDD)

The only unit-tested code in P1. DTOs are `Codable` value types that map cleanly to/from the `@Model` types. Mapping is pure (no Firestore), so it's testable with an in-memory SwiftData container (mirrors `LineupServiceTests`).

**Files:**
- Create: `Fullball/Services/Firestore/CloudDTOs.swift`
- Test: `FullballTests/CloudDTOTests.swift`

- [ ] **Step 1: Write the failing test** — create `FullballTests/CloudDTOTests.swift`:

```swift
import Testing
import SwiftData
@testable import Fullball

@MainActor
struct CloudDTOTests {
    private let container = try! ModelContainer(
        for: Schema([Wallet.self, CardInstance.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    @Test func walletRoundTrips() {
        let w = Wallet(coins: 2500, gems: 1600, tickets: 10, formTokens: 5)
        let dto = WalletDTO(w)
        #expect(dto == WalletDTO(coins: 2500, gems: 1600, tickets: 10, formTokens: 5))
        let w2 = Wallet()
        dto.apply(to: w2)
        #expect(w2.coins == 2500 && w2.gems == 1600 && w2.tickets == 10 && w2.formTokens == 5)
    }

    @Test func cardInstanceRoundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let inst = CardInstance(cardID: "ARG-10", level: 4, stars: 2, xp: 30, copies: 3, dateAcquired: date)
        let dto = CardInstanceDTO(inst)
        #expect(dto.cardID == "ARG-10")
        #expect(dto.level == 4 && dto.stars == 2 && dto.xp == 30 && dto.copies == 3)
        #expect(dto.dateAcquired == date)
        let rebuilt = dto.makeInstance()
        #expect(rebuilt.cardID == "ARG-10" && rebuilt.level == 4 && rebuilt.stars == 2
                && rebuilt.xp == 30 && rebuilt.copies == 3 && rebuilt.dateAcquired == date)
    }

    @Test func pityRoundTrips() {
        let dto = PityDTO(bannerID: "featured", state: PityState(pullsSinceIcon: 7, guaranteeFeatured: true))
        #expect(dto.pullsSinceIcon == 7 && dto.guaranteeFeatured == true)
        #expect(dto.state == PityState(pullsSinceIcon: 7, guaranteeFeatured: true))
    }
}
```

- [ ] **Step 2: Run, confirm fail** —
```
xcodegen generate
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests/CloudDTOTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: FAIL (`cannot find 'WalletDTO'` etc.).

- [ ] **Step 3: Implement** — create `Fullball/Services/Firestore/CloudDTOs.swift`:

```swift
import Foundation

/// Codable mirrors of the persisted models, used as the Firestore wire format.
/// Pure value types (no Firestore/SwiftData imports beyond the model refs) so
/// the mapping is unit-testable. FirebaseFirestore encodes/decodes these via
/// its built-in Codable support (`setData(from:)` / `data(as:)`).

struct WalletDTO: Codable, Equatable {
    var coins: Int
    var gems: Int
    var tickets: Int
    var formTokens: Int

    init(coins: Int, gems: Int, tickets: Int, formTokens: Int) {
        self.coins = coins; self.gems = gems; self.tickets = tickets; self.formTokens = formTokens
    }

    @MainActor init(_ w: Wallet) {
        self.init(coins: w.coins, gems: w.gems, tickets: w.tickets, formTokens: w.formTokens)
    }

    @MainActor func apply(to w: Wallet) {
        w.coins = coins; w.gems = gems; w.tickets = tickets; w.formTokens = formTokens
    }
}

struct CardInstanceDTO: Codable, Equatable {
    var cardID: String
    var level: Int
    var stars: Int
    var xp: Int
    var copies: Int
    var dateAcquired: Date

    init(cardID: String, level: Int, stars: Int, xp: Int, copies: Int, dateAcquired: Date) {
        self.cardID = cardID; self.level = level; self.stars = stars
        self.xp = xp; self.copies = copies; self.dateAcquired = dateAcquired
    }

    @MainActor init(_ inst: CardInstance) {
        self.init(cardID: inst.cardID, level: inst.level, stars: inst.stars,
                  xp: inst.xp, copies: inst.copies, dateAcquired: inst.dateAcquired)
    }

    @MainActor func makeInstance() -> CardInstance {
        CardInstance(cardID: cardID, level: level, stars: stars,
                     xp: xp, copies: copies, dateAcquired: dateAcquired)
    }
}

struct PityDTO: Codable, Equatable {
    var bannerID: String
    var pullsSinceIcon: Int
    var guaranteeFeatured: Bool

    init(bannerID: String, pullsSinceIcon: Int, guaranteeFeatured: Bool) {
        self.bannerID = bannerID
        self.pullsSinceIcon = pullsSinceIcon
        self.guaranteeFeatured = guaranteeFeatured
    }

    init(bannerID: String, state: PityState) {
        self.init(bannerID: bannerID,
                  pullsSinceIcon: state.pullsSinceIcon,
                  guaranteeFeatured: state.guaranteeFeatured)
    }

    var state: PityState {
        PityState(pullsSinceIcon: pullsSinceIcon, guaranteeFeatured: guaranteeFeatured)
    }
}
```

- [ ] **Step 4: Run, confirm pass** — same test command. Expected: PASS (3 tests).

- [ ] **Step 5: Commit**
```
git add Fullball/Services/Firestore/CloudDTOs.swift FullballTests/CloudDTOTests.swift
git commit -m "P1: cloud DTOs + pure model mapping (+ tests)"
```

---

## Task 2: FirestoreClient typed helpers

Add wallet/collection/pity read+write helpers to the existing `FirestoreClient`. Uses Firestore's built-in Codable.

**Files:**
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift`

- [ ] **Step 1: Add helpers.** Append these methods inside the `FirestoreClient` class (after `userDoc`):

```swift
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
```

> `setData(from:)` is the throwing Codable overload from FirebaseFirestore 11. `data(as:)` decodes. Both are synchronous-throwing on a `DocumentReference`/`DocumentSnapshot`; `getDocument()`/`getDocuments()` are the async reads.

- [ ] **Step 2: Regenerate + build**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **`. If `setData(from:)` is ambiguous, fully-qualify with `try walletDoc(uid).setData(from: dto, merge: false)`; if `data(as:)` needs a decoder hint, it does not — it's built in.

- [ ] **Step 3: Commit**
```
git add Fullball/Services/Firestore/FirestoreClient.swift
git commit -m "P1: FirestoreClient typed wallet/collection/pity helpers"
```

---

## Task 3: FirestoreWalletService decorator

Wraps `SwiftDataWalletService`. Reads delegate to local; mutations write through; `hydrate()` loads from cloud (cloud wins; seed if absent).

**Files:**
- Create: `Fullball/Services/Wallet/FirestoreWalletService.swift`

- [ ] **Step 1: Implement** — create `Fullball/Services/Wallet/FirestoreWalletService.swift`:

```swift
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
```

> Binding `client`/`uid` to locals before the `Task` avoids capturing `self` and keeps the `@Sendable` closure clean (mirrors the project's AsyncStream gotcha). `FirestoreClient` is `@MainActor`, so the `Task` inherits the main actor.

- [ ] **Step 2: Regenerate + build** (same commands as Task 2 Step 2). Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
```
git add Fullball/Services/Wallet/FirestoreWalletService.swift
git commit -m "P1: FirestoreWalletService decorator (hydrate + write-through)"
```

---

## Task 4: FirestoreCollectionService decorator

Wraps `SwiftDataCollectionService`. Reads delegate; `acquire`/`train`/`limitBreak` mutate local then push the affected card; `hydrate()` loads from cloud (cloud wins; seed if absent).

**Files:**
- Create: `Fullball/Services/Collection/FirestoreCollectionService.swift`

- [ ] **Step 1: Implement** — create `Fullball/Services/Collection/FirestoreCollectionService.swift`:

```swift
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
                try? context.save()
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
```

> The decorator needs its own `ModelContext` reference (for the cloud-wins wipe/reinsert) because that bulk operation isn't exposed on `CollectionService`. It's the same `context` the local service uses.

- [ ] **Step 2: Regenerate + build**. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**
```
git add Fullball/Services/Collection/FirestoreCollectionService.swift
git commit -m "P1: FirestoreCollectionService decorator (hydrate + write-through)"
```

---

## Task 5: Thread uid through AppContainer.bootstrap + RootView

Construct the decorators only when signed in, hydrate before returning, and keep previews/offline on the local services. No other service changes — gacha/market/live already receive `any WalletService`/`any CollectionService` and now transparently get the decorated ones (so their wallet mutations sync too).

**Files:**
- Modify: `Fullball/App/AppContainer.swift`
- Modify: `Fullball/App/RootView.swift`

- [ ] **Step 1: Make `AppContainer.init` accept injected wallet/collection (backward-compatible defaults).** In `AppContainer.swift`, change the `init` signature and the wallet/collection construction. Replace the current `init(context:catalog:rng:)` head and the two lines that build `wallet`/`collection`:

Current:
```swift
    init(context: ModelContext,
         catalog: any CatalogService = BundledCatalogService(),
         rng: any RandomProvider = SystemRandomProvider()) {
        self.catalog = catalog
        let wallet = SwiftDataWalletService(context: context)
        self.wallet = wallet
        let collection = SwiftDataCollectionService(context: context, catalog: catalog, wallet: wallet)
        self.collection = collection
```

New:
```swift
    init(context: ModelContext,
         catalog: any CatalogService = BundledCatalogService(),
         wallet injectedWallet: (any WalletService)? = nil,
         collection injectedCollection: (any CollectionService)? = nil,
         rng: any RandomProvider = SystemRandomProvider()) {
        self.catalog = catalog
        let wallet = injectedWallet ?? SwiftDataWalletService(context: context)
        self.wallet = wallet
        let collection = injectedCollection
            ?? SwiftDataCollectionService(context: context, catalog: catalog, wallet: wallet)
        self.collection = collection
```

Everything after (`self.gacha = …`, `self.slate = …`, etc.) stays byte-identical — they read `wallet`/`collection` locals, which now may be the injected decorators.

- [ ] **Step 2: Update `bootstrap` to thread `uid` and hydrate.** Replace the existing `bootstrap` method with:

```swift
    /// Async composition: resolve the catalog, then — when signed in — build the
    /// Firestore-backed wallet/collection decorators and hydrate them from the
    /// cloud before returning. Signed-out (previews/tests) uses local services.
    static func bootstrap(context: ModelContext,
                          uid: String? = nil,
                          loader: any CatalogLoading = BundledCatalogLoader()) async -> AppContainer {
        let data: CatalogData
        if let loaded = try? await loader.load() {
            data = loaded
        } else {
            data = (try? await BundledCatalogLoader().load())
                ?? CatalogData(cards: [], banners: [], fixtures: [], nations: [])
        }
        let catalog = ResolvedCatalogService(data)

        guard let uid else {
            return AppContainer(context: context, catalog: catalog)
        }

        let client = FirestoreClient()
        let localWallet = SwiftDataWalletService(context: context)
        let cloudWallet = FirestoreWalletService(local: localWallet, client: client, uid: uid)
        // The local collection takes the DECORATOR wallet so that training /
        // limit-break coin spends (which call wallet.debit internally) also
        // write through to Firestore.
        let localCollection = SwiftDataCollectionService(context: context, catalog: catalog, wallet: cloudWallet)
        let cloudCollection = FirestoreCollectionService(local: localCollection, context: context, client: client, uid: uid)
        await cloudWallet.hydrate()
        await cloudCollection.hydrate()

        return AppContainer(context: context, catalog: catalog,
                            wallet: cloudWallet, collection: cloudCollection)
    }
```

> Construction order matters: `cloudWallet` wraps `localWallet`; `localCollection` is built against `cloudWallet` (not `localWallet`) so its internal `wallet.debit` calls go through the write-through decorator; `cloudCollection` wraps `localCollection`. Hydrate the wallet before the collection (collection hydrate doesn't depend on wallet, but wallet-first keeps the seed order intuitive).

- [ ] **Step 3: Pass `uid` from `RootView`.** In `Fullball/App/RootView.swift`, the `.task(id:)` calls `AppContainer.bootstrap(context:loader:)`. Add the uid:

Change:
```swift
            let c = await AppContainer.bootstrap(context: modelContext,
                                                 loader: FullballConfig.catalogLoader)
```
to:
```swift
            let c = await AppContainer.bootstrap(context: modelContext,
                                                 uid: auth.currentUser?.uid,
                                                 loader: FullballConfig.catalogLoader)
```
(The surrounding `guard auth.currentUser != nil, container == nil else { return }` already ensures a uid is present here.)

- [ ] **Step 4: Regenerate, build, and run the full suite**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **`, then `** TEST SUCCEEDED **`. Confirm the passing count with `grep -cE "✔ Test .* passed"` → **48** (45 prior + 3 CloudDTO).

- [ ] **Step 5: Confirm `AppContainer.preview()` still compiles** (it calls `AppContainer(context:catalog:)` with no wallet/collection — the new defaults cover it; the build in Step 4 already proves this).

- [ ] **Step 6: Commit**
```
git add Fullball/App/AppContainer.swift Fullball/App/RootView.swift
git commit -m "P1: thread uid into bootstrap; wire Firestore wallet/collection + hydrate"
```

---

## Task 6: Firestore security rules

Owner-scoped rules so each user can only touch their own subtree. (Wallet/gacha anti-forgery validation is deferred to P5.) The rules file lives in the repo as the source of truth; you deploy it from the Firebase console or CLI.

**Files:**
- Create: `firestore.rules`

- [ ] **Step 1: Create `firestore.rules`** at the repo root:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // A signed-in user may read/write only their own subtree.
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Shared, read-only config (catalog, slate seed) — written out-of-band.
    // Tightened/extended in later phases (P3 catalog, P4 slate).
    match /config/{document=**} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

- [ ] **Step 2: Commit**
```
git add firestore.rules
git commit -m "P1: owner-scoped Firestore security rules"
```

- [ ] **Step 3 (MANUAL — human):** Deploy the rules. Either:
  - Firebase console → Firestore Database → **Rules** → paste `firestore.rules` contents → **Publish**, or
  - `firebase deploy --only firestore:rules` (requires `firebase-tools` + `firebase init firestore` once).

  Until published, the default production rules deny all client access and **every hydrate/write-through will fail** (you'll see `putWallet failed: … permission-denied` in the console). This is the gate for P1 working end-to-end.

---

## Done criteria (P1)

- Build green; **48 unit tests pass**.
- After deploying the rules and signing in on a device: the wallet (Cash/Gems/Scouts/Rep) and collection persist to Firestore (`users/{uid}/state/wallet`, `users/{uid}/collection/*`). Verify in the Firebase console → Firestore Data viewer.
- Reinstall the app (or sign in on a second device) → progress restores from Firestore.
- Spend Cash / pull a card / train → the corresponding Firestore doc updates within a moment.
- No ViewModel/View/service-protocol changes (Firebase stays behind `WalletService`/`CollectionService`/`FirestoreClient`).

## Known limitations (acceptable for P1; revisited later)

- **Write-through is per-mutation fire-and-forget** (a 10-pull = up to 10 card writes). Firestore batches/queues internally; debouncing can come later if write volume matters.
- **Last-write-wins across devices** (no merge/conflict resolution). Single-active-device assumption holds for now; the spec's server-authoritative model means the last hydrate is authoritative.
- **No transactional anti-forgery yet** — a tampered client could write an inflated wallet (rules only check ownership, not validity). Closed for gacha specifically in **P5**; full wallet validation is a later hardening pass if needed.
- **Pity hydrate is additive** (applies cloud pity onto local); fine because pity is small and owner-scoped.

## Out of scope (later phases)

- Progress singleton (`LiveProgress`), lineup, match records → **P4**.
- Real leaderboard → **P2**. Remote catalog → **P3**. Server gacha transaction → **P5**.
- Auth invasiveness rework (deferred sign-in) → separate follow-up after the backend phases.
