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

Holds: `auth` (`AuthService`), `catalog`, `wallet`, `collection`, `gacha`, `live`, `leaderboard`,
`score` (`ScoreBoard`), `rewards`, `energy`, `milestones`, `exchange`,
`matchStore`, `slate` (`MatchSlateService`), `market` (`TransferMarketService`),
`navigator`. `static schema` lists the SwiftData models. (`lineup` / `LineupService` removed.)

`RootView` calls `signInAnonymously()` in `.task` (anon-first), then builds the uid-keyed container and shows `MainTabView`. `.onChange(of: auth.currentUser?.uid)` triggers a container rebuild on account/uid change. Also presents the first-run `LoopIntroView` (`@AppStorage("didSeeIntro")`) and `LinkAccountView` when `navigator.linkPromptPending` is set.

## Services

| Service | Protocol? | Backing | Role |
|---|---|---|---|
| `CatalogService` | yes | `BundledCatalogService` / `MockCatalogService` / `ResolvedCatalogService` | static catalog: cards, banners, fixtures, nations |
| `WalletService` | yes (`@MainActor`) | `SwiftDataWalletService` | `Wallet` balances + per-banner `BannerPity` |
| `CollectionService` | yes (`@MainActor`) | `SwiftDataCollectionService` | owned `CardInstance`s; acquire / train / limit-break |
| `GachaService` | yes (`@MainActor`) | `DefaultGachaService` | wraps `GachaEngine` + wallet + collection + pity |
| `LiveMatchService` | yes | `MockLiveMatchService` | `play(fixture)` → `AsyncStream<MatchTick>` clock (legacy; futsal uses `FutsalEngine` directly) |
| `MatchSlateService` | class (`@Observable`) | — | owns the generated slate; refresh-for-Gems |
| `MatchProgressStore` | yes (`@MainActor`) | `SwiftDataMatchStore` | persist match entries/results (`MatchRecord`) |
| `TransferMarketService` | class (`@Observable`) | — | daily transfer shortlist; sign for Cash |
| `EnergyService` | yes (`@MainActor`) | `DefaultEnergyService` | regen-on-read, drain post-match, Gem refill |
| `MilestoneService` | yes (`@MainActor`) | `DefaultMilestoneService` | grant career-point milestones |
| `ExchangeService` | yes (`@MainActor`) | `DefaultExchangeService` | Rep → Scouts/Gems |
| `RewardsService` | yes (`@MainActor`) | `DefaultRewardsService` | daily drop |
| `LeaderboardService` | yes (`@MainActor`) | `MockLeaderboardService` / `FirestoreLeaderboardService` | agency ranking (shared via Firestore) |
| `ScoreBoard` | class (`@Observable`) | SwiftData `LiveProgress` (+ optional Firestore write-through) | live points/Rep/daily/milestone/slate meta |
| `AuthService` | yes (`@MainActor`) | `FirebaseAuthService` / `MockAuthService` | anonymous sign-in + optional Apple ID linking → Firebase session; exposes `isAnonymous`, `signInAnonymously()`, `linkApple(...)` |

## Firebase backend (branch `feat/firebase-backend`, merged to `main`)

Server-authoritative backend behind the existing protocols — no ViewModel/View churn. Firebase is quarantined in `Services/Auth` + `Services/Firestore`. See the spec + per-phase plans under `docs/superpowers/`.

- **Auth (P0 — anonymous-first):** On launch `RootView` calls `signInAnonymously()` via `AuthService` (zero-friction; no SIWA wall). If offline, `uid` is nil and the app runs with local-only services, retrying anon sign-in later. `FirebaseApp.configure()` runs at launch *only if* `GoogleService-Info.plist` is bundled (gitignored; injected in CI). `RootView` rebuilds the uid-keyed `AppContainer` via `.onChange(of: auth.currentUser?.uid)` whenever the account changes (cross-account container leak fixed). Optional Apple ID linking surfaces on the **Agencies** screen ("Guest agency" label + Link Apple ID button when anonymous; "Linked · name" when linked) and via a **one-time soft prompt** at the first career milestone (`LinkPromptPolicy.shouldPrompt(...)` — pure, tested). `linkApple(...)` upgrades the anon account (same uid, data preserved) or switches to the existing Apple account (uid changes, container rebuilds). `SignInView` removed.
- **Cloud save (P1):** `FirestoreWalletService` / `FirestoreCollectionService` **decorators** wrap the SwiftData impls — reads hit the local cache; mutations write through to Firestore async; `hydrate()` on login (cloud wins, seed-if-absent). Same pattern for progress via the cloud-aware `ScoreBoard` (P4).
- **Leaderboard (P2):** `FirestoreLeaderboardService` publishes `leaderboard/{uid}`, fetches top-N, merges a cosmetic rival floor + the live user entry via the pure `Leaderboard.dedupedRanked`.
- **Shared slate (P4):** `DeviceSeed.sharedSeed(for:)` (no device base) → all players share fixtures per time block.
- **Composition:** `AppContainer.bootstrap(context:uid:userName:loader:)` builds the Firestore-backed services + hydrates only when signed in; signed-out (previews/tests) uses the local/mock services. `FirestoreClient` (`@MainActor`) is the single DB entry point; `CloudDTOs` are the Codable wire types. Firestore types are non-`Sendable` → confined to `@MainActor`.
- **Rules:** `firestore.rules` — `users/{uid}/**` owner-only, `leaderboard/{uid}` read-all/owner-write, `catalog/{document=**}` world-readable. `storage.rules` — `players/{file}` world-readable, no client writes. Publish in the console after changes.
- **Parked/deferred:** P5 server gacha (needs Cloud Functions/Blaze — not on free tier). Monetization decided = StoreKit-only. See ROADMAP.

## SwiftData (`AppContainer.schema`)

`Wallet`, `CardInstance`, `BannerPity`, `LiveProgress`, `MatchRecord`.
**Add a model → add it here** or it won't persist. When signed in these mirror to Firestore (`users/{uid}/state/wallet`, `…/collection/{cardID}`, `…/pity/{bannerID}`, `…/state/progress`); `MatchRecord` is not cloud-saved yet (deferred). `Lineup` was **removed** — per-match selection replaces the persistent XI.

- `Wallet` — currency balances (single row).
- `CardInstance` — owned card: `cardID` (unique), `level`, `stars`, `xp`, `copies`, `dateAcquired`, **`energy`** (0–100), **`lastEnergyUpdate`**.
- `BannerPity` — per-banner `pullsSinceIcon` + `guaranteeFeatured`.
- `LiveProgress` — meta singleton: `points`, `formTokensEarned`, `lastDailyClaim`, `milestonesClaimed`, `slateBlock`, `slateRefreshCount`.
- `MatchRecord` — per `(slateID, fixtureID)`: status/points/form/score/bonus.

## Futsal tactics engine

Pure domain layer added in `feat/futsal-tactics-match`, all under `Domain/`.

**New types** (`Domain/Models/`):
- `PlayStyle` — `pace | physical | technical`; derived from a `CardInstance`'s dominant stat. Drives a RPS shooting edge (pace > physical > technical > pace).
- `Intensity` / `Focus` / `Tactics` (`Tactics.swift`) — pre-game knobs. `Intensity` (Conservative/Balanced/Aggressive) scales chance creation and energy drain. `Focus` (Defend/Balanced/Attack) tilts goals for/against.
- `MatchPlayer`, `MatchSide`, `PossessionEvent`, `PlayerContribution`, `MatchResult` (`MatchTypes.swift`) — engine I/O types.
- `OffPosition` (`FutsalMatchSupport.swift`) — marks a player in a slot outside his natural position; stats are halved before the engine sees them.

**Engine** (`Domain/Economy/`):
- `FutsalEngine.play(home:away:seed:) -> MatchResult` — pure, deterministic. Runs `FutsalRules.possessionCount` (14) alternating possessions. Each possession: midfield tug-of-war → chance creation (blends Focus + Intensity both sides) → shot (shooting vs GK defending, with `PlayStyle` RPS edge) → `PossessionEvent`.
- `OpponentGenerator` — builds a deterministic AI `MatchSide` (away-nation-preferred + global backfill from catalog).
- `MatchSideAssembly` + `FutsalReward` (`FutsalMatchSupport.swift`) — map `MatchResult` to currency deltas (cash = commission via `AgentRules`, Rep, win bonus; captain ×2 via `LiveRules.captainMultiplier`).

**Economy constants** (all in `Economy.swift`):
- `FutsalRules` — `possessionCount`, chance-creation weights, shot-resolution coefficients.
- `EnergyRules` — `baseDrain`, `captainExtraDrain`, `drainFactor(intensity:)`, `regenPerHour`, `applyPenalty(energy:stats:)`, `refillCost`.
- `LiveRules.captainMultiplier` — moved here from the removed `LineupRules`.

**LiveMatches feature** (`Features/LiveMatches/`):
- `TacticsMatchViewModel` — `@MainActor @Observable`; drives the Match Setup → sim → rewards flow.
- `TacticsMatchView` — Match Setup (positional field, roster strip, Intensity/Focus pickers, entry fee button).
- `FutsalPitchView` — watch view: horizontal pitch, round card-portrait players by role, animated ball, scoreline + clock, event feed.

**Energy** (`Services/EnergyService.swift`): regen-on-read (computes elapsed hours × `regenPerHour`), drain post-match, Gem refill. `CardInstance` gains `energy` + `lastEnergyUpdate` SwiftData fields.

**Removed**: `LineupService`, `SwiftDataLineupService`, `Lineup` @Model, `LineupSheet`, `LineupServiceTests`. `captainMultiplier` moved from `LineupRules` to `LiveRules`.

## Determinism & generation

Everything "random but stable" is seeded:
- `RandomProvider` (protocol) — `SeededRandomProvider` (SplitMix64) for tests/generation, `SystemRandomProvider` for production gacha, plus `ScriptedRandomProvider` for exact-sequence tests.
- FNV-1a hashes turn ids/strings into seeds (`NameGenerator`, `DeviceSeed`, `WC.spectrumColor`).
- `FixtureGenerator.slate(seed:nations:cards:)` — pure procedural fixtures.
- `DeviceSeed` — `identifierForVendor` (UDID-equivalent) ⊕ an 8-hour time block ⊕ refresh counter.
- `LinkPromptPolicy.shouldPrompt(isAnonymous:didPrompt:milestonesReached:)` — pure, tested; decides when to show the one-time Apple ID link soft-prompt.

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

**91 tests**, all on the **pure** layer (economy/generation + futsal engine + energy + cloud mapping + auth nonce):
`GachaEngineTests` (odds over 300k N, soft/hard pity, 50/50, counter resets),
`UpgradeRulesTests`, `LeaderboardTests` (ranking + `dedupedRanked` merge), `FictionalizerTests` (names stay fictional),
`NameGeneratorTests`, `EconomyTests` (milestones, exchange, refresh, commission, transfer pricing),
`FixtureGeneratorTests` (determinism, valid refs),
`PlayStyleTests` (RPS edge matrix), `TacticsTests` (Intensity/Focus value mapping),
`MatchTypesTests` (MatchResult structure), `FutsalEngineTests` (determinism, score range, possession count),
`OpponentGeneratorTests` (nation preference, backfill), `FutsalMatchSupportTests` (MatchSideAssembly, OffPosition penalty, FutsalReward),
`EnergyRulesTests` (drain, regen, penalty curve, refill cost),
`NonceTests` (Sign in with Apple nonce), `CloudDTOTests` (wallet/card/pity/progress DTO round-trips),
`DeviceSeedTests` (shared slate seed is device-independent), `LinkPromptPolicyTests` (prompt-once gate logic).
`LineupServiceTests` removed (service removed). No view/navigation/Firebase-wiring tests by design. (Run on `iPhone 16` — the `iPhone 15` sim is gone on current Xcode.)
