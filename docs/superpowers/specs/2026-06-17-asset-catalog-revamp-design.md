# Asset & Catalog Revamp — Design

> Status: approved 2026-06-17. Replaces the 80 generic procedural cards with 61
> curated anime-style players (51 regular + 10 icons), authored names, a 4-tier
> rarity system, and a live-ops catalog (Firestore metadata + Firebase Storage
> images). Quality over quantity.

## Goal

Swap all player assets and identity for higher-quality, curated content, and move
the catalog to a backend so players/stats/odds/names can be retuned and new
players added **without an App Store release**.

Driver (chosen): **live-ops without app releases**. Image delivery (chosen):
**Firebase Storage + on-device cache**. This is the "asset revamp" that ROADMAP
P3 (remote catalog) was deferred to.

## Source material

- `~/Downloads/Regular_player/` — 51 PNGs (bronze→gold tiers).
- `~/Downloads/ICONS/` — 10 PNGs (icon tier).
- ~100 MB raw PNG total. Filenames encode **position role** + personality +
  appearance hints + a UUID. They do **not** encode name, rarity tier, or nation.

Parsed position coverage (→ GK/DEF/MID/FWD):

| Bucket | Regular | Icons | Total |
|--------|--------:|------:|------:|
| FWD | 28 | 10 | 38 |
| MID | 11 | 0 | 11 |
| DEF | 8 | 0 | 8 |
| GK | 4 | 0 | 4 |

## Decisions (locked)

1. **Catalog metadata** lives in Firestore, with a bundled `catalog.json`
   fallback for offline/first launch.
2. **Images** live in Firebase Storage, downloaded once and cached on disk +
   memory. Enables adding new players' art with zero app release.
3. **Names** authored per card (data field). Regulars = mononym (`Kaito`);
   icons = `mononym — epithet` (`Raiden — The Comet`). Short, anime-MC flavor.
   `NameGenerator` demoted to fallback (used only when a card has no authored name).
4. **Rarity = 4 tiers**: `bronze, silver, gold, icon` (drop `epic`).
5. **Nations = curated subset** (~12–16) with deeper rosters, not all 32.

## Architecture

Two independent layers, each behind a protocol (quarantine Firebase per CLAUDE.md
constraint #9 — never import Firebase in Views/ViewModels).

### Layer A — Catalog metadata

- Firestore: `catalog/{version}` doc holding `nations[]` + `players[]`, OR a
  `catalog_players/{id}` collection (decide in plan; single-doc is simpler to
  cache and version). Each player: `id, name, epithet?, nationTag, position,
  rarity, stats{pace,shooting,passing,defending}, imageRef`.
- `FirestoreCatalogLoader` — decorator over the bundled loader, same pattern as
  the existing `FirestoreWallet/Collection/Leaderboard` decorators. Reads remote;
  on miss/offline/error falls back to bundled `catalog.json`. Result cached
  locally (SwiftData or a cached JSON) so subsequent cold launches are instant.
- Bundled `catalog.json` is regenerated from the curation CSV (below) and shipped
  as the offline baseline. Identical schema to the Firestore payload.

### Layer B — Images

- Firebase Storage: `players/{id}.jpg`.
- `PlayerImageStore` service (protocol + Firebase impl + Mock):
  `func image(_ id: String) async -> UIImage?`. Lookup order:
  **memory (NSCache) → disk (Caches dir, `players/{id}.jpg`) → Storage download →
  cache both tiers**. Mirrors the existing `AvatarAssets` NSCache pattern but
  async + disk-backed. `@MainActor` cache per the strict-concurrency gotcha.
- `AvatarView` / `CardPortraitFull` switch from `AvatarAssets` (hash → bundled
  jpg) to `PlayerImageStore`. While loading or offline-with-empty-cache, keep the
  existing placeholder (rarity-color rectangle + `position.symbol`).
- No images bundled (Storage-only per decision). First online launch downloads;
  disk cache persists across launches. Accept that a brand-new install used
  fully offline shows placeholders until first connectivity.

## Rarity refactor (4 tiers)

- `Rarity` enum → `bronze, silver, gold, icon`. Remove `epic`.
- Odds (sum = 1.0): **bronze .70 / silver .22 / gold .073 / icon .007**.
- Star caps: bronze 3 / silver 4 / gold 5 / icon 5.
- Pity 50/50 now resolves gold ↔ icon (was epic/icon — confirm in code).
- Tier counts for the 61: icons = 10 (icon); regulars 51 ≈ bronze 24 / silver 18
  / gold 9 (tunable in CSV).
- Ripples: `Rarity.swift`, gacha weights + **Odds sheet UI** (must match disclosed
  odds), pity logic, and `GachaEngineTests` / `RarityTests` if any. Re-normalize,
  don't leave a dead `epic` case.

## Naming

- Card title = authored `name` (+ ` — epithet` for icons).
- Identity line unchanged: `nationTag #num · POS`.
- `NameGenerator.funnyName` kept only as fallback when `name` is empty.
- Keep names short (≤ ~12 chars given) so they don't overflow card tiles — the
  current `'Nickname'` triple-barrel form is removed.

## Tooling

- `tools/process_players.sh` — resize each source PNG to ~1024px tall, JPEG q0.8
  (~15 MB total), rename `<raw>` → `<cardId>.jpg`, write to a build dir, and emit
  a manifest (cardId → source filename). Re-runnable. Upload step to Storage
  (gsutil or Firebase CLI) documented; images are gitignored (large).
- `tools/player_manifest.csv` — the curation source of truth: one row per image →
  `id, sourceFile, name, epithet, nationTag, position, rarity, pace, shooting,
  passing, defending`. Positions pre-filled from filename parse; name/tier/nation/
  stats authored. A generator script turns the CSV into `catalog.json` + the
  Firestore seed payload.

## Migration & rollout

- Pre-launch (TestFlight): card ids change, so existing local collection/pity/
  lineup reference stale ids. **Reset local stores** on upgrade (one-time wipe or
  schema bump). Acceptable pre-launch; document it. Cloud docs for test accounts
  likewise reset.
- Security: `firestore.rules` + Storage rules — catalog metadata and player images
  are **world-readable, no client writes** (authored via console/CI only).
- Confirm Firebase **Storage** is enabled (Firestore already is).

## Testing (pure-logic only, per constraint #8)

- 4-tier gacha odds normalize + sum to 1.0; pity resolves correctly.
- Name resolution: authored name wins; empty → generator fallback.
- Catalog DTO ↔ domain mapping (Firestore payload → `Card`/`Player`).
- CSV → `catalog.json` generation (counts, tier distribution, no missing fields).
- No view/Storage/SwiftData-wiring tests.

## Action items (owner: user)

1. **Position skew** — 38 FWD / 11 MID / 8 DEF / 4 GK. With ~12–16 nations,
   GK/DEF are too thin for balanced squads. Generate more **GK + DEF** art, and
   ideally 1–2 **icon GK/DEF** (all 10 current icons are forwards/wingers).
2. **Choose the 12–16 nations** (or approve a set proposed from the art's hints).
3. **Review `tools/player_manifest.csv`** once drafted (names/tiers/nations/stats).
4. **Enable Firebase Storage** on the project if not already.

## Out of scope

- StoreKit IAP, push, localization (separate roadmap items).
- Server-authoritative gacha / anti-cheat (parked P5).
- Auth-invasiveness rework (separate).

## Implementation phasing (for the plan)

1. Image pipeline (`process_players.sh`) + curation CSV scaffold + position parse.
2. Catalog data model: CSV → `catalog.json`, 4-tier `Rarity`, authored names,
   `catalog.json` fallback loader. (Offline-complete milestone — verifiable.)
3. Rarity 4-tier refactor + odds + Odds sheet + tests.
4. `PlayerImageStore` (memory/disk/Storage) + `AvatarView` swap.
5. `FirestoreCatalogLoader` decorator + remote payload + rules.
6. Curation pass (author the 61 rows) + migration reset + Storage upload.
