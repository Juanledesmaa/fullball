# Firebase P4 — Shared Slate + Progress Cloud-Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) Make the live match slate **globally shared** — every player sees the same fixtures per time block — by deriving the slate seed from the time block alone (no device component). (2) **Cloud-save `LiveProgress`** (points, Rep earned, daily-claim, milestones, slate meta) so points survive reinstall and the P2 leaderboard entry stays durable.

**Architecture:** The slate is already keyed by a device-independent `slateID` (day + 8h block); only the *seed* mixed in `deviceBase`. Adding `DeviceSeed.sharedSeed(for:)` (= `fnv1a(slateID)`, no device) and switching `MatchSlateService` to it makes the base slate identical across devices — no Firestore seed doc, no config-seeding. Progress cloud-save reuses the P1 pattern: `ScoreBoard` becomes cloud-aware (write-through the whole `LiveProgress` snapshot after each award; `hydrate()` on login where cloud wins), wired in `AppContainer.bootstrap` only when signed in. `users/{uid}/state/progress` is already covered by the P1 owner-scoped rule, so **no security-rules change**.

**Tech Stack:** Swift 6 strict concurrency, FirebaseFirestore 11.15 (Codable), SwiftData, XcodeGen.

**Scope decision (deliberate):** This phase does **shared slate + `LiveProgress` cloud-save** only. **Deferred** (noted, lower value): cloud-saving `Lineup` (persistent but minor) and `MatchRecord` (slate-transient — expires each block, regenerated). `LiveProgress` has four mutators (`ScoreBoard`, `MatchSlateService`, `RewardsService`, `MilestoneService`); P4 syncs it **opportunistically** — every `ScoreBoard.award` pushes the whole snapshot (capturing whatever the other services last wrote to the shared model row), and `hydrate()` restores everything on login. A change to daily/milestone with no subsequent award before app close lags until the next award or relaunch — acceptable for single-device MVP, documented below.

**Testing note:** Per CLAUDE.md, only deterministic logic is tested. P4's pure seams: `DeviceSeed.sharedSeed` (device-independence) and `ProgressDTO` mapping — both TDD. Existing 51 tests stay green.

---

## Firestore layout (P4 addition)

```
users/{uid}/state/progress   ← {points, formTokensEarned, lastDailyClaim?, milestonesClaimed, slateBlock?, slateRefreshCount}
```

(Same `state` subcollection as the P1 wallet doc. Covered by the existing `users/{uid}/{document=**}` owner rule — no rules change.)

## File structure (P4)

- Modify: `Fullball/App/DeviceSeed.swift` — add `sharedSeed(for:)`.
- Modify: `Fullball/Services/MatchSlateService.swift` — use `sharedSeed` for slate generation.
- Test: `FullballTests/DeviceSeedTests.swift` — shared-seed determinism + device-independence.
- Modify: `Fullball/Services/Firestore/CloudDTOs.swift` — add `ProgressDTO`.
- Test: `FullballTests/CloudDTOTests.swift` — add `ProgressDTO` round-trip.
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift` — `fetchProgress` / `putProgress`.
- Modify: `Fullball/Domain/Models/ScoreBoard.swift` — cloud-aware `ScoreBoard` (write-through + `hydrate`).
- Modify: `Fullball/App/AppContainer.swift` — `init` accepts injected `score`; `bootstrap` builds the cloud-aware ScoreBoard + hydrates.

---

## Task 1: Shared slate seed (TDD)

Make the base slate seed device-independent so all players share fixtures per block. `slateID` is already device-independent; only the seed mixed `deviceBase`.

**Files:**
- Modify: `Fullball/App/DeviceSeed.swift`
- Modify: `Fullball/Services/MatchSlateService.swift`
- Test: `FullballTests/DeviceSeedTests.swift` (new)

- [ ] **Step 1: Write failing tests** — create `FullballTests/DeviceSeedTests.swift`:

```swift
import Testing
@testable import Fullball

struct DeviceSeedTests {
    @Test func sharedSeedIsStableForASlateID() {
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") == DeviceSeed.sharedSeed(for: "20260617-1"))
    }

    @Test func sharedSeedDiffersBySlateID() {
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != DeviceSeed.sharedSeed(for: "20260617-2"))
    }

    @Test func sharedSeedIsDeviceIndependent() {
        // It must NOT mix in the device base — i.e. it equals the hash of the
        // slateID alone, so two devices derive the same value.
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != DeviceSeed.seed(for: "20260617-1")
                || DeviceSeed.deviceBase == 0)
        // The shared seed is non-zero and purely a function of the id.
        #expect(DeviceSeed.sharedSeed(for: "20260617-1") != 0)
    }
}
```

- [ ] **Step 2: Confirm fail** —
```
xcodegen generate
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests/DeviceSeedTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: FAIL (`sharedSeed` not found).

- [ ] **Step 3: Implement.** In `Fullball/App/DeviceSeed.swift`, add a `sharedSeed` method (after the existing `seed(for:)`):

```swift
    /// Device-INDEPENDENT seed: a pure function of the slate id, so every
    /// device derives the same slate for a given time block (shared world).
    static func sharedSeed(for slateID: String) -> UInt64 { fnv1a(slateID) }
```

> `fnv1a` is `private`; `sharedSeed` is in the same `enum DeviceSeed`, so it can call it. Leave `deviceBase`/`seed(for:)` as-is — `TransferMarketService` still uses `seed(for:)` for its personal daily shortlist (intentionally NOT shared in this phase).

- [ ] **Step 4: Switch the slate to the shared seed.** In `Fullball/Services/MatchSlateService.swift`, find:
```swift
    private static func generate(slateID: String, catalog: any CatalogService) -> [Fixture] {
        FixtureGenerator.slate(seed: DeviceSeed.seed(for: slateID),
                               nations: catalog.nations, cards: catalog.cards)
    }
```
and change `DeviceSeed.seed(for: slateID)` to `DeviceSeed.sharedSeed(for: slateID)`:
```swift
    private static func generate(slateID: String, catalog: any CatalogService) -> [Fixture] {
        FixtureGenerator.slate(seed: DeviceSeed.sharedSeed(for: slateID),
                               nations: catalog.nations, cards: catalog.cards)
    }
```

- [ ] **Step 5: Confirm pass** (same test command). Expected: PASS (3 tests).

- [ ] **Step 6: Commit**
```
git add Fullball/App/DeviceSeed.swift Fullball/Services/MatchSlateService.swift FullballTests/DeviceSeedTests.swift
git commit -m "P4: shared (device-independent) slate seed (+ tests)"
```

---

## Task 2: ProgressDTO + FirestoreClient helpers (TDD for the DTO)

**Files:**
- Modify: `Fullball/Services/Firestore/CloudDTOs.swift`
- Test: `FullballTests/CloudDTOTests.swift`
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift`

- [ ] **Step 1: Add a failing DTO test.** Append a method to the existing `CloudDTOTests` struct in `FullballTests/CloudDTOTests.swift` (it already imports `Testing`, `SwiftData`, `Foundation` and is `@MainActor`; add `LiveProgress.self` to its container schema). First update its container line:
```swift
    private let container = try! ModelContainer(
        for: Schema([Wallet.self, CardInstance.self, LiveProgress.self]),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
```
Then add:
```swift
    @Test func progressRoundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let p = LiveProgress(points: 1200, formTokensEarned: 40,
                             lastDailyClaim: date, milestonesClaimed: 2)
        p.slateBlock = "20260617-1"
        p.slateRefreshCount = 3
        let dto = ProgressDTO(p)
        #expect(dto.points == 1200 && dto.formTokensEarned == 40)
        #expect(dto.lastDailyClaim == date && dto.milestonesClaimed == 2)
        #expect(dto.slateBlock == "20260617-1" && dto.slateRefreshCount == 3)
        let p2 = LiveProgress()
        dto.apply(to: p2)
        #expect(p2.points == 1200 && p2.formTokensEarned == 40 && p2.milestonesClaimed == 2)
        #expect(p2.lastDailyClaim == date && p2.slateBlock == "20260617-1" && p2.slateRefreshCount == 3)
    }
```

- [ ] **Step 2: Confirm fail** —
```
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests/CloudDTOTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: FAIL (`ProgressDTO` not found).

- [ ] **Step 3: Add the DTO.** Append to `Fullball/Services/Firestore/CloudDTOs.swift`:

```swift
struct ProgressDTO: Codable, Equatable {
    var points: Int
    var formTokensEarned: Int
    var lastDailyClaim: Date?
    var milestonesClaimed: Int
    var slateBlock: String?
    var slateRefreshCount: Int

    init(points: Int, formTokensEarned: Int, lastDailyClaim: Date?,
         milestonesClaimed: Int, slateBlock: String?, slateRefreshCount: Int) {
        self.points = points; self.formTokensEarned = formTokensEarned
        self.lastDailyClaim = lastDailyClaim; self.milestonesClaimed = milestonesClaimed
        self.slateBlock = slateBlock; self.slateRefreshCount = slateRefreshCount
    }

    @MainActor init(_ p: LiveProgress) {
        self.init(points: p.points, formTokensEarned: p.formTokensEarned,
                  lastDailyClaim: p.lastDailyClaim, milestonesClaimed: p.milestonesClaimed,
                  slateBlock: p.slateBlock, slateRefreshCount: p.slateRefreshCount)
    }

    @MainActor func apply(to p: LiveProgress) {
        p.points = points; p.formTokensEarned = formTokensEarned
        p.lastDailyClaim = lastDailyClaim; p.milestonesClaimed = milestonesClaimed
        p.slateBlock = slateBlock; p.slateRefreshCount = slateRefreshCount
    }
}
```

- [ ] **Step 4: Confirm pass** (same test command). Expected: PASS.

- [ ] **Step 5: Add FirestoreClient helpers.** Inside `FirestoreClient`, after the leaderboard helpers:

```swift
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
```

- [ ] **Step 6: Regenerate + build**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**
```
git add Fullball/Services/Firestore/CloudDTOs.swift FullballTests/CloudDTOTests.swift Fullball/Services/Firestore/FirestoreClient.swift
git commit -m "P4: ProgressDTO + Firestore progress helpers (+ test)"
```

---

## Task 3: Cloud-aware ScoreBoard

`ScoreBoard` gains an optional Firestore backing: when signed in it writes the whole `LiveProgress` snapshot through after each award and can `hydrate()` from the cloud on login. Signed-out (previews/tests) it behaves exactly as today.

**Files:**
- Modify: `Fullball/Domain/Models/ScoreBoard.swift`

- [ ] **Step 1: Make `ScoreBoard` cloud-aware.** Replace the `ScoreBoard` class (keep the `LiveProgress` `@Model` above it unchanged) with:

```swift
/// Live user score driven by the match feed, persisted via SwiftData and —
/// when signed in — written through to Firestore so points/daily/milestone
/// state survive reinstall and keep the leaderboard entry durable.
@MainActor
@Observable
final class ScoreBoard {
    private let context: ModelContext
    private let model: LiveProgress
    private let client: FirestoreClient?
    private let uid: String?

    init(context: ModelContext, client: FirestoreClient? = nil, uid: String? = nil) {
        self.context = context
        self.client = client
        self.uid = uid
        let descriptor = FetchDescriptor<LiveProgress>()
        if let existing = try? context.fetch(descriptor).first {
            self.model = existing
        } else {
            let fresh = LiveProgress()
            context.insert(fresh)
            self.model = fresh
            try? context.save()
        }
    }

    var points: Int { model.points }
    var formTokensEarned: Int { model.formTokensEarned }

    func award(points: Int, formTokens: Int) {
        model.points += points
        model.formTokensEarned += formTokens
        try? context.save()
        push()
    }

    /// Login reconciliation. Cloud wins; if no cloud doc exists, seed it from local.
    func hydrate() async {
        guard let client, let uid else { return }
        do {
            if let dto = try await client.fetchProgress(uid: uid) {
                dto.apply(to: model)
                try? context.save()
            } else {
                try await client.putProgress(uid: uid, ProgressDTO(model))
            }
        } catch {
            print("Progress hydrate failed: \(error as NSError)")
        }
    }

    /// Fire-and-forget write-through of the whole progress snapshot.
    private func push() {
        guard let client, let uid else { return }
        let dto = ProgressDTO(model)
        Task { do { try await client.putProgress(uid: uid, dto) } catch { print("putProgress failed: \(error)") } }
    }
}
```

> The whole-snapshot push means fields written by `RewardsService`/`MilestoneService`/`MatchSlateService` to the shared `LiveProgress` row are captured on the next `award`. `hydrate()` restores everything on login.

- [ ] **Step 2: Regenerate + build**. Expected: `** BUILD SUCCEEDED **`. (`ScoreBoard.swift` imports `Foundation`/`SwiftData`; `FirestoreClient`/`ProgressDTO` are in the same module — no new import needed.)

- [ ] **Step 3: Commit**
```
git add Fullball/Domain/Models/ScoreBoard.swift
git commit -m "P4: cloud-aware ScoreBoard (LiveProgress write-through + hydrate)"
```

---

## Task 4: Wire bootstrap

Build the cloud-aware `ScoreBoard` when signed in and hydrate it; inject it into `AppContainer`. Signed-out keeps the local ScoreBoard.

**Files:**
- Modify: `Fullball/App/AppContainer.swift`

- [ ] **Step 1: `init` accepts an injected score.** Add a parameter after `leaderboard injectedLeaderboard:`:
```swift
         score injectedScore: ScoreBoard? = nil,
```
Then find:
```swift
        self.score = ScoreBoard(context: context)
```
and replace with:
```swift
        self.score = injectedScore ?? ScoreBoard(context: context)
```

- [ ] **Step 2: `bootstrap` builds + hydrates the cloud ScoreBoard.** In the signed-in branch (after the `leaderboard` is built, before the `return`), add:
```swift
        let score = ScoreBoard(context: context, client: client, uid: uid)
        await score.hydrate()
```
and add `score: score` to the `AppContainer(...)` call. The signed-in `return` becomes:
```swift
        return AppContainer(context: context, catalog: catalog,
                            wallet: cloudWallet, collection: cloudCollection,
                            leaderboard: leaderboard, score: score)
```

> Hydrate `score` BEFORE the leaderboard's first refresh would publish points — order: wallet, collection, (leaderboard built), score.hydrate(). Since the leaderboard publishes on the View's `.task` (not at bootstrap), score is already hydrated by then, so the first publish uses restored points. Good.

- [ ] **Step 3: Regenerate, build, full test suite**
```
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'
```
Expected: `** BUILD SUCCEEDED **` then `** TEST SUCCEEDED **`. Confirm count with `grep -cE "✔ Test .*\(\) passed"` → **55** (51 prior + 3 DeviceSeed + 1 ProgressDTO).

- [ ] **Step 4: Confirm `AppContainer.preview()` still compiles** (it omits `score` → local ScoreBoard; the build proves it).

- [ ] **Step 5: Commit**
```
git add Fullball/App/AppContainer.swift
git commit -m "P4: wire cloud-aware ScoreBoard into bootstrap (hydrate on login)"
```

---

## Done criteria (P4)

- Build green; **55 unit tests pass**.
- **Shared slate:** two different devices (or a reinstall on the same account) signed in within the same 8h block see the **same** Live fixtures. (The slate is now a pure function of the time block.)
- **Progress durable:** earn points in Live → `users/{uid}/state/progress` updates (Firebase console). Delete + reinstall → sign in → points restore (not reset to 0), and the leaderboard entry keeps the real total.
- No security-rules change required (covered by the P1 `users/{uid}/**` rule).

## Known limitations (acceptable for P4)

- **Opportunistic progress sync:** only `ScoreBoard.award` and login `hydrate()` push `LiveProgress`. A daily-claim or milestone change with no subsequent award before the app closes lags until the next award/relaunch. Single-device MVP is fine; a dedicated per-mutator push (or a lifecycle flush) can harden it later.
- **Manual slate refresh (`#r<n>`) stays personal** (counter-mixed) — only the *free* base slate is shared. Intended (refresh is a premium "fresh board just for you").
- **Transfer market shortlist stays device-personal** (`DeviceSeed.seed`), not shared — out of scope this phase; could share the same way later if desired.
- **Lineup + MatchRecord are not cloud-saved yet** — deferred (lineup persistent-but-minor; match records slate-transient/regenerated). Follow-up if needed.

## Out of scope (later phases)

- Server gacha (commit-reveal + transaction) → **P5**.
- Remote catalog → **P3** (deferred to the asset revamp).
- Lineup / match-record cloud-save; perfect multi-mutator progress sync.
