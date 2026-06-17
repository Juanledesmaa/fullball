# Firebase Backend — Design Spec

**Date:** 2026-06-16
**Branch:** `feat/firebase-backend`
**Status:** Approved, pre-implementation

Adds a server-authoritative backend (Firebase) to Fullball, an offline MVP. Delivers five
features from [ROADMAP](../../ROADMAP.md): real leaderboard (#1), shared match slate (#2),
cloud save (#3), server-validated gacha (#5), remote catalog (#6).

## Goals

- Real cross-player leaderboard, shared fixtures, cloud-saved progress, server-authoritative
  wallet/gacha, remotely-updatable catalog.
- Zero change to ViewModels and Views — only service *implementations* and `AppContainer`
  wiring change. Firebase must not leak past the service layer.
- Stay on Firebase's free **Spark** plan (no Cloud Functions).

## Non-goals

- Cloud Functions / fully tamper-proof gacha (deferred; drop-in later behind same protocol).
- Data migration (pre-release MVP, no real users — fresh server start on first login).
- Push notifications, localization, real IAP (separate future work).

## Decisions (locked)

| Topic | Decision | Rationale |
|---|---|---|
| Backend | Firebase (Auth + Firestore), Spark plan | User choice; overrides CLAUDE.md zero-dep constraint #9 |
| Source of truth | **Server-authoritative** — Firestore is truth, SwiftData becomes read cache | Simplest consistency; #5 already forces server-side pulls |
| Identity | **Sign in with Apple**, day one, via Firebase Auth | User choice; real account + cross-device restore from launch |
| Gacha #5 | Firestore transaction (pity + wallet authoritative) + **commit-reveal** seed for fair RNG | Free-tier; no Functions. Residual: client computes derivation |
| Slate #2 | Global `config/slate` seed doc → existing `FixtureGenerator` on every client | Identical slate for all, free-tier, reuses pure generator |
| Catalog #6 | Firestore-backed `CatalogLoading`; `Fictionalizer` stays name chokepoint | Existing seam already proves drop-in |
| Migration | None | Pre-release; sim data disposable |
| Build order | **Phased** (P0→P5), each ships green with its own plan | Lower risk, reviewable, rollback-able |

## Architecture

```
Views → ViewModels → Service protocols (UNCHANGED) → Firebase-backed impls → Firestore/Auth
                                                    ↘ SwiftData local cache mirror (offline reads)
```

`AppContainer` (the only composition root) wires Firebase-backed impls in place of the
SwiftData/mock impls. Protocols (`WalletService`, `CollectionService`, `GachaService`,
`LeaderboardService`, `CatalogLoading`, `MatchSlateService`, `MatchProgressStore`, plus a new
`AuthService`) are unchanged in shape, so ViewModels and Views need no edits.

## Firestore schema

```
users/{uid}/
  wallet                      {coins, gems, tickets, formTokens}
  collection/{cardID}         {level, stars, xp, copies, dateAcquired}
  pity/{bannerID}             {pullsSinceIcon, guaranteeFeatured}
  progress                    {points, formTokensEarned, lastDailyClaim, milestonesClaimed,
                               slateBlock, slateRefreshCount}
  lineup                      {fieldedIDs, captainID}
  matches/{slateID_fixtureID} {status, points, form, score, bonus}
leaderboard/{uid}             {agencyName, points}            ← #1
config/catalog                {cards[], banners[]}            ← #6 (fictionalized)
config/slate                  {seed, block, generatedAt}      ← #2
config/gachaSeed/{bannerID}   {committedSeedHash, ...}        ← #5 commit-reveal
```

Mirrors existing SwiftData entities (`Wallet`, `CardInstance`, `BannerPity`, `LiveProgress`,
`Lineup`, `MatchRecord`) one-to-one, so the value DTOs map cleanly.

## Security rules (the "server" — no Functions)

- `users/{uid}/**`: only the owner reads/writes.
- Wallet writes: rule rejects negative balances and enforces `debit == declared cost`, applied
  inside an atomic transaction.
- `pity`: increments only within the pull transaction.
- `leaderboard/{uid}`: owner writes only own `points`.
- `config/**`: read-only to clients; seeded out-of-band (script/console).

## Gacha #5 — commit-reveal, free-tier

1. `config/gachaSeed/{bannerID}` holds a server-committed seed (hash published ahead of pull).
2. A pull runs one Firestore transaction: read `wallet` + `pity` → validate cost → debit wallet →
   increment/reset pity → derive the outcome deterministically from the committed seed + pity
   counter using the existing pure `GachaEngine`.
3. Pity and wallet cannot be forged (transaction + rules). Odds are provably fair (seed committed
   before the pull). **Residual:** the client executes the derivation, so a tampered client could
   compute a different outcome; full enforcement needs Cloud Functions later — a drop-in behind the
   unchanged `GachaService` protocol.

## Phases

Each phase is independently shippable, stays green, and gets its own implementation plan.

- **P0 — Foundation.** Add Firebase SPM (Auth + Firestore) to `project.yml`. New `AuthService`
  protocol + `FirebaseAuthService` (Sign in with Apple → Firebase credential). SIWA gate in
  onboarding before `MainTabView`. `FirestoreClient` wrapper. Enable Firestore offline persistence.
- **P1 — Cloud save (#3).** `WalletService` + `CollectionService` Firestore impls (protocols
  unchanged); SwiftData demoted to read-cache mirror; starter wallet seeded server-side on first login.
- **P2 — Leaderboard (#1).** `LeaderboardService` → real `leaderboard` collection; top-N query +
  user rank; user highlighted (existing UI).
- **P3 — Remote catalog (#6).** Firestore-backed `CatalogLoading`; `Fictionalizer` stays the name
  chokepoint; bundled JSON remains the offline fallback.
- **P4 — Shared slate (#2).** `MatchSlateService` reads `config/slate.seed` → existing
  `FixtureGenerator`; `MatchProgressStore` → per-user Firestore (`users/{uid}/matches`).
- **P5 — Server gacha (#5).** `GachaService` Firestore-transaction impl per the commit-reveal flow above.

## Swift 6 concurrency

Firestore types are not `Sendable`; map them to value DTOs at the service boundary. All Firebase
calls are wrapped in `async/await` inside `@MainActor` services. Keeps
`SWIFT_STRICT_CONCURRENCY: complete` green.

## Testing

- Existing 42 pure economy/generation tests stay green (that layer is untouched).
- No Firebase-wiring unit tests (matches the project's "no view/navigation/wiring tests" rule).
- Firebase Local Emulator Suite is available for optional integration checks later.

## Risks / accepted trade-offs

- **Zero-dep constraint #9 broken** (user's call). Dependency quarantined behind service protocols.
- **SIWA at first launch** = network + Apple ID required; the game was fully offline. Local cache
  tolerates brief disconnects after sign-in.
- **#5 residual trust:** client computes the derivation; full tamper-proofing needs Functions (later).
- **Cost:** Spark (free) covers all five features. Blaze (paid) only if Functions are added later.

## Constraints preserved

iPhone-only portrait · SwiftUI `@Observable` MVVM · Swift 6 strict concurrency · iOS 17 · no real
player likeness · virtual currency only · disclose gacha odds · no "Co-Authored-By" trailer.
(Zero-dep constraint #9 is the single intentional exception.)
