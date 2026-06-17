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
sign (Scout/Market)  →  field your XI (Live)  →  matches run  →  earn Cash + Rep + points + Form
        ↑                                                                    │
        └──────────────  reinvest (Market / Scout / Rep Exchange)  ←─────────┘
```

## Currencies

`Currency` enum ([Currency.swift](../Fullball/Domain/Models/Currency.swift)) — internal case names in parens.

| Currency (case) | In-game name | Earned from | Spent on |
|---|---|---|---|
| `coins` | **Cash** | live commission (`AgentRules.cashPerPoint`), Daily Drop | transfer signings, training (level-up), match entry fee |
| `gems` | **Gems** (premium) | matchday milestones, Rep Exchange; "buy" button is a **stub** | 10-pulls, slate refresh |
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

## Live matches — the staked game
`LiveMatchesViewModel` + `LiveMatchService` + `MatchSlateService`.

- **Field a lineup**: up to **5** clients (`LineupService.maxFielded`); pick a **captain** (first pick auto-captains). Captain scores **×2** (`LineupRules.captainMultiplier`). Only **fielded** clients earn.
- **Enter a match**: pay **200 Cash** entry fee (`LiveRules.entryFeeCoins`). Only then are your fielded clients eligible to earn in that match. Each card shows **which of your clients play in it** (the "YOUR EARNERS" row) or "None of your clients play here".
- **Fixed duration**: a match runs a clock 0→90′ (`fullTimeMinute`) compressed into ~**40s** real time (`realDurationSeconds`), emitting scripted events as it passes their minute, then **FULL TIME**.
- **Earnings** (per fielded client event): points (×2 if captain) → matchday/career points + a **Cash commission** (`AgentRules.commission = points × 3`) + **Rep** (`formTokens`).
- **Win bonus**: if a match's points ≥ **150** (`winBonusTarget`) → **+1 Scout** (`winBonusTickets`).
- **Concurrent**: you can enter several matches at once (one task per match; feed merges).
- **Procedural + persisted slates** (`FixtureGenerator` + `DeviceSeed` + `MatchRecord`/`MatchProgressStore`): the slate (teams, stages, scripted events) is generated deterministically from an **8-hour** time block (`hoursPerBlock`). Since the Firebase backend the base slate uses `DeviceSeed.sharedSeed` (time-block only, no device component) so **all players share the same fixtures** per block — stable for hours, then refreshes. A Gem refresh stays personal (counter-mixed). Entries/results persist across relaunch; a match interrupted mid-play finalizes on next launch.
- **Refresh for Gems** (premium sink, `RefreshRules`): regenerate a fresh slate now instead of waiting for the free block. Escalating cost `150 × (n+1)` per refresh within a block; resets when the block rolls over. Gated to between-matches.

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
| Match entry fee, length, win bonus | `LiveRules` |
| Slate refresh cost | `RefreshRules` |
| Milestone tiers | `Milestones.tiers` |
| Rep exchange rates | `ExchangeRates` |
| Daily drop | `RewardsService.dailyReward` |
| Lineup size, captain multiplier | `LineupService.maxFielded`, `LineupRules.captainMultiplier` |
| Slate cadence | `DeviceSeed.hoursPerBlock` |
| Player images | Firebase Storage `players/{id}.jpg` (via `PlayerImageStore`) |

> Balance note: cheapest transfer (~4,240 Cash) currently > starter Cash (2,500), so early signings require a couple of matches' commission. Intentional, but easy to soften (lower `TransferRules` bases or raise starter Cash).
