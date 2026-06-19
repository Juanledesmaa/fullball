# Status & Roadmap

Snapshot of what's built, what's intentionally fake, the rough edges, and where
to go next. Keep this honest — it's the first thing a future session should read
to avoid re-discovering known gaps.

## ☁️ Firebase backend — branch `feat/firebase-backend` (merged to main)

Server-authoritative backend behind the existing service protocols (no ViewModel/View
churn). Spec: [`docs/superpowers/specs/2026-06-16-firebase-backend-design.md`]; per-phase
plans under `docs/superpowers/plans/`. Firebase (Auth + Firestore) is the one third-party
dep — a deliberate exception to the zero-dep constraint, quarantined in `Services/Auth` +
`Services/Firestore`. Security rules live in `firestore.rules` (publish in the console after
any phase that changes them).

**Done (build green, 108 tests):**
- **P0 — Auth foundation:** Firebase SPM, **anonymous-first auth** (`signInAnonymously()` on launch, falls back to local-only if offline), `FirestoreClient`. Optional Apple ID linking via Agencies screen + first-milestone soft prompt (`LinkPromptPolicy`). `RootView` rebuilds uid-keyed `AppContainer` on account/uid change (cross-account leak fixed). `SignInView` removed.
- **P1 — Cloud save:** wallet + collection + pity → Firestore via write-through decorators (cloud-wins hydrate on login, seed-if-absent). Verified on device.
- **P2 — Real leaderboard:** `leaderboard/{uid}` (owner-write/read-all), top-N + cosmetic rival floor, ranked.
- **P4 — Shared slate + progress:** device-independent slate seed (all players share fixtures per time block); `LiveProgress` cloud-saved via cloud-aware `ScoreBoard` (fixes the P2 points-reset-on-reinstall bug).
- **P3 — Remote catalog + asset revamp** (branch `feat/asset-catalog-revamp`, merged): `FirestoreCatalogLoader` reads `catalog/current` from Firestore with bundled `catalog.json` fallback (live-ops: retune without an app release). Catalog rebuilt: 61 curated players (51 regular + 10 icons) across 16 nations, authored in `tools/player_manifest.csv` + compiled by `tools/build_catalog.py`. 4-tier rarity (bronze/silver/gold/icon — epic dropped). Authored mononym names + icon epithets (`NameGenerator` is now a fallback). Player images from Firebase Storage `players/{id}.jpg` via `PlayerImageStore` (memory NSCache → disk → Storage); async `AvatarView` with rarity-tinted placeholder. `firestore.rules` + new `storage.rules` make `catalog/**` and `players/*` world-readable. `FirebaseStorage` added to SPM deps.
- **Futsal tactics match** (branch `feat/futsal-tactics-match`, merged): active-only Live tab — Match Setup with positional 5-a-side field (GK/DEF/MID/MID/FWD 1-2-1, drag-to-slot, off-position 0.5× penalty), Intensity + Focus pre-game knobs, deterministic `FutsalEngine` (14 possessions, PlayStyle RPS, AI opponents via `OpponentGenerator`), `FutsalPitchView` watch screen, `EnergyService` (drain/regen/Gem refill). Persistent `Lineup` XI removed; `LineupService` + `Lineup` @Model removed from schema.
- **Agency rename (Firestore-backed):** `LeaderboardService.updateName(_:userPoints:)` writes `/leaderboard/{uid}.name`; editable via pencil on the Agencies current-user row; bootstrap prefers the stored name.

**Next steps (prioritized):**
1. **StoreKit 2 IAP seam** (free, no server) — turn the Gems "buy" stub into real IAP. On-device signed-`Transaction` verification, then credit Gems. **Monetization is decided to be solely StoreKit.** This is the real next monetization step.
2. **Real PvP opponents** — replace deterministic AI opponent with a real user's squad (sampled from the shared leaderboard or a match-making pool).
3. **Deferred cloud-save:** `MatchRecord` (slate-transient) — optional; low value.
4. **P5 — Server gacha:** PARKED. Not achievable on free Spark (owner-scoped rules let a client write its own collection). The *one* server (Blaze) investment that ever makes sense is **server-side App Store receipt validation + server-authoritative wallet** — which protects real (StoreKit) revenue **and** makes gacha cheating moot as a side effect. Never build P5 standalone.

**Known limitations (current backend):** opportunistic progress sync (daily/milestone lag until next award/relaunch); leaderboard identity keyed by display-name not uid (collisions collapse rows); leaderboard points published on tab-open (slightly stale); no points anti-cheat. All documented in the phase plans.

## ✅ Done (works, offline, tested where it matters)

- **Agent framing** end to end: Scout · Market · Roster · Live · Agencies + Wallet bar (Cash/Gems/Scouts/Rep).
- **Scout (gacha)**: banners, ×1/×10, soft+hard pity, 50/50, disclosed Odds sheet, animated reveal (stagger, rarity flare, haptics), pity bar.
- **Transfer Market**: deterministic daily shortlist of specific marquee clients, Cash signings.
- **Roster (collection)**: grid, rarity/position filters, DEX completion, squad rating, portrait tiles with energy bar + ×N copies badge + sort control (Quality/Name), empty-state CTA.
- **Card Detail**: full vertical portrait hero; stats; Train (level-up); Limit Break (consume copies); Gem energy refill button.
- **Live — futsal tactics match**: Match Setup with positional 5-a-side field (drag-to-slot, off-position 0.5× penalty), Intensity + Focus knobs, pay Cash entry, deterministic futsal sim (`FutsalEngine`, 14 possessions, PlayStyle RPS), `FutsalPitchView` (horizontal pitch, card-portrait players, animated ball, scoreline, event feed), full-time rewards (Cash + Rep + win Scout bonus, captain ×2).
- **Energy system**: `CardInstance.energy` (0–100), drains per match, regens ~4/hr, Gem refill on Card Detail. Energy bars on Roster and Match Setup strip.
- **Procedural + persisted match slates** (device + 8h-block seeded; survive relaunch; refresh-for-Gems).
- **Economy closed**: live commission (Cash) + Rep, milestones (Gems/Scouts), Rep Exchange, daily drop.
- **Agencies**: Firestore-backed agency rename (pencil on current-user row); shared real leaderboard.
- **Portraits**: player images from Firebase Storage `players/{id}.jpg` via `PlayerImageStore` (memory NSCache → disk → Storage download); async `AvatarView` with rarity-tinted position-symbol placeholder; full image on Card Detail.
- **Authored player names** (anime-MC mononym; icons add " — epithet"); `NameGenerator` as fallback. **Onboarding intro**, **light/dark** theme with adaptive contrast.
- **Real nation flags**: 32 WC-nation flags bundled as vector assets (`Assets.xcassets/Flags/flag_<TAG>`, ~680 KB) from lipis/flag-icons (MIT/public-domain); `NationBadge` renders them with the old gray stand-in as fallback. Fetched offline by `tools/fetch_flags.sh` (no api-football, no key).
- **Auth (anonymous-first):** `signInAnonymously()` on launch (zero-friction, no SIWA wall); falls back to local-only if offline. Optional Apple ID linking on the Agencies screen + one-time first-milestone soft prompt (`LinkPromptPolicy`). `linkApple(...)` upgrades the anon account (same uid, data preserved) or switches to the existing Apple account. `RootView` rebuilds the uid-keyed `AppContainer` on uid change (cross-account container leak fixed). `SignInView` removed.
- **UI polish**: position pill (not shirt number) on cards; `CurrencyCost` component (icon + amount, styled like wallet bar) on all spend buttons; rarity tag no longer wraps.
- **Tooling**: XcodeGen project, `tools/player_manifest.csv` + `tools/build_catalog.py` (catalog authoring), `tools/fetch_flags.sh`, dev launch args, **108 passing tests**.

## 🟡 Stubbed / fake on purpose (MVP scope)

- **No real IAP** — the Gems "buy" button shows "coming soon". The Gem sinks (10-pulls, slate refresh, energy refill) create the *demand*; StoreKit is where real revenue would plug in. **This is the #1 thing to wire for monetization** (and needs the real 3.1.1 review path).
- **api-football loader is opt-in & off by default** — set `APIFootballKey` to enable; otherwise bundled JSON. Live/remote catalog still fictionalizes names.
- **AI opponents only** — futsal match opponents are deterministic AI (`OpponentGenerator`), not real users. Real PvP would sample live squads from the leaderboard.
- **Leaderboard rivals are a fixed floor** + real users (Firestore) — no real-time match-making.
- **No push, no localization.**

## 🔧 Known rough edges / TODO

- **Card Detail not visually verified from automation** — navigation needs a tap; computer-use screen-recording was ungranted, so the full-portrait hero was shipped on build-correctness + logic, not a screenshot. **Eyeball it on device.**
- **Transfer prices vs starter Cash**: cheapest listing (~4,240) > starter (2,500). Intended grind, but may feel gated early — tune `TransferRules` / starter Cash if so.
- **Player art style** — images now served from Firebase Storage (`players/{id}.jpg`). A new art set is a Storage-only swap; no code change needed.
- **Live-match tab-switch freeze — FIXED.** `LiveMatchesView` used to `vm.stop()` on `onDisappear`, cancelling in-flight matches on every tab switch (they only finalized on relaunch). Removed; matches now keep ticking in the background and settle. Note: a hard app-kill mid-match still relies on `restore()` finalizing on next launch (Task.sleep is suspended while backgrounded).
- **Portrait crop** — images are square-cropped server-side before Storage upload. Per-image tuning requires re-uploading. (The old bundled `avatar_NNN.jpg` set was removed — saved ~5.8 MB.)
- **Market has no gem-refresh** (unlike the match slate) — could add the same `RefreshRules`-style sink.
- **`fixtures.json` removed** — Live uses the procedural `MatchSlateService`; `CatalogService` now loads fixtures tolerantly (→ `[]` if absent) for the opt-in api-football loader.
- **api-football key**: a real key was shared in chat during development — **rotate it** before any production use; it is NOT stored in the repo.
- **Economy/currency tuning is baked client-side — not remote-configurable, and the wallet is client-authoritative.** Only the *catalog* is remote (Firestore `catalog/current`); every balance constant (`Economy.swift` — `AgentRules`, `TransferRules`, `LiveRules`, `RefreshRules`, `Milestones`, `ExchangeRates`, `FutsalRules`, `EnergyRules` — plus `Wallet.starter` and `Rarity.baseOdds`) is a hardcoded Swift literal. Two consequences: (1) **live-ops** — no economy retune (prices, rewards, odds, milestones) without an app release; (2) **security** — the wallet is cloud-*saved* but client-*authoritative* (write-through decorators, `users/{uid}/**` owner-write rules), so a client mints its own balances; there is no server validation or anti-cheat. **Direction:** move the tunables behind a remote config doc (mirror the `catalog/current` pattern → e.g. `config/economy`), and make spend/earn server-authoritative. The latter is the same **server-side receipt validation + server-authoritative wallet** investment already flagged as the *one* sensible Blaze spend (see P5 note above) — it protects StoreKit revenue and makes balance-tampering moot in one move. Until then, treat all balances as untrusted.
- **`StatSquish` is a client-side transform — bake it at the source instead.** Stat compression (`StatSquish.apply` in `ResolvedCatalogService.init`, anchor 56 / factor 0.62) runs on-device every catalog load. Bad practice: the durable catalog (`catalog.json` + Firestore `catalog/current`) still holds the hot raw values, and every client recomputes the squish forever. **Proper fix:** apply the squish once at the data source — re-author/compress in `tools/player_manifest.csv` + `tools/build_catalog.py` (and re-seed Firestore `catalog/current` from the rebuilt JSON), then **delete the runtime transform** (`StatSquish` + its call) so the values in play equal the values stored. Until then, the two MUST NOT both apply (double-squish). Once baked, `StatSquishTests` can go too.

## 🚀 Suggested next steps (roughly prioritized)

1. **StoreKit seam for Gems** — turn the stub into a real (or sandbox) IAP; single seam behind the buy button. Unlocks monetization.
2. **Real PvP opponents** — sample a real user's squad from the Firestore leaderboard as the away side in the futsal match.
3. **"Today" home hub** — a landing tab tying live matches × your holdings × daily × next action into one glance (the biggest remaining clarity lever; the WC26 wireframe originally had a Today screen).
4. **Objectives / quests** — a rewarded checklist turning systems into next-taps ("sign a client", "field an XI", "win a match", "reach squad 80").
5. **Settings** — sound/haptics toggles, restore purchases, a place for legal/odds.
6. **Persistence polish** — persist matchday session points; consider migrating SwiftData carefully (additive fields only) as models grow.
7. **Bake stat squish at the source** — replace the on-device `StatSquish` transform by compressing the authored catalog once (`tools/build_catalog.py` + re-seed Firestore `catalog/current`), then remove the runtime transform. See rough-edges note above. Stored values should equal in-play values; clients shouldn't recompute balance on every load.
8. **Remote economy config + server-authoritative wallet** — move the `Economy.swift` tunables (prices/rewards/odds/milestones/starter) behind a remote `config/economy` doc (same async seam as the catalog) so balance is retunable without a release, and make spend/earn server-validated so clients can't mint currency. The wallet half is the StoreKit-receipt-validation Blaze investment from the P5 note — do them together. See rough-edges note above.

## Design constraints to never violate (recap)

iPhone-only portrait · SwiftUI + `@Observable` MVVM · Swift 6 strict concurrency · iOS 17 · **no real player likeness / kits / crests** · virtual currency only · disclose gacha odds · zero third-party deps · no "Co-Authored-By" trailer in commits. Full list in [CLAUDE.md](../CLAUDE.md).
