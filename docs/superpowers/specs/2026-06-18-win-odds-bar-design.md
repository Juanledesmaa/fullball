# Win-odds bar in Match Setup — design

## Goal

In Match Setup, show a live progress bar indicating the player's current odds of
winning the futsal match. The bar updates as players are slotted and as Intensity
and Focus change, so the player can read the effect of their choices before paying
the entry fee.

## Why this is honest (not a spoiler)

The actual match is deterministic: `FutsalEngine.play` with one fixed `seed` per
fixture. The odds bar is a **separate Monte Carlo** over many *random* seeds —
it estimates the win probability of the configured lineup/tactics without
revealing the single predetermined result.

## Architecture

One new pure unit + a cached value on the ViewModel + a view component.

### 1. `FutsalOdds` — pure, tested (`Domain/Economy/FutsalOdds.swift`)

```swift
enum FutsalOdds {
    static func winProbability(home: MatchSide, away: MatchSide,
                               samples: Int, seed: UInt64) -> Double
}
```

- Runs `FutsalEngine.play(home:away:seed: seed &+ UInt64(i))` for `i in 0..<samples`.
- Returns a win-chance in `0...1`: a win scores 1, a **draw scores ½** (futsal is
  draw-heavy, so folding draws keeps an even contest near 50% instead of reading
  punishingly low), a loss scores 0. (Updated post-tuning; was a pure win-fraction.)
- **Deterministic**: same inputs → same output (no flicker between renders).
- Empty home side → engine returns 0-0 every run → `0.0`.

New constant: `FutsalRules.oddsSamples = 200` (tunable; ±~3.5% sampling noise,
microsecond cost since each sim is 14 possessions).

### 2. `TacticsMatchViewModel` — cached recompute

- Add `private(set) var winProbability: Double = 0`.
- `private func recomputeOdds()` →
  `winProbability = FutsalOdds.winProbability(home: buildHomeSide(), away: opponent, samples: FutsalRules.oddsSamples, seed: seed)`.
- Trigger via `didSet` on `assignments` and `tactics` (both already
  `@Observable`-tracked). The Intensity/Focus pickers mutate `vm.tactics.*`
  directly; `assign`/`clearSlot` mutate `assignments`. Both paths fire `didSet`.
- **Captain ignored** for odds — captain affects rewards only, not match outcome.
- `buildHomeSide()` already folds in off-position penalty, energy penalty, and
  tactics, so odds reflect all three automatically.
- No Monte Carlo runs at SwiftUI body-evaluation time — the value is cached and
  only recomputed on the two mutation paths.

### 3. View — odds bar (`TacticsMatchView`)

- Placed between the tactics rows and the kick-off button in `setup`.
- Always visible (live from 0%).
- Filled horizontal progress bar 0–100% reading `vm.winProbability`.
- Color-coded: red `< 0.40` / amber `0.40...0.60` / green `> 0.60`.
- Label: `WIN CHANCE` + percent (e.g. `68%`) + qualitative tag
  (`Underdog` / `Even` / `Favored`).
- Colors via `WC` tokens only (no hardcoded hex).

### Data flow

```
slot player / change intensity / change focus
  → didSet (assignments | tactics)
  → recomputeOdds()
  → winProbability updates
  → bar re-renders
```

## Testing

`FutsalOddsTests` (Swift Testing, pure layer only):

- **Determinism**: identical inputs → identical probability across two calls.
- **Empty home** → `0.0`.
- **Strong home vs weak away** → `> 0.5`.
- **Range**: result always within `0.0...1.0`.

No view/navigation/wiring tests (per project convention).

## Constraints honored

iPhone portrait · SwiftUI `@Observable` MVVM · Swift 6 strict concurrency ·
iOS 17 · zero third-party deps · pure economy logic tested · no view-logic tests ·
no real player likeness (unaffected) · virtual currency only (unaffected).
