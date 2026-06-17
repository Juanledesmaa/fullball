# Firebase P2 — Real Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed-mock leaderboard with a real, shared Firestore-backed ranking: each signed-in player publishes their agency (name + points) to `leaderboard/{uid}`, and the board shows the top players (real entries + a cosmetic rival floor) ranked, with the current user highlighted — reusing the existing `LeaderboardView`.

**Architecture:** Same cache-and-refresh shape as P1. `FirestoreLeaderboardService` keeps a locally-cached snapshot of other players' entries (observable) and answers `standings(userPoints:)` synchronously by merging: a baked cosmetic **rival floor** + the cached real entries + the live current-user entry, deduped and ranked by the existing pure `Leaderboard` engine. An async `refresh(userPoints:)` publishes the user's own entry to Firestore and re-fetches the top-N. The `LeaderboardService` protocol gains `@MainActor` isolation and a `refresh(userPoints:) async` method (the only protocol change — a real leaderboard fundamentally needs an async read of *other* users, which the synchronous surface can't express). `MockLeaderboardService` keeps working (no-op refresh) for previews.

**Tech Stack:** Swift 6 strict concurrency, FirebaseFirestore 11.15 (`order(by:descending:).limit(to:)` query + Codable), SwiftData (unaffected), XcodeGen.

**Why a rival floor (cosmetic, in-app):** With one real user the board would be a list of one. Real entries come from `leaderboard/{uid}` (shared, secure — owner-writable, all-readable). A baked rival floor (the 11 names from the old mock) is merged client-side so the board looks alive before the player base grows; it is cosmetic (other clients don't see your floor) and clearly documented. As real users accumulate they naturally populate the board; the floor can be removed later. This avoids client-written bot docs (which owner-scoped rules correctly forbid) and avoids a manual bot-seeding step.

**Testing note:** Per CLAUDE.md, only deterministic logic is tested. The pure seam here is leaderboard **merge+dedupe+rank** (Task 1, TDD, extends the existing `Leaderboard` engine + `LeaderboardTests`). The service/wiring is build-verified.

---

## Firestore layout (P2 addition)

```
leaderboard/{uid}   ← {name: String, points: Int}   (one doc per real player; uid = doc id)
```

## File structure (P2)

- Modify: `Fullball/Domain/Economy/Leaderboard.swift` — add pure `dedupedRanked(_:)`.
- Test: `FullballTests/LeaderboardTests.swift` — add dedupe/merge cases.
- Modify: `Fullball/Services/Firestore/CloudDTOs.swift` — add `LeaderboardEntryDTO`.
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift` — `putLeaderboardEntry` + `fetchTopLeaderboard`.
- Modify: `Fullball/Services/LeaderboardService.swift` — `@MainActor` protocol + `refresh`; `MockLeaderboardService` conforms; add `FirestoreLeaderboardService`.
- Modify: `Fullball/App/AppContainer.swift` — `init` accepts injected `leaderboard`; `bootstrap` threads `userName`, builds the real service when signed in.
- Modify: `Fullball/App/RootView.swift` — pass `userName: auth.currentUser?.displayName`.
- Modify: `Fullball/Features/Leaderboard/LeaderboardViewModel.swift` — add `refresh()`.
- Modify: `Fullball/Features/Leaderboard/LeaderboardView.swift` — add `.task { await vm.refresh() }`.
- Modify: `firestore.rules` — `leaderboard/{uid}` read-all / owner-write.

---

## Task 1: Pure merge+dedupe+rank (TDD)

Extend the existing pure `Leaderboard` engine so the service can merge entries from multiple sources (rival floor, real entries, current user) without duplicate names, current user winning collisions.

**Files:**
- Modify: `Fullball/Domain/Economy/Leaderboard.swift`
- Create: `FullballTests/LeaderboardTests.swift` (does not exist yet)

- [ ] **Step 1: Add failing tests.** Create `FullballTests/LeaderboardTests.swift`:

```swift
import Testing
@testable import Fullball

struct LeaderboardTests {
    @Test func dedupeKeepsCurrentUserOnNameCollision() {
        let entries = [
            LeaderboardEntry(userName: "Rival", points: 100),
            LeaderboardEntry(userName: "You", points: 50),
            LeaderboardEntry(userName: "You", points: 999, isCurrentUser: true),
        ]
        let ranked = Leaderboard.dedupedRanked(entries)
        // "You" appears once, as the current-user entry (999 points), ranked #1.
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
```

- [ ] **Step 2: Confirm fail** —
```
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests/LeaderboardTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: FAIL (`Leaderboard.dedupedRanked` not found).

- [ ] **Step 3: Implement.** Add to `Fullball/Domain/Economy/Leaderboard.swift`, inside `enum Leaderboard`, after `ranked`:

```swift
    /// Merge entries that may share a `userName`, keeping the current-user entry
    /// on any collision (else the higher-points entry), then rank. Used to fold
    /// the rival floor + real entries + the live current-user entry into one board.
    static func dedupedRanked(_ entries: [LeaderboardEntry]) -> [LeaderboardEntry] {
        var byName: [String: LeaderboardEntry] = [:]
        for entry in entries {
            if let existing = byName[entry.userName] {
                if entry.isCurrentUser {
                    byName[entry.userName] = entry
                } else if !existing.isCurrentUser, entry.points > existing.points {
                    byName[entry.userName] = entry
                }
            } else {
                byName[entry.userName] = entry
            }
        }
        return ranked(Array(byName.values))
    }
```

- [ ] **Step 4: Confirm pass** (same test command). Expected: PASS.

- [ ] **Step 5: Commit**
```
git add Fullball/Domain/Economy/Leaderboard.swift FullballTests/LeaderboardTests.swift
git commit -m "P2: pure leaderboard merge+dedupe+rank (+ tests)"
```

---

## Task 2: LeaderboardEntryDTO + FirestoreClient helpers

**Files:**
- Modify: `Fullball/Services/Firestore/CloudDTOs.swift`
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift`

- [ ] **Step 1: Add the DTO.** Append to `CloudDTOs.swift`:

```swift
struct LeaderboardEntryDTO: Codable, Equatable {
    var name: String
    var points: Int
}
```

- [ ] **Step 2: Add client helpers.** Inside `FirestoreClient`, after the pity helpers:

```swift
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
```

- [ ] **Step 3: Regenerate + build**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**
```
git add Fullball/Services/Firestore/CloudDTOs.swift Fullball/Services/Firestore/FirestoreClient.swift
git commit -m "P2: LeaderboardEntryDTO + Firestore put/fetch-top helpers"
```

---

## Task 3: LeaderboardService protocol + Firestore impl

**Files:**
- Modify: `Fullball/Services/LeaderboardService.swift`

- [ ] **Step 1: Replace the whole file** `Fullball/Services/LeaderboardService.swift` with:

```swift
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
}

/// Fixed local board for previews/offline. No cloud.
@MainActor
struct MockLeaderboardService: LeaderboardService {
    let currentUserName: String

    init(currentUserName: String = "You") { self.currentUserName = currentUserName }

    private let rivals: [(String, Int)] = LeaderboardRivals.floor

    func standings(userPoints: Int) -> [LeaderboardEntry] {
        var entries = rivals.map { LeaderboardEntry(userName: $0.0, points: $0.1) }
        entries.append(LeaderboardEntry(userName: currentUserName,
                                        points: userPoints, isCurrentUser: true))
        return Leaderboard.dedupedRanked(entries)
    }

    func refresh(userPoints: Int) async {}
}

/// Shared, real leaderboard. Publishes the user's entry to `leaderboard/{uid}`
/// and caches the top real entries; merges them with a cosmetic rival floor and
/// the live current-user entry for display. The cache is `@Observable` so the
/// board updates when a refresh lands.
@MainActor
@Observable
final class FirestoreLeaderboardService: LeaderboardService {
    let currentUserName: String
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
```

> This drops `Sendable` from the protocol (it's now `@MainActor`, which provides the isolation the existing call sites — all main-actor — need). `MockLeaderboardService` stays a struct.

- [ ] **Step 2: Regenerate + build**. Expected: `** BUILD SUCCEEDED **`. (If a non-main-actor caller surfaces, there is none in the codebase — both `AppContainer` and `LeaderboardViewModel` are `@MainActor`; report any as BLOCKED.)

- [ ] **Step 3: Commit**
```
git add Fullball/Services/LeaderboardService.swift
git commit -m "P2: @MainActor LeaderboardService + FirestoreLeaderboardService"
```

---

## Task 4: Wire bootstrap + RootView + VM refresh + View task

**Files:**
- Modify: `Fullball/App/AppContainer.swift`
- Modify: `Fullball/App/RootView.swift`
- Modify: `Fullball/Features/Leaderboard/LeaderboardViewModel.swift`
- Modify: `Fullball/Features/Leaderboard/LeaderboardView.swift`

- [ ] **Step 1: `AppContainer.init` accepts an injected leaderboard.** In the `init` signature (which already takes injected wallet/collection from P1), add a `leaderboard` param and use it. Change the param list to include:
```swift
         leaderboard injectedLeaderboard: (any LeaderboardService)? = nil,
```
(place it right after the `collection injectedCollection:` parameter). Then replace the line:
```swift
        self.leaderboard = MockLeaderboardService()
```
with:
```swift
        self.leaderboard = injectedLeaderboard ?? MockLeaderboardService()
```

- [ ] **Step 2: `bootstrap` builds the real leaderboard when signed in.** In the signed-in branch of `bootstrap` (the `guard let uid` path, after `cloudCollection` is built), add — using the threaded `userName`:

First add a `userName` parameter to `bootstrap`. Change its signature:
```swift
    static func bootstrap(context: ModelContext,
                          uid: String? = nil,
                          userName: String? = nil,
                          loader: any CatalogLoading = BundledCatalogLoader()) async -> AppContainer {
```
Then, in the signed-in branch, after `await cloudCollection.hydrate()` and before the `return`, build the leaderboard and pass it in:
```swift
        let displayName = (userName?.isEmpty == false ? userName! : "Agent \(uid.prefix(4))")
        let leaderboard = FirestoreLeaderboardService(uid: uid, currentUserName: displayName, client: client)

        return AppContainer(context: context, catalog: catalog,
                            wallet: cloudWallet, collection: cloudCollection,
                            leaderboard: leaderboard)
```
(Replace the existing `return AppContainer(... wallet: cloudWallet, collection: cloudCollection)` with the version above.)

- [ ] **Step 3: `RootView` passes the display name.** Change the bootstrap call to add `userName`:
```swift
            let c = await AppContainer.bootstrap(context: modelContext,
                                                 uid: auth.currentUser?.uid,
                                                 userName: auth.currentUser?.displayName,
                                                 loader: FullballConfig.catalogLoader)
```

- [ ] **Step 4: `LeaderboardViewModel` exposes refresh.** In `Fullball/Features/Leaderboard/LeaderboardViewModel.swift`, add a method:
```swift
    func refresh() async {
        await service.refresh(userPoints: score.points)
    }
```

- [ ] **Step 5: `LeaderboardView` triggers refresh.** In `Fullball/Features/Leaderboard/LeaderboardView.swift`, add a `.task` after the existing `.background(ScreenBackground())` on the root `VStack`:
```swift
        .background(ScreenBackground())
        .task { await vm.refresh() }
```

- [ ] **Step 6: Regenerate, build, full test suite**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **` then `** TEST SUCCEEDED **`. Confirm count with `grep -cE "✔ Test .* passed"` → **51** (48 prior + 3 new leaderboard).

- [ ] **Step 7: Commit**
```
git add Fullball/App/AppContainer.swift Fullball/App/RootView.swift Fullball/Features/Leaderboard/LeaderboardViewModel.swift Fullball/Features/Leaderboard/LeaderboardView.swift
git commit -m "P2: wire real leaderboard (bootstrap userName, VM/View refresh)"
```

---

## Task 5: Security rules for leaderboard

**Files:**
- Modify: `firestore.rules`

- [ ] **Step 1: Add the leaderboard match** inside `match /databases/{database}/documents { … }`, after the `config` block:

```
    // Shared leaderboard: anyone signed in may read; a player may write only
    // their own entry (doc id == their uid). No validation of the points value
    // yet (anti-cheat is a later hardening pass).
    match /leaderboard/{entryUid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == entryUid;
    }
```

- [ ] **Step 2: Commit**
```
git add firestore.rules
git commit -m "P2: leaderboard security rules (read-all, owner-write)"
```

- [ ] **Step 3 (MANUAL — human):** Re-publish the rules (console → Firestore → Rules → paste full `firestore.rules` → Publish, or `firebase deploy --only firestore:rules`). Until republished, leaderboard writes fail `permission-denied` and the board shows only the cosmetic floor + you.

---

## Done criteria (P2)

- Build green; **51 unit tests pass**.
- After republishing rules and signing in: opening the Agencies tab publishes `leaderboard/{uid}` (verify in Firebase console → Firestore Data) and the board shows you ranked among the rival floor.
- A second signed-in device/account appears as a real entry on both boards, ranked by points.
- The current user is highlighted and `#rank` shows in the header (existing UI, unchanged).

## Known limitations (acceptable for P2)

- **Cosmetic rival floor is client-side** (not shared); real players are shared via Firestore. Remove the floor once the real player base is large enough.
- **Points are published on board-open / bootstrap**, not on every points change — others see your last-viewed points (slightly stale). Acceptable; could publish on match settlement later.
- **No anti-cheat on points** — rules only enforce ownership, not value validity (a tampered client could post inflated points). A later hardening pass (or Cloud Functions) can validate.
- **Display name** falls back to `Agent <uid prefix>` when Apple withheld the name (only provided on first sign-in).
- **`LeaderboardEntry` identity is `userName`, not uid** (`id == userName`, dedupe keys by name). Two distinct real players sharing a display name collapse into one row (higher points kept). Harmless for the MVP floor (and it guards `ForEach` against duplicate ids), but once the real player base grows, switch `LeaderboardEntry.id` to carry uid and dedupe by uid. Tracked from the P2 review.

## Out of scope (later phases)

- Remote catalog → **P3**. Shared slate → **P4**. Server gacha → **P5**.
- Per-friend / seasonal boards, pagination beyond top-50.
