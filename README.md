# Fullball ⚽️

A free-to-play football-**agent** game for iPhone, themed around the 2026
World Cup. You're a representative building a roster of clients: **scout**
unknown talent in packs, **sign** specific marquee clients on the transfer
market, then **field** them in live matches to earn a Cash commission on
their performance — and reinvest in bigger clients. This repo is the **MVP
vertical slice**: a complete, playable core loop, fully offline.

Core loop: **sign → field → live → earn Cash + Rep → sign bigger.** Two
acquisition paths — cheap-and-random scouting (gacha) vs paid-and-certain
transfers (`TransferMarketService`). Currencies: **Cash** (agency money, earned
as match commission, `AgentRules`), **Gems** (premium), **Scouts** (pack
passes), **Rep** (unlocks, from live play).

> No real player names, faces, kits, or club/federation marks. Every player
> is a stylized placeholder (e.g. `ARG #10`). Virtual currency only — no
> real-money wagering or IAP.

## Stack

- **Swift 6** (strict concurrency / data-race safety), **iOS 17.0+**, iPhone-only, portrait-locked.
- **SwiftUI** + `NavigationStack`. **MVVM** with the `@Observable` macro (no `ObservableObject`).
- **SwiftData** (`@Model`) for owned/mutable state; bundled JSON (`Codable`) for the static catalog.
- **Swift Testing** for the economy unit tests. **No third-party dependencies.**
- Project generated with **XcodeGen** (`project.yml`).

## Build & run

```bash
brew install xcodegen          # one-time
xcodegen generate              # produces Fullball.xcodeproj
open Fullball.xcodeproj         # ⌘R on an iPhone simulator (iOS 17+)
```

CLI build / test:

```bash
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 15'

xcodebuild test  -project Fullball.xcodeproj -scheme Fullball \
  -only-testing:FullballTests \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

> After editing `project.yml` or adding files, re-run `xcodegen generate`.

## Architecture

Strict one-way deps — **Views → ViewModels → Services → Models**.

```
Fullball/
  App/        FullballApp · AppContainer (composition root) · RootView · Theme
  Domain/
    Models/   Card, Player, Rarity, Banner, Fixture, Wallet(@Model),
              CardInstance(@Model), PityState(+BannerPity @Model), ScoreBoard…
    Economy/  GachaEngine · UpgradeRules · RandomProvider · Leaderboard  (pure, tested)
  Services/   Catalog · Wallet · Collection · Gacha · LiveMatch · Leaderboard
              (protocol-first; SwiftData / mock implementations)
  Features/   PackOpening · Collection · CardDetail · LiveMatches · Leaderboard · Wallet
              + Components/ (shared WC26 UI)
  Resources/  catalog.json · banners.json · fixtures.json · Assets.xcassets
  Mocks/      MockCatalogService + AppContainer.preview() for #Preview-driven dev
tools/        generate_catalog.py · wc_nations.json
FullballTests/  GachaEngineTests · UpgradeRulesTests · LeaderboardTests
```

The gacha/economy engine is **pure** (RNG injected via `RandomProvider`),
so odds/pity/50-50 and the upgrade math are deterministically tested.
Every screen ships a `#Preview` driven by `AppContainer.preview()` — develop
in Previews, not full rebuilds.

## Economy (closed loop)

| Currency | Earned from | Spent on |
|----------|-------------|----------|
| **Coins** | starter + Daily Drop | training (level-up) |
| **Tickets** | Daily Drop · Form Exchange · matchday milestones | single pulls |
| **Gems** | Form Exchange · matchday milestones | 10-pulls |
| **Form Tokens** | live matches (fielded players) | **Form Exchange** → Tickets/Gems |

Live play funds pulls two ways: **Form Exchange** (trade Form Tokens for
Tickets/Gems, `ExchangeRates`) and **matchday milestones** (career-point
thresholds auto-grant Gems/Tickets, `Milestones`). So the loop closes:
*pull → field → live → Form Tokens + points → more pulls.*

**Premium Gem sink — refresh matches.** The match slate refreshes free every
time block; spending Gems (`RefreshRules`, escalating 150/300/450…) regenerates
a fresh slate immediately. This is the monetization hook: it drives Gem demand
(where real IAP would plug into the stubbed buy button). Persisted via
`MatchSlateService` so the refreshed slate survives relaunch; the counter
resets when the free block rolls over.

## Gacha spec

| Rarity | Base odds | Rarity | Base odds |
|--------|-----------|--------|-----------|
| Bronze | 70%       | Epic   | 1.2%      |
| Silver | 22%       | Icon   | 0.3%      |
| Gold   | 6.5%      |        |           |

- **Soft pity** from pull 40 (Icon odds ramp upward each pull).
- **Hard pity** guarantees an Icon at pull 50; counter resets on any Icon.
- **50/50**: the first guaranteed Icon may be off-banner; if so the next
  guaranteed Icon is the featured card.

Odds + pity rules are disclosed in-app via the **Odds** sheet (Packs tab).

## Design

Visuals follow the **WC26 Wireframes** handoff: bold black + coral (`#FB4B3E`)
on warm paper, heavy display type, rounded-14 cards, pill chips, live dot,
black accent bars, plus a **WC2026 brand spectrum** (`WC.spectrum`) used for
the multicolor completion bar and accents. Light + dark mode via adaptive
asset colors. (Archivo isn't bundled; the system heavy face stands in.)

### Card portraits

Cards use a **bundled set of illustrated portraits** (`Resources/Avatars/`,
square-cropped, ~150 images, JPEG ~2.6 MB), mapped **deterministically by card
id** via `AvatarView` / `AvatarAssets` (FNV hash → index, cached in-memory).
A card always shows the same portrait. (The earlier procedural pixel/vector
avatars were removed in favour of these.)

Each card also gets a stable, fictional **funny name** (e.g. "Turbo
Nutmegger", "Mohammed 'Houdini' Studsley") generated deterministically from
its id (`NameGenerator`) — shown as the card title with the nation tag / shirt
number as the identity line. Memorable, and still no real likeness.

### Matchday lineup (the live game)

Live is a staked, fixed-duration game, not a passive feed:

- **Field a lineup** of up to 5 collected cards, pick a **captain** (2×).
- **Enter a match** by paying a Coins entry fee (`LiveRules.entryFeeCoins`).
  Only then are your fielded players eligible to earn in that match.
- Each match runs a **fixed clock** (0→90′ compressed to ~40s, `LiveMatchService.play`)
  emitting scripted events, then settles at **FULL TIME** with the points/
  Form Tokens you earned and a **win bonus** if you beat the target.
- One match at a time; the Set-Lineup sheet flags players whose nation is
  playing now. See `Services/LineupService.swift`, `Domain/Economy/Economy.swift`
  (`LiveRules`), `Features/LiveMatches/`.

**Procedural, persisted slates.** Matches aren't hardcoded — `FixtureGenerator`
deterministically builds a slate (teams, stages, scripted events) from a seed
of `identifierForVendor` + an 8-hour time block (`DeviceSeed`). So the slate is
personal and stable for a few hours, then refreshes — not pure RNG. Entries and
results persist across relaunch via the `MatchRecord` SwiftData model
(`MatchProgressStore`); a match interrupted mid-play finalizes on next launch.

### Game-loop extras

Daily Drop reward (Packs tab), squad rating + DEX completion meter
(Collection), staggered reveal with rarity flare + haptics, persisted live
score, and a first-run Collect→Compete→Climb intro. Launch args
`-startTab N`, `-seedDemo 1`, `-didSeeIntro YES` exist for UI screenshots.

## Data provenance

`Resources/*.json` is generated by `tools/generate_catalog.py`. The nation
set and stat distributions were *inspired* by api-football v3 (World Cup
2022) as structural reference only — **no real names/likenesses**. The
generator needs no API key (`tools/wc_nations.json` is checked in). Re-run:

```bash
python3 tools/generate_catalog.py
```

## Out of scope (MVP)

Evolution/ascension, skill trees, equipment, battle pass, real networking,
auth, StoreKit/IAP, push, localization. Clean protocol seams are left where
these slot in later. The "Buy Gems" button is an intentional stub.
