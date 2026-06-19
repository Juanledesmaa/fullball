# Gameplay & Economy

How Fullball plays, and every number behind it. Constants are cited with their
file so future tuning is a one-line change.

## The fantasy

You're a **football agent / representante**. You don't "collect cards" — you
**sign clients** to your agency and earn a **commission** when they perform.
Two ways to sign:

- **Scout** (Scout tab) — open packs. Cheap, **random** (gacha). You don't know who you'll get.
- **Transfer Market** (Market tab) — pay **Cash** to sign a **specific** marquee client outright. Expensive, **certain**.

Then you **field** clients in live matches; the better they do, the more they
earn you. Reinvest in bigger clients and climb the **Agency** ranks.

## Core loop

```
sign (Scout/Market)  →  set lineup + tactics (Live)  →  watch futsal sim  →  earn Cash + Rep + points
        ↑                                                                              │
        └──────────────────  reinvest (Market / Scout / Rep Exchange)  ←──────────────┘
```

## Currencies

`Currency` enum ([Currency.swift](../Fullball/Domain/Models/Currency.swift)) — internal case names in parens.

| Currency (case) | In-game name | Earned from | Spent on |
|---|---|---|---|
| `coins` | **Cash** | live commission (`AgentRules.cashPerPoint`), Daily Drop | transfer signings, training (level-up), match entry fee |
| `gems` | **Gems** (premium) | matchday milestones, Rep Exchange; "buy" button is a **stub** | 10-pulls, slate refresh, energy refill |
| `tickets` | **Scouts** | Daily Drop, Rep Exchange, match win bonus, milestones | single pulls |
| `formTokens` | **Rep** | live matches (fielded clients only) | Rep Exchange → Scouts/Gems |

Starter wallet ([Wallet.starter](../Fullball/Domain/Models/Wallet.swift)): **2500 Cash, 1600 Gems, 10 Scouts, 0 Rep**.

## Acquisition

### Scout (gacha) — `GachaEngine` + `DefaultGachaService`
Per-pull rarity odds (disclosed in the in-app Odds sheet; `Rarity.baseOdds`):

| Rarity | Odds  | Star cap |
|---|---|---|
| Bronze | 70.0% | 3 |
| Silver | 22.0% | 4 |
| Gold   | 7.3%  | 5 |
| Icon   | 0.7%  | 5 |

- Cards have **authored short names**: mononym for regulars (e.g. "Kaelan"), mononym + " — epithet" for icons (e.g. "Vasco — The Wall"). `NameGenerator` is a fallback for any card without an authored name.
- **Soft pity**: from pull **40** (`softPityStart`), Icon odds ramp up each pull.
- **Hard pity**: pull **50** (`hardPity`) guarantees an Icon; counter resets on any Icon.
- **50/50**: first guaranteed Icon may be off-banner; if so the *next* guaranteed Icon is the featured one. State persists per banner (`BannerPity`).
- RNG is injected (`RandomProvider`) so it's deterministic in tests. Engine is pure; the service debits the wallet and persists.
- Banners: one **standard** + one **featured** ("Today's Match", rate-up `ARG-10` & `FRA-10`). Single pull = 1 Scout; 10-pull = 1500 Gems (`banners.json`).
- Duplicates → `+1 copy` (limit-break fuel), not a new card.

### Transfer Market — `TransferMarketService`
- A deterministic daily shortlist (seeded by device + day) of specific high-rarity clients (2 Icon, 2 Gold, 2 Silver, 1 Bronze).
- Price (`TransferRules.price`): base by rarity (`Icon 6000 · Gold 1200 · Silver 500 · Bronze 200`) `+ overall × 40`.
- **Sign** debits Cash, adds the client to your roster, removes the listing. Re-signing an owned client adds a copy.
- Listings are in-session (regenerate per day); purchases persist (the client is in your roster).

## Upgrades — `UpgradeRules` + `SwiftDataCollectionService`
On Card Detail:
- **Train** (level up): spend `trainCoinCost = 50 × level` Cash → `+60 XP` (`xpPerTrain`). XP rolls levels: `xpToNext(level) = 100 + (level-1)×50`. Level cap = `10 + stars×10`.
- **Limit Break**: consume duplicate **copies** (`copiesForStar(n) = n`) → `+1 star` (raises level cap by 10, `+2` to every stat per star). Capped at the rarity's `starCap`.
- Effective stats = base `+ (level-1)×1 + stars×2`.

## Live matches — futsal tactics match
`TacticsMatchViewModel` + `FutsalEngine` + `MatchSlateService`.

The Live tab is **active-only** — there is no persistent "Matchday XI". Each match is a fresh selection.

### Match Setup
- Tap **PLAY** on any fixture from the shared slate → **Match Setup** screen.
- **Positional field** (5-a-side, formation 1-2-1): five slots — GK, DEF, MID, MID, FWD. Drag players from the roster strip at the bottom into slots. A player fielded **off his natural position** plays at **0.5× effective stats** (`OffPosition`). Energy bars are visible on the strip.
- **Auto-fill** button (squad header): one tap picks the strongest squad via `SquadAutoFill` — best natural-position fit per slot, backfilling empty slots with the best remaining card (off-position) — and captains the highest-rated pick.
- **Captain** is the first player you slot; captain earns **×2** rewards (`LiveRules.captainMultiplier`).
- **Intensity** (Conservative / Balanced / Aggressive) — controls pace of play: aggressive creates more chances but drains energy faster (`EnergyRules.drainFactor`).
- **Focus** (Defend / Balanced / Attack) — tilts goals for AND against. Both sides' Focus and Intensity are fed into the engine.
- Marking, counter-pick, and formation RPS were prototyped and **removed** for clarity.
- **Win-odds bar**: a live progress bar shows the estimated chance your side wins, recomputed as you slot players or change Intensity/Focus. It's a Monte-Carlo estimate (`FutsalOdds.winProbability` runs the pure engine `FutsalRules.oddsSamples` (200) times over varied seeds) — separate from the single fixed-seed actual match, so it informs without spoiling the result. Futsal is draw-heavy, so draws fold as **half a win** (an even contest reads ~50%); an empty side is `0`.
- Pay **200 Cash** entry fee (`LiveRules.entryFeeCoins`), then the sim begins.

### The sim
- **Horizontal pitch view** (`FutsalPitchView`): round card-portrait players positioned by role (GK back → FWD forward); animated ball; centered scoreline + match clock.
- **Running event feed** below the pitch (goals, saves, near-misses).
- **Deterministic** (`FutsalEngine.play(home:away:seed:) -> MatchResult`): `FutsalRules.possessionCount` (14) alternating possessions. Chance creation blends midfield strength + Focus + Intensity of both sides. Midfield strength is normalized to a **full** outfield (`FutsalRules.fullOutfieldCount`), so fielding more players is **always additive** — an undermanned side is genuinely weaker, and adding even a weak player only adds chances + tightens defense (never dilutes via an average). Shot resolution: your **best finisher** takes each chance (so bench depth never steals a shot from your star), shooting vs GK defending + a **player-style RPS edge** (`PlayStyle`: pace > physical > technical, derived from a player's dominant stat). The engine is pure and fully tested.
- **AI opponents** generated deterministically by `OpponentGenerator` (away-nation-preferred + global backfill). Their stats are boosted by `FutsalRules.opponentStrengthMultiplier` (1.05, clamped to 99) — a mild edge so a best-XI side sits roughly even and weaker/undermanned squads are underdogs (raise toward 1.18 for harder, 1.0 for even-OVR).

### Rewards
- **Cash commission** = `AgentRules.cashPerPoint × points`, captain ×2 (`FutsalReward`).
- **Rep** earned per fielded client.
- **Win bonus**: +1 Scout if your side wins.
- **Energy drain**: each fielded client loses energy post-match (base 20, captain +10, scaled by Intensity `drainFactor`).

### Procedural slate + persistence
`FixtureGenerator` + `DeviceSeed.sharedSeed` (time-block only, no device component) — all players share the same fixtures per 8-hour block. A Gem refresh regenerates a personal slate now (`RefreshRules`, escalating `150 × (n+1)`). `MatchRecord`/`MatchProgressStore` persist results across relaunch.

## Energy system
Every `CardInstance` has `energy` (0–100) and `lastEnergyUpdate`.

- **Drain**: fielding in a match drains energy post-match. Base: 20, captain: +10 extra, then scaled by Intensity `drainFactor` (`EnergyRules`).
- **Penalty**: players below **50** energy receive a scaling stat penalty applied by `EnergyRules.applyPenalty` before the engine sees their stats.
- **Regen**: ~**4 energy per hour** passively (checked on-read by `EnergyService`). Full recovery ≈ 24 hours.
- **Gem refill**: tap the refill button on Card Detail to restore to 100 instantly (`EnergyRules.refillCost` Gems, via `EnergyService.refill`).
- Energy bars appear on Roster grid tiles and on the Match Setup roster strip.

## Progression & meta

- **Matchday milestones** (`Milestones`): career-point thresholds auto-grant Gems + Scouts, once each. Tiers: `500→150◆/1🎟 · 1500→300/2 · 3000→500/3 · 5000→800/4 · 8000→1200/5`. The Live hero shows a "NEXT REWARD" progress bar + a toast on unlock.
- **Daily Drop** (`RewardsService`): once/day, **+600 Cash, +3 Scouts** (resets on calendar day).
- **Rep Exchange** (`ExchangeService` / `ExchangeRates`): trade live-earned Rep for pulls — `8 Rep → 1 Scout`, `40 Rep → 250 Gems`. This is what lets live play fund more signings.
- **Agencies (leaderboard)**: local mock (`MockLeaderboardService`) ranking fixed rival agencies + you by points; you're highlighted.
- **Roster (collection)**: `LazyVGrid` of owned clients, filter by rarity/position. Header shows **squad rating** (avg effective OVR of best 11) + **DEX completion** (owned/total, multicolor bar).
- **Onboarding**: one-time `Sign → Play → Profit` intro (`@AppStorage("didSeeIntro")`).

## Tuning quick-reference

| Want to change | Where |
|---|---|
| Pull odds, star caps | `Rarity` ([Rarity.swift](../Fullball/Domain/Models/Rarity.swift)) |
| Soft/hard pity, 50/50 | `GachaEngine` |
| Level/XP/limit-break math | `UpgradeRules` |
| Starter wallet | `Wallet.starter` |
| Cash commission rate | `AgentRules.cashPerPoint` |
| Transfer prices | `TransferRules.price` |
| Match entry fee, win bonus, captain multiplier | `LiveRules` |
| Futsal possession count, chance weights | `FutsalRules` |
| Energy drain, regen rate, refill cost, stat penalty | `EnergyRules` |
| Slate refresh cost | `RefreshRules` |
| Milestone tiers | `Milestones.tiers` |
| Rep exchange rates | `ExchangeRates` |
| Daily drop | `RewardsService.dailyReward` |
| Slate cadence | `DeviceSeed.hoursPerBlock` |
| Player images | Firebase Storage `players/{id}.jpg` (via `PlayerImageStore`) |
| Global stat squish (compress all player stats) | `StatSquish` (`anchor`/`factor`) |
| AI opponent difficulty | `FutsalRules.opponentStrengthMultiplier` |

> Balance note: cheapest transfer (~4,240 Cash) currently > starter Cash (2,500), so early signings require a couple of matches' commission. Intentional, but easy to soften (lower `TransferRules` bases or raise starter Cash).
