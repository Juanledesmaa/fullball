# Futsal Tactics Match — Phase 5A (Model/Engine Rework) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Simplify the tactics model to **two clear knobs** — `Intensity` (Conservative/Balanced/Aggressive) and `Focus` (Attack/Balanced/Defend) — and rework `FutsalEngine` to use them. Remove the confusing layers (formation RPS, man-marking, counter-pick). Aggressive intensity tires players more (intensity-scaled energy drain). Energy regen → ~4/hour. Keep the automatic player-style edge (invisible depth). Pure logic, TDD.

**Architecture:** `Tactics` becomes `{ intensity: Intensity, focus: Focus }`. `MatchSide` drops `teamStyle`/`dangerManID` (only `players`, `tactics`, `captainID` remain). `FutsalEngine.chanceProbability` = base + stat diff + focus(both sides) + intensity(both sides); `goalProbability` = base + (shooting − GK defending) + style-edge vs GK. `EnergyRules.afterMatch` gains an `intensity` factor; `regenPerMinute` → 4/60. Delete `Formation`/`Mentality`. Update all affected tests.

**Tech:** Swift 6, Swift Testing. Sim by UDID. Test: `xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`. `xcodegen generate` after add/remove.

> NOTE: this rewrites code the UI (P2–P4) consumes. Some app-target files (`OpponentGenerator`, `MatchSideAssembly`, `TacticsMatchViewModel`, `TacticsMatchView`, `FutsalPitchView`) reference the old `Tactics`/`MatchSide` shape and WILL fail to build mid-rework. Each task keeps the **test target** green; the **app target** is fixed within this plan (Tasks 3 & 6) and fully built green by Task 7. Do not consider the plan done until the app builds.

---

### Task 1: Replace `Mentality`+`Formation` with `Intensity`+`Focus`

**Files:**
- Rewrite: `Fullball/Domain/Models/Tactics.swift`
- Delete: `Fullball/Domain/Models/Formation.swift`, `FullballTests/FormationTests.swift`
- Test: `FullballTests/TacticsTests.swift` (rewrite)

- [ ] **Step 1: Rewrite `Tactics.swift`** to:

```swift
import Foundation

/// Match tempo / risk. Aggressive creates more chances (both ends) and tires
/// players faster; conservative is calmer and gentler on energy.
enum Intensity: Int, Codable, Sendable, CaseIterable, Equatable {
    case conservative = -1
    case balanced = 0
    case aggressive = 1

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced:     return "Balanced"
        case .aggressive:   return "Aggressive"
        }
    }
    /// One-line, player-facing impact.
    var impact: String {
        switch self {
        case .conservative: return "Fewer chances both ways · players tire less"
        case .balanced:     return "Even tempo · normal energy use"
        case .aggressive:   return "More chances both ways · players tire faster"
        }
    }
    /// Energy-drain multiplier applied after the match.
    var drainFactor: Double {
        switch self {
        case .conservative: return 0.7
        case .balanced:     return 1.0
        case .aggressive:   return 1.4
        }
    }
}

/// Where the team tilts. Attack lifts your chances created AND conceded;
/// Defend lowers both.
enum Focus: Int, Codable, Sendable, CaseIterable, Equatable {
    case defend = -1
    case balanced = 0
    case attack = 1

    var displayName: String {
        switch self {
        case .defend:   return "Defend"
        case .balanced: return "Balanced"
        case .attack:   return "Attack"
        }
    }
    var impact: String {
        switch self {
        case .defend:   return "Fewer goals for and against"
        case .balanced: return "No tilt"
        case .attack:   return "More goals for — and against"
        }
    }
}

/// The two pre-match decisions. Pure value type.
struct Tactics: Codable, Sendable, Equatable {
    var intensity: Intensity = .balanced
    var focus: Focus = .balanced

    init(intensity: Intensity = .balanced, focus: Focus = .balanced) {
        self.intensity = intensity
        self.focus = focus
    }
}
```

- [ ] **Step 2: Delete** `Fullball/Domain/Models/Formation.swift` and `FullballTests/FormationTests.swift`:
```bash
git rm Fullball/Domain/Models/Formation.swift FullballTests/FormationTests.swift
```

- [ ] **Step 3: Rewrite `FullballTests/TacticsTests.swift`:**

```swift
import Testing
import Foundation
@testable import Fullball

struct TacticsTests {
    @Test func defaultsAreBalanced() {
        let t = Tactics()
        #expect(t.intensity == .balanced)
        #expect(t.focus == .balanced)
    }
    @Test func intensityDrainFactorOrders() {
        #expect(Intensity.conservative.drainFactor < Intensity.balanced.drainFactor)
        #expect(Intensity.balanced.drainFactor < Intensity.aggressive.drainFactor)
    }
    @Test func everyOptionHasImpactText() {
        #expect(Intensity.allCases.allSatisfy { !$0.impact.isEmpty })
        #expect(Focus.allCases.allSatisfy { !$0.impact.isEmpty })
    }
    @Test func codableRoundTrips() throws {
        let t = Tactics(intensity: .aggressive, focus: .attack)
        let back = try JSONDecoder().decode(Tactics.self, from: JSONEncoder().encode(t))
        #expect(back == t)
    }
}
```

- [ ] **Step 4:** `xcodegen generate`, run tests. The **test target won't fully compile yet** (FutsalEngine/OpponentGenerator still reference old types) — that's expected; this task's gate is that `TacticsTests` compiles against the new types. Proceed; the suite goes green at Task 7. (If you want a green checkpoint, do Tasks 1–3 then run.)

- [ ] **Step 5: Commit.**
```bash
git add -A
git commit -m "feat: simplify Tactics to Intensity + Focus; drop Formation/Mentality"
```

---

### Task 2: Rework `FutsalEngine` + slim `MatchSide`

**Files:**
- Modify: `Fullball/Domain/Models/MatchTypes.swift` (slim `MatchSide`)
- Modify: `Fullball/Domain/Economy/FutsalEngine.swift`
- Modify: `Fullball/Domain/Economy/Economy.swift` (`FutsalRules`: replace formation/counter/style-vs-marker weights with focus/intensity)
- Modify: `FullballTests/FutsalEngineTests.swift` + `FullballTests/MatchTypesTests.swift`

- [ ] **Step 1: Slim `MatchSide`** in `MatchTypes.swift` — remove `teamStyle` and `dangerManID`; keep `players`, `tactics`, `captainID` + the `goalkeeper`/`outfield`/`player(_:)` helpers:

```swift
struct MatchSide: Sendable, Equatable {
    let players: [MatchPlayer]
    let tactics: Tactics
    let captainID: String?

    var goalkeeper: MatchPlayer? { players.first { $0.position == .gk } }
    var outfield: [MatchPlayer] { players.filter { $0.position != .gk } }
    func player(_ id: String?) -> MatchPlayer? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
}
```

- [ ] **Step 2: Update `FutsalRules`** in `Economy.swift` — replace the chance-creation/​shot weight set with:

```swift
enum FutsalRules {
    static let possessionCount = 14

    // Chance creation.
    static let baseChance = 0.45
    static let strengthWeight = 0.004     // per point of midfield diff ((passing+pace)/2, atk - def)
    static let focusWeight = 0.06         // per focus step, summed across both sides (attack opens both ends)
    static let intensityWeight = 0.05     // per intensity step, summed across both sides (more tempo = more chances)
    static let chanceFloor = 0.05, chanceCeil = 0.90

    // Shot resolution.
    static let baseGoal = 0.30
    static let shotWeight = 0.004         // per point of (shooting - GK defending)
    static let styleEdgeWeight = 0.03     // shooter style vs GK style (automatic depth)
    static let saveBand = 0.30
    static let goalFloor = 0.03, goalCeil = 0.90

    static let maxTacticsBonus = 1.5
}
```
(Delete the removed constants: `formationEdgeWeight`, `mentalityWeight`, `counterEdgeWeight`, `markWeight`.)

- [ ] **Step 3: Rework `FutsalEngine.swift`** — `chanceProbability` and `goalProbability`:

```swift
    static func chanceProbability(atk: MatchSide, def: MatchSide) -> Double {
        let atkMid = midfieldStrength(atk), defMid = midfieldStrength(def)
        let focus = atk.tactics.focus.rawValue + def.tactics.focus.rawValue
        let intensity = atk.tactics.intensity.rawValue + def.tactics.intensity.rawValue
        let p = FutsalRules.baseChance
            + FutsalRules.strengthWeight * (atkMid - defMid)
            + FutsalRules.focusWeight * Double(focus)
            + FutsalRules.intensityWeight * Double(intensity)
        return min(FutsalRules.chanceCeil, max(FutsalRules.chanceFloor, p))
    }

    static func goalProbability(shooter: MatchPlayer, atk: MatchSide, def: MatchSide) -> Double {
        let gkDef = def.goalkeeper?.stats.defending ?? 50
        let gkStyle = def.goalkeeper?.style ?? .physical
        let styleEdge = shooter.style.edge(against: gkStyle)
        let p = FutsalRules.baseGoal
            + FutsalRules.shotWeight * (Double(shooter.stats.shooting) - Double(gkDef))
            + FutsalRules.styleEdgeWeight * Double(styleEdge)
        return min(FutsalRules.goalCeil, max(FutsalRules.goalFloor, p))
    }
```
Leave the possession loop, `midfieldStrength`, `weightedPick`, points tally, and the empty-outfield guard unchanged. Remove `counterEdge(...)` (now unused).

- [ ] **Step 4: Update `MatchTypesTests.swift`** — the `matchSideExposesGoalkeeperAndOutfield` test constructs `MatchSide(... teamStyle:..., dangerManID:..., captainID:...)`. Change it to the new initializer `MatchSide(players:, tactics:, captainID:)`. Keep the GK/outfield assertions.

- [ ] **Step 5: Update `FutsalEngineTests.swift`** — its `side(prefix:base:tactics:style:)` helper builds `MatchSide(... teamStyle: style, dangerManID:..., captainID:...)`. Rewrite the helper to the new shape and drop the `style:` param:

```swift
    static func side(prefix: String, base: Int, tactics: Tactics = Tactics()) -> MatchSide {
        let s = Stats(pace: base, shooting: base, passing: base, defending: base)
        let players = [
            mp("\(prefix)gk", .gk, s), mp("\(prefix)d", .def, s),
            mp("\(prefix)m", .mid, s), mp("\(prefix)f1", .fwd, s),
            mp("\(prefix)f2", .fwd, s),
        ]
        return MatchSide(players: players, tactics: tactics, captainID: "\(prefix)f1")
    }
```
Then REMOVE the now-obsolete tests `correctCounterBeatsWrongCounter`, `markingTheDangerManReducesTheirGoals`, and `favorableFormationOutscoresUnfavorable` (those mechanics are gone). KEEP `sameSeedIsDeterministic`, `differentSeedCanDiffer`, `eventsAreOrderedAndReferenceRealPlayers`, `goalsEqualCountedGoalEvents`, `strongerTeamOutscoresOverManySeeds`, `poorShootersConvertLessThanGoodShooters`, and `attackingMentalityProducesMoreGoalsThanParkingTheBus` — but rewrite that last one for the new model:

```swift
    @Test func aggressiveAttackProducesMoreGoalsThanConservativeDefend() {
        func both(_ t: Tactics) -> (MatchSide, MatchSide) {
            (Self.side(prefix: "h", base: 60, tactics: t), Self.side(prefix: "a", base: 60, tactics: t))
        }
        var openGoals = 0, closedGoals = 0
        for seed in UInt64(0)..<60 {
            let (ho, ao) = both(Tactics(intensity: .aggressive, focus: .attack))
            let o = FutsalEngine.play(home: ho, away: ao, seed: seed); openGoals += o.homeGoals + o.awayGoals
            let (hc, ac) = both(Tactics(intensity: .conservative, focus: .defend))
            let c = FutsalEngine.play(home: hc, away: ac, seed: seed); closedGoals += c.homeGoals + c.awayGoals
        }
        #expect(openGoals > closedGoals)
    }
```

- [ ] **Step 6:** `xcodegen generate`, run tests. Test target still won't link until Task 3 fixes OpponentGenerator/MatchSideAssembly — acceptable. (Do Tasks 2+3 back-to-back, then run for a green checkpoint.)

- [ ] **Step 7: Commit.**
```bash
git add -A
git commit -m "feat: rework FutsalEngine to Intensity+Focus; slim MatchSide"
```

---

### Task 3: Update `OpponentGenerator` + `MatchSideAssembly`

**Files:**
- Modify: `Fullball/Domain/Economy/OpponentGenerator.swift`
- Modify: `Fullball/Domain/Economy/FutsalMatchSupport.swift`
- Modify: `FullballTests/OpponentGeneratorTests.swift`, `FullballTests/FutsalMatchSupportTests.swift`

- [ ] **Step 1: `OpponentGenerator.opponent(...)`** — build the new `MatchSide` (no teamStyle/dangerManID; random Intensity+Focus tactics). Replace the tactics + return:

```swift
        let tactics = Tactics(
            intensity: Intensity.allCases[rng.nextInt(Intensity.allCases.count)],
            focus: Focus.allCases[rng.nextInt(Focus.allCases.count)])
        guard !players.isEmpty else {
            return MatchSide(players: [], tactics: tactics, captainID: nil)
        }
        let captain = players.filter { $0.position != .gk }.max { $0.stats.shooting < $1.stats.shooting } ?? players.first
        return MatchSide(players: players, tactics: tactics, captainID: captain?.id)
```
Remove `dominantStyle` if nothing else uses it — BUT `MatchSideAssembly` used it; check Step 2 first. Keep `dominantStyle` only if still referenced; otherwise delete it.

- [ ] **Step 2: `MatchSideAssembly.build(...)`** — drop teamStyle/dangerManID:

```swift
    static func build(players: [(id: String, position: Position, stats: Stats)],
                      tactics: Tactics, captainID: String?) -> MatchSide {
        let mps = players.map { MatchPlayer(id: $0.id, position: $0.position, stats: $0.stats) }
        return MatchSide(players: mps, tactics: tactics, captainID: captainID)
    }
```
Now `dominantStyle` is unused → delete it from `OpponentGenerator`.

- [ ] **Step 3: Update tests.** In `OpponentGeneratorTests`, remove `dangerManIsHighestShootingOutfielder` (no danger man now); keep determinism, five-players-one-keeper, global-fallback. In `FutsalMatchSupportTests`, rewrite `assemblyBuildsSideWithDangerManAndStyle` → `assemblyBuildsFiveWithCaptainAndTactics`:

```swift
    @Test func assemblyBuildsFiveWithCaptainAndTactics() {
        let inputs = [
            mp("gk", .gk,  Stats(pace: 40, shooting: 10, passing: 40, defending: 80)),
            mp("d",  .def, Stats(pace: 50, shooting: 20, passing: 50, defending: 70)),
            mp("m",  .mid, Stats(pace: 60, shooting: 50, passing: 90, defending: 50)),
            mp("f1", .fwd, Stats(pace: 70, shooting: 95, passing: 50, defending: 30)),
            mp("f2", .fwd, Stats(pace: 80, shooting: 70, passing: 40, defending: 30)),
        ]
        let side = MatchSideAssembly.build(players: inputs, tactics: Tactics(intensity: .aggressive), captainID: "f1")
        #expect(side.players.count == 5)
        #expect(side.captainID == "f1")
        #expect(side.tactics.intensity == .aggressive)
        #expect(side.goalkeeper?.id == "gk")
    }
```
Keep the two `FutsalReward` tests (they don't depend on the removed fields).

- [ ] **Step 4:** `xcodegen generate`, run tests → the pure suite should now compile and PASS (app target may still fail on UI — fixed in Task 6). Confirm the engine/opponent/reward/tactics/energy tests are green.

- [ ] **Step 5: Commit.**
```bash
git add -A
git commit -m "feat: update OpponentGenerator + MatchSideAssembly to slim MatchSide/new Tactics"
```

---

### Task 4: Energy — intensity-scaled drain + 4/hr regen

**Files:**
- Modify: `Fullball/Domain/Economy/Economy.swift` (`EnergyRules`)
- Modify: `FullballTests/EnergyRulesTests.swift`

- [ ] **Step 1: Update tests.** Change `regenPerMinute`-dependent test if any asserts exact regen (the existing `regenIsClampedToMax` uses large/zero minutes — still fine). Change the `afterMatch` tests to pass an intensity and add a factor test:

```swift
    @Test func drainAfterMatchSubtractsBaseAndCaptainExtra() {
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: false, intensity: .balanced) == 80)
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: true,  intensity: .balanced) == 70)
        #expect(EnergyRules.afterMatch(energy: 10,  isCaptain: true,  intensity: .balanced) == 0)
    }
    @Test func aggressiveDrainsMoreThanConservative() {
        let agg  = EnergyRules.afterMatch(energy: 100, isCaptain: false, intensity: .aggressive)
        let cons = EnergyRules.afterMatch(energy: 100, isCaptain: false, intensity: .conservative)
        #expect(agg < cons)   // less energy left after aggressive
    }
    @Test func regenApproximatelyFourPerHour() {
        // 60 minutes ≈ +4 energy.
        #expect(EnergyRules.regen(from: 0, minutesElapsed: 60) == 4)
    }
```

- [ ] **Step 2: Implement.** In `EnergyRules`: change `regenPerMinute` and make `afterMatch` take `intensity`:

```swift
    static let regenPerMinute = 4.0 / 60.0      // ~4 energy/hour → full in ~24h

    static func afterMatch(energy: Int, isCaptain: Bool, intensity: Intensity) -> Int {
        let base = Double(drainPerMatch + (isCaptain ? captainExtraDrain : 0))
        let drain = Int((base * intensity.drainFactor).rounded())
        return max(0, energy - drain)
    }
```
(`refillCost` and `applyPenalty` unchanged. Keep `drainPerMatch`/`captainExtraDrain`.)

- [ ] **Step 3:** `xcodegen generate`, run tests → PASS. (`regenApproximatelyFourPerHour`: 4.0/60*60 = 4.0 → floor 4. ✓)

- [ ] **Step 4: Commit.**
```bash
git add -A
git commit -m "feat: intensity-scaled energy drain; regen ~4/hr"
```

---

### Task 5: Update `EnergyService` drain call site

**Files:**
- Modify: `Fullball/Services/EnergyService.swift`

Build-only (compiled green by Task 7).

- [ ] **Step 1:** `EnergyService.drainAfterMatch` must pass the match intensity. Change the protocol + impl signature:

```swift
    func drainAfterMatch(fieldedIDs: [String], captainID: String?, intensity: Intensity)
```
and in `DefaultEnergyService`:
```swift
    func drainAfterMatch(fieldedIDs: [String], captainID: String?, intensity: Intensity) {
        for id in fieldedIDs {
            guard let inst = collection.instance(forCardID: id) else { continue }
            _ = current(inst)
            inst.energy = EnergyRules.afterMatch(energy: inst.energy, isCaptain: id == captainID, intensity: intensity)
            inst.lastEnergyUpdate = Date()
        }
        try? context.save()
    }
```

- [ ] **Step 2: Commit** (build verified in Task 7; the only caller is `TacticsMatchViewModel`, updated in Task 6):
```bash
git add Fullball/Services/EnergyService.swift
git commit -m "feat: EnergyService drain takes match intensity"
```

---

### Task 6: Reconcile the app-target callers (make it compile)

**Files:**
- Modify: `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`
- Modify: `Fullball/Features/LiveMatches/TacticsMatchView.swift`
- Modify: `Fullball/Features/LiveMatches/FutsalPitchView.swift`
- Possibly: `Fullball/Services/LineupService.swift` (it persisted old `Tactics(formation:mentality:markerID:counter:)`)

This task ONLY makes the app build against the new model. Full UX rework (player selection, simplified board, horizontal pitch) is Phase 5B — here, do the **minimum** so it compiles and runs.

- [ ] **Step 1: `LineupService` tactics persistence.** It stored `formationRaw/mentalityRaw/markerID/counterRaw`. The new `Tactics` is `intensity/focus`. Since Phase 5B moves to per-match selection (no persisted tactics), SIMPLIFY: change `Lineup` model fields to `var intensityRaw: Int = Intensity.balanced.rawValue` and `var focusRaw: Int = Focus.balanced.rawValue` (defaults → lightweight migration), and update `SwiftDataLineupService.tactics`/`setTactics`:
```swift
    var tactics: Tactics {
        Tactics(intensity: Intensity(rawValue: model.intensityRaw) ?? .balanced,
                focus: Focus(rawValue: model.focusRaw) ?? .balanced)
    }
    func setTactics(_ t: Tactics) {
        model.intensityRaw = t.intensity.rawValue
        model.focusRaw = t.focus.rawValue
        try? context.save()
    }
```
Remove the old four fields from `Lineup.swift`. (Read both files; update any mock conformer's `tactics`.)

- [ ] **Step 2: `TacticsMatchViewModel`** — its `settle()` calls `energy.drainAfterMatch(fieldedIDs:captainID:)`; add `intensity: tactics.intensity`. It references `opponent.dangerManID`/`teamStyle`/`opponentName`/`dangerMan` for scouting — remove `dangerMan`/danger-man helpers (gone). Keep `opponent` and `opponentName`. Ensure `buildHomeSide` still compiles (it already passes `tactics` to `MatchSideAssembly.build`).

- [ ] **Step 3: `TacticsMatchView`** — the board has formation/mentality/marker/counter pickers. For THIS task, reduce to the two new pickers minimally so it compiles (Phase 5B restyles + adds impact text + selection):
  - Formation picker → Intensity picker (`Intensity.allCases`, `\.displayName`).
  - Mentality picker → Focus picker (`Focus.allCases`, `\.displayName`).
  - DELETE the marker picker and counter picker and any `dangerMan` references in `scouting`.
  Bind to `vm.tactics.intensity` / `vm.tactics.focus`.

- [ ] **Step 4: `FutsalPitchView`** — remove any reference to removed fields (it mainly uses `vm.opponent.players`, `lastEvent`, etc.; likely already fine). Fix compile errors only.

- [ ] **Step 5:** `xcodegen generate`, build the app:
`xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`
Expected BUILD SUCCEEDED.

- [ ] **Step 6: Commit.**
```bash
git add -A
git commit -m "refactor: reconcile Live tactics UI/VM + Lineup to Intensity/Focus model"
```

---

### Task 7: Full green

- [ ] **Step 1:** `xcodegen generate`; run the full test suite → PASS (no regressions; counts shift as obsolete tests were removed and new ones added).
- [ ] **Step 2:** Build the app → BUILD SUCCEEDED.
- [ ] **Step 3: Report** test count + build result + any leftover references to `Formation`/`Mentality`/`dangerManID`/`teamStyle`/`markerID`/`counter` (grep to confirm none remain):
```bash
grep -rn "dangerManID\|teamStyle\|Mentality\|Formation\|markerID\|\.counter" Fullball | grep -v "encounter" || echo "clean"
```

---

## Self-review (author)
- Tactics simplified to Intensity+Focus with impact text — Task 1. Engine reworked, marking/counter/formation removed, style-edge-vs-GK kept — Task 2. Opponent/assembly updated — Task 3. Intensity-scaled drain + 4/hr regen — Tasks 4–5. App compiles against new model — Task 6. Whole thing green — Task 7.
- Obsolete tests explicitly removed (counter/marking/formation); new directional test (aggressive+attack > conservative+defend) added.
- Migration: `Lineup` field swap uses defaulted new props.
- Phase 5B (UI/UX: per-match selection, horizontal pitch + card images + ball animation, currency icons, roster copies, agency rename, energy text) is a SEPARATE plan built on this shape.
```
