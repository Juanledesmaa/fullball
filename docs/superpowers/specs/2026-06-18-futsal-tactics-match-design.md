# Design — Futsal Tactics Match (gameplay layer)

> Status: approved (design + plan pre-approved by user). Date: 2026-06-18.
> Adds an actual gameplay/skill layer on top of the existing idle live-match loop.

## Problem

Today the loop is "open packs → field 5 → watch a 40s scripted clock → collect." Fielded
players are scattered across WC nation fixtures; scripted events randomly land on cards whose
nation is in the slate. There is **zero skill expression and no decisions** — once your XI is
set, every match is autopilot. We want a real gameplay factor that is **optional**: lean back
and auto-earn, or lean in and drive the outcome with pre-game decisions.

## North star

**Auto floor, active ceiling.** Walking away always works and pays a baseline. Engaging pays a
premium. Active play must never drop you *below* the auto baseline — engagement is a multiplier,
not a tax.

## Locked decisions (from brainstorm)

1. **No in-match interaction.** The match plays itself; the player *watches*. All skill is pre-game.
2. **Match = your 5-a-side squad vs an opponent 5.** Replaces "players scattered across nation
   fixtures." Your fielded 5 now play together as one team.
3. **Futsal 5v5** — fits the existing `maxFielded = 5`; round profiles read clean on a small pitch.
4. **Three engagement rungs:** Auto (stats only), Manager (set tactics, watch), [Hands-on B1 deferred].
5. **One active match at a time** (drop-in lens); auto matches stay concurrent in the background.
6. **Discrete possession sim (B1)** for visuals: round profiles + ball lerping between them, auto-driven.
7. **Resolution = stats-heavy + RPS player-style triangle + tactics/formation matchup + read-and-counter.**
8. **Pre-game decision layers for v1:** Formation · Mentality · Marking · Counter-pick.
9. **Per-player energy** — tired players underperform; regen over real time; Gem refill = monetization.
10. **Opponent:** AI-generated squads now (phase A); real-player squads later (phase B) — both are the target.

---

## Section 1 — Match model & flow

- A match is **your fielded 5** (with your tactics) **vs an opponent 5** (scouted, with theirs).
- **Engagement rungs**, all on one deterministic sim:
  - **Auto:** field 5, hit play, walk away. Sim resolves by stats. Baseline reward. Concurrent allowed.
  - **Manager:** set the 4 tactical layers pre-kickoff, watch playback. Better setup → better result → premium.
- **One active match at a time** — opening a match to set tactics focuses it; other entered matches keep
  auto-running concurrently (preserves today's concurrency model).
- **Watch-only playback:** a match = **~14 alternating possessions** compressed to **~35–45s** wall-clock
  (keeps current pacing, `LiveRules.realDurationSeconds`). Each possession runs the engine → maybe a shot →
  goal / save / miss. Output: a **scoreline + per-player contributions**, which drive rewards.
- **Deterministic:** same seed + same tactics ⇒ same match. Unit-testable like the economy; finalizes on
  relaunch if interrupted (reuse `MatchProgressStore`).

## Section 2 — Resolution engine (pure, deterministic, injected RNG)

New pure type `FutsalEngine` (mirrors `GachaEngine`/`FixtureGenerator`: pure, `RandomProvider`-injected,
fully unit-tested).

**Stat mapping** (existing `Stats`: pace, shooting, passing, defending; effective stats already include
level/star from `UpgradeRules`):
- **Build-up / chance creation:** attacking team `passing + pace` vs defending team `defending + pace`.
- **Shot resolution:** shooter `shooting` vs GK `defending` (+ marking). **Low shooting ⇒ more misses**
  (explicit requirement).
- **GK** uses `defending` for saves.

**Player-style RPS triangle** — style derived from a player's dominant stat:
- `passing`-dominant → **Technical**, `defending`-dominant → **Physical**, `pace`-dominant → **Pace**.
  (`shooting` is the finishing stat, not a style.)
- Triangle: **Pace > Physical > Technical > Pace.** In a duel (e.g. attacker vs their marker), a style
  advantage applies a `± styleEdge` modifier.

**Tactical modifiers** layered onto base stat probabilities:
- **Formation matchup (shape RPS):** Defensive (2-1-1) > Attacking (1-1-2) > Balanced (1-2-1) > Defensive.
  Edge = ± to chances created/conceded.
- **Mentality:** Attack↔Defend dial; Attack raises both your chances *and* theirs, Defend lowers both.
- **Marking:** your assigned marker's `defending` vs the danger man's threat stats → reduces (good fit) or
  amplifies (mismatch) the danger man's output.
- **Counter-pick:** opponent telegraphs a style; you pick a counter from 3. Correct → team-wide `+` modifier,
  wrong → small penalty, neutral → 0.

All layers compose as additive/multiplicative modifiers on base probabilities, then clamp. Constants live in
`Economy.swift` (RPS tables, style/formation edges, mentality range).

## Section 3 — Pre-game decisions (v1)

1. **Formation** — pick one of 3 shapes (Diamond 1-2-1 balanced · 2-1-1 defensive · 1-1-2 attacking). GK fixed,
   4 outfield arranged. Drives shape RPS + where chances come from.
2. **Mentality** — Attack↔Defend slider (e.g. 5 notches, value −2..+2).
3. **Marking** — assign one of your players to mark the scouted danger man.
4. **Counter-pick** — choose your answer to the opponent's telegraphed style (Pace / Possession / Physical).

Scouting strip surfaces opponent: formation, style, danger man (+key stat), telegraphed weakness — the
information the 4 decisions respond to. Tactics persist per player (extend `LineupService` / a `Tactics` model).

## Section 4 — Energy

- Each owned player has **energy 0–100**, stored on `CardInstance` (`@Model`) — **add to `AppContainer.schema`**
  (SwiftData gotcha).
- **Drain:** fielding in a match costs energy (e.g. −20; **captain −30** for the ×2 workload). Starting values tunable.
- **Penalty:** above 50 = no penalty; below 50, effective stats scale down linearly to ~−30% at 0. Tired ⇒ worse —
  reinforces "stats matter heavily."
- **Regen:** + per real minute, full recovery in ~6–8h (idle-friendly; tied to wall-clock, persisted timestamp).
- **Monetization:** **Gem refill** (instant per-player or team energy refill, escalating cost) — new premium sink
  alongside slate refresh and 10-pulls. Optional consumable "energy drink" item is a later add.
- Effect on meta: can't field your best 5 every match forever → **squad rotation → roster depth matters → more pulls.**

## Section 5 — Rewards / economy

- Keep all existing outputs: points → Cash commission (`AgentRules.commission`), Rep (`formTokens`), matchday
  milestones, win bonus (points ≥ 150 → Scout), entry fee (200 Cash).
- **Auto floor** = expected stats-only result.
- **Active premium:** good tactics → more goals / clean sheet / win → more points → more Cash & Rep *naturally*,
  **plus** an explicit capped **tactics bonus** (~×1.5 max) so reading the matchup is rewarded without breaking the
  milestone economy. All premiums are tunable constants in `Economy.swift`.
- Energy refills are a **Gem sink** (monetization), not a reward.

## Section 6 — Opponent model

- **Phase A (now): AI squad**, generated deterministically from the slate seed (like `FixtureGenerator` today):
  5 fictional catalog players + formation + mentality + a danger man (highest-threat player) + a style (for
  counter) + a telegraphed weakness. New `OpponentGenerator` (pure, tested). Surfaced on the scouting strip.
- **Phase B (later): real-player squads** from Firestore — persist each player's saved tactics + roster snapshot;
  async PvP; matchmaking by Rep/points. Layers onto the existing Firebase backend. Same engine consumes either
  opponent (AI or real) — the engine only sees "an opposing 5 + their tactics."

## Architecture, testing, phasing

**New pure/domain types** (all unit-tested, no view/wiring tests, per CLAUDE.md):
- `FutsalEngine` (resolution), `OpponentGenerator` (AI squads), `PlayStyle` enum + RPS tables,
  `Formation` enum, `Mentality`, `Tactics` struct, `MatchResult`/`PossessionEvent`, energy curve + reward premium.

**Models:** `Tactics` (persisted lineup tactics), `energy` field on `CardInstance` (+ schema), `OpponentSquad`.

**Services:** extend `LineupService` (tactics persistence); new `OpponentGenerator`, `EnergyService`; rework
`LiveMatchService` to drive `FutsalEngine` and emit an `AsyncStream` of possession events for playback;
`MatchProgressStore` persists/finalizes as today.

**Views (SwiftUI, portrait, `WC` theme):** pre-match **tactics board** (scouting strip + formation + mentality +
marking + counter-pick), **futsal playback** (round profiles + ball animation, watch-only), **result** screen.

**Constants:** all new tuning in `Economy.swift` (energy drain/regen/penalty, RPS/formation/style edges, mentality
range, reward premium, refill cost).

**Phasing:**
1. **Engine + models + tests** (pure, no UI).
2. **Opponent generator (AI) + tactics persistence + rework `LiveMatchService`** to consume the engine.
3. **Tactics board UI** (the 4 decision layers + scouting strip).
4. **Futsal playback view** (round profiles + ball).
5. **Energy system + Gem refill monetization** (schema migration, `EnergyService`, refill sink).
6. **Rewards premium tuning + milestone integration.**
7. **(Later) PvP opponent (phase B)** on Firebase.

## Out of scope (v1)

- In-match interaction / hands-on B1 controls (deferred).
- Player roles, set-piece takers, captain auras (phase-2 decision layers).
- Real IAP/StoreKit for Gem purchase (still stubbed project-wide).
- PvP backend (phase B, later).
