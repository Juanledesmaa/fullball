# Architecture

MVVM with strict one-way dependencies, an `@Observable` everything, SwiftData
for owned state, and protocol-first services. Fully offline; designed so a real
backend drops in behind the existing protocols without touching ViewModels.

## Layers

```
Views (SwiftUI, dumb)  →  ViewModels (@MainActor @Observable)  →  Services (protocol-first)  →  Models
                                   ↑ built from ↑
                            AppContainer (composition root)
```

- **Views** own their VM via `@State private var vm` (built in `init` from the injected `AppContainer`). No business logic. Every meaningful screen has a `#Preview` using `AppContainer.preview()`.
- **ViewModels** hold view state, call services, expose intent methods (`pull`, `enter`, `sign`, `train`, `limitBreak`, `refreshSlate`…). No SwiftUI beyond Observation.
- **Services** are protocols with concrete (SwiftData / mock) impls. ViewModels depend on the protocol, never the concretion.
- **Models**: value types + SwiftData `@Model` entities. The **economy is pure** (structs/enums + free functions, injected RNG) and lives in `Domain/Economy/` — fully unit-testable.

## Composition root — `AppContainer`

[`App/AppContainer.swift`](../Fullball/App/AppContainer.swift) is the only place
services are constructed and wired. It's `@MainActor @Observable`, injected via
`.environment`, and built async by `AppContainer.bootstrap(context:loader:)`
(resolves the catalog — bundled or remote — then wires everything).

Holds: `catalog`, `wallet`, `collection`, `gacha`, `live`, `leaderboard`,
`score` (`ScoreBoard`), `rewards`, `lineup`, `milestones`, `exchange`,
`matchStore`, `slate` (`MatchSlateService`), `market` (`TransferMarketService`),
`navigator`. `static schema` lists the SwiftData models.

`RootView` builds the container from the environment `modelContext` in `.task`,
shows `MainTabView`, and presents the first-run `LoopIntroView`
(`@AppStorage("didSeeIntro")`).

## Services

| Service | Protocol? | Backing | Role |
|---|---|---|---|
| `CatalogService` | yes | `BundledCatalogService` / `MockCatalogService` / `ResolvedCatalogService` | static catalog: cards, banners, fixtures, nations |
| `WalletService` | yes (`@MainActor`) | `SwiftDataWalletService` | `Wallet` balances + per-banner `BannerPity` |
| `CollectionService` | yes (`@MainActor`) | `SwiftDataCollectionService` | owned `CardInstance`s; acquire / train / limit-break |
| `GachaService` | yes (`@MainActor`) | `DefaultGachaService` | wraps `GachaEngine` + wallet + collection + pity |
| `LiveMatchService` | yes | `MockLiveMatchService` | `play(fixture)` → `AsyncStream<MatchTick>` clock |
| `MatchSlateService` | class (`@Observable`) | — | owns the generated slate; refresh-for-Gems |
| `MatchProgressStore` | yes (`@MainActor`) | `SwiftDataMatchStore` | persist match entries/results (`MatchRecord`) |
| `TransferMarketService` | class (`@Observable`) | — | daily transfer shortlist; sign for Cash |
| `LineupService` | yes (`@MainActor`) | `SwiftDataLineupService` | fielded clients + captain (`Lineup`) |
| `MilestoneService` | yes (`@MainActor`) | `DefaultMilestoneService` | grant career-point milestones |
| `ExchangeService` | yes (`@MainActor`) | `DefaultExchangeService` | Rep → Scouts/Gems |
| `RewardsService` | yes (`@MainActor`) | `DefaultRewardsService` | daily drop |
| `LeaderboardService` | yes (`@MainActor`) | `MockLeaderboardService` / `FirestoreLeaderboardService` | agency ranking (shared via Firestore) |
| `ScoreBoard` | class (`@Observable`) | SwiftData `LiveProgress` (+ optional Firestore write-through) | live points/Rep/daily/milestone/slate meta |
| `AuthService` | yes (`@MainActor`) | `FirebaseAuthService` / `MockAuthService` | Sign in with Apple → Firebase session |

## Firebase backend (branch `feat/firebase-backend`, merged to `main`)

Server-authoritative backend behind the existing protocols — no ViewModel/View churn. Firebase is quarantined in `Services/Auth` + `Services/Firestore`. See the spec + per-phase plans under `docs/superpowers/`.

- **Auth (P0):** `RootView` gates the app behind `SignInView` (Sign in with Apple) until `auth.currentUser != nil`. `FirebaseApp.configure()` runs at launch *only if* `GoogleService-Info.plist` is bundled (gitignored; injected in CI).
- **Cloud save (P1):** `FirestoreWalletService` / `FirestoreCollectionService` **decorators** wrap the SwiftData impls — reads hit the local cache; mutations write through to Firestore async; `hydrate()` on login (cloud wins, seed-if-absent). Same pattern for progress via the cloud-aware `ScoreBoard` (P4).
- **Leaderboard (P2):** `FirestoreLeaderboardService` publishes `leaderboard/{uid}`, fetches top-N, merges a cosmetic rival floor + the live user entry via the pure `Leaderboard.dedupedRanked`.
- **Shared slate (P4):** `DeviceSeed.sharedSeed(for:)` (no device base) → all players share fixtures per time block.
- **Composition:** `AppContainer.bootstrap(context:uid:userName:loader:)` builds the Firestore-backed services + hydrates only when signed in; signed-out (previews/tests) uses the local/mock services. `FirestoreClient` (`@MainActor`) is the single DB entry point; `CloudDTOs` are the Codable wire types. Firestore types are non-`Sendable` → confined to `@MainActor`.
- **Rules:** `firestore.rules` — `users/{uid}/**` owner-only, `leaderboard/{uid}` read-all/owner-write, `catalog/{document=**}` world-readable. `storage.rules` — `players/{file}` world-readable, no client writes. Publish in the console after changes.
- **Parked/deferred:** P5 server gacha (needs Cloud Functions/Blaze — not on free tier). Monetization decided = StoreKit-only. See ROADMAP.

## SwiftData (`AppContainer.schema`)

`Wallet`, `CardInstance`, `BannerPity`, `LiveProgress`, `Lineup`, `MatchRecord`.
**Add a model → add it here** or it won't persist. When signed in these mirror to Firestore (`users/{uid}/state/wallet`, `…/collection/{cardID}`, `…/pity/{bannerID}`, `…/state/progress`); `Lineup` + `MatchRecord` are not cloud-saved yet (deferred).

- `Wallet` — currency balances (single row).
- `CardInstance` — owned card: `cardID` (unique), `level`, `stars`, `xp`, `copies`, `dateAcquired`.
- `BannerPity` — per-banner `pullsSinceIcon` + `guaranteeFeatured`.
- `LiveProgress` — meta singleton: `points`, `formTokensEarned`, `lastDailyClaim`, `milestonesClaimed`, `slateBlock`, `slateRefreshCount`.
- `Lineup` — `fieldedIDs` + `captainID`.
- `MatchRecord` — per `(slateID, fixtureID)`: status/points/form/score/bonus.

## Determinism & generation

Everything "random but stable" is seeded:
- `RandomProvider` (protocol) — `SeededRandomProvider` (SplitMix64) for tests/generation, `SystemRandomProvider` for production gacha, plus `ScriptedRandomProvider` for exact-sequence tests.
- FNV-1a hashes turn ids/strings into seeds (`NameGenerator`, `DeviceSeed`, `WC.spectrumColor`).
- `FixtureGenerator.slate(seed:nations:cards:)` — pure procedural fixtures.
- `DeviceSeed` — `identifierForVendor` (UDID-equivalent) ⊕ an 8-hour time block ⊕ refresh counter.

## Catalog data

- `Resources/catalog.json` is authored via `tools/player_manifest.csv` + compiled by `tools/build_catalog.py`. **61 curated players** (51 regular + 10 icons) across 16 nations. `banners.json` is hand-edited; `fixtures.json` exists but Live no longer uses it (the generator replaced it).
- Provenance: nations + stat spreads *inspired by* api-football v3 WC2022 (free tier); the `Fictionalizer` is the single chokepoint guaranteeing names stay fictional. Player cards carry authored short names (`Player.name`, optional `Player.epithet`); `NameGenerator` is the fallback.
- **Remote catalog (P3 — done):** `FirestoreCatalogLoader` reads `catalog/current` from Firestore; bundled `catalog.json` is the offline fallback. Wired via the existing `CatalogLoading` async seam in `RootView`. Allows live-ops retuning without an app release; seeding is out-of-band (admin script).
- The opt-in `APIFootballCatalogLoader` path (set `FullballConfig.apiFootballKey`) is still present but secondary.

## Portraits

- Player images are stored in **Firebase Storage** at `players/{id}.jpg` and fetched by `PlayerImageStore` (memory `NSCache` → disk cache in `Caches/players/` → Storage download on miss). Injected via SwiftUI environment key `\.playerImageStore`.
- `AvatarView` — async, top-anchored fill for cards/grids; shows a rarity-tinted position-symbol placeholder while loading or offline. `CardPortraitFull` — async full vertical image for Card Detail.
- `AvatarAssets` (the old FNV-hash enum mapping card id → bundled JPG) was **removed**. The old `Resources/Avatars/avatar_NNN.jpg` bundle is now unused and can be deleted.
- The earlier procedural avatars (`PixelAvatar` CryptoPunks-style, `VectorAvatar` illustrated) were also **removed** previously.

## UI components & theme

- `WC` ([Theme.swift](../Fullball/Features/Components/Theme.swift)) — colors (adaptive neutrals via asset colorsets; `WC.spectrum` brand palette) + system display/ui fonts (Archivo not bundled).
- `SharedUI.swift` — `ScreenHeader`, `SectionLabel`, `Chip`, `LiveDot`, `NationBadge` (real flag from `Assets.xcassets/Flags/flag_<TAG>`, gray stand-in fallback), `PanelCard`, `RarityTag`, `StarRow`, etc.
- `CardFace.swift` — `CardArt` (portrait window), `CardTile` (roster card), `CardHero` (reveal/detail header).
- Navigation: each tab is its own `NavigationStack`; `Navigator` (in `AppContainer`) holds the selected tab so any screen can route (e.g. empty Roster → Scout).

## Tests (`FullballTests`, Swift Testing)

64 tests, all on the **pure** layer (economy/generation + cloud mapping + auth nonce):
`GachaEngineTests` (odds over 300k N, soft/hard pity, 50/50, counter resets),
`UpgradeRulesTests`, `LeaderboardTests` (ranking + `dedupedRanked` merge), `FictionalizerTests` (names stay fictional),
`NameGeneratorTests`, `EconomyTests` (milestones, exchange, refresh, commission, transfer pricing),
`FixtureGeneratorTests` (determinism, valid refs), `LineupServiceTests` (field/captain/cap, in-memory SwiftData),
`NonceTests` (Sign in with Apple nonce), `CloudDTOTests` (wallet/card/pity/progress DTO round-trips),
`DeviceSeedTests` (shared slate seed is device-independent).
No view/navigation/Firebase-wiring tests by design. (Run on `iPhone 16` — the `iPhone 15` sim is gone on current Xcode.)
