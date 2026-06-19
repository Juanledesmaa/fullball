# Futsal Tactics Match — Phase 1 (Engine Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, deterministic 5-a-side match-resolution engine and its tactics value types, fully unit-tested, with zero UI or persistence — the foundation every later phase consumes.

**Architecture:** A pure `FutsalEngine.play(home:away:seed:)` consumes two `MatchSide` values (5 players each + `Tactics`) and returns a `MatchResult` (scoreline + per-player contributions + an ordered list of possession events for later playback). Resolution is stat-driven (your real `pace/shooting/passing/defending`), modulated by a player-style RPS triangle and four tactical layers (formation, mentality, marking, counter-pick). RNG is injected via the existing `RandomProvider` so results are reproducible and testable, exactly like `GachaEngine`/`FixtureGenerator`.

**Tech Stack:** Swift 6 (strict concurrency, `Sendable` value types), Swift Testing (`import Testing`, `@Test`, `#expect`), XcodeGen. No SwiftData, no Firebase, no SwiftUI in this phase.

**Scope note:** Spec phases 2–7 (opponent generator, tactics-board UI, futsal playback view, energy wiring, rewards integration, PvP) get their own plans once this engine's contract is locked. This plan produces independently buildable + testable software.

**Conventions for every task below:**
- After creating or removing any `.swift` file, run `xcodegen generate` before building (the `.xcodeproj` is gitignored).
- Build/test sim: `iPhone 16`. Full test command:
  `xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,name=iPhone 16'`
- New source files go under `Fullball/Domain/Economy/` (pure engine) and `Fullball/Domain/Models/` (value types), matching the existing layout. New tests go under `FullballTests/`.
- Tests prefer **comparative/monotonic** assertions over magic numbers where outcomes are probabilistic (e.g. "better team scores ≥ weaker team over the same seed"), so tuning constants can change without breaking tests. Determinism and exact-value tests are used only where the contract is exact.

---

### Task 1: `PlayStyle` enum + RPS triangle

**Files:**
- Create: `Fullball/Domain/Models/PlayStyle.swift`
- Test: `FullballTests/PlayStyleTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct PlayStyleTests {
    @Test func derivesFromDominantStat() {
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 10, passing: 90, defending: 10)) == .technical)
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 10, passing: 10, defending: 90)) == .physical)
        #expect(PlayStyle.from(Stats(pace: 90, shooting: 10, passing: 10, defending: 10)) == .pace)
    }

    @Test func tiesResolveTechnicalThenPhysicalThenPace() {
        // All equal → technical wins the tie order.
        #expect(PlayStyle.from(Stats(pace: 50, shooting: 50, passing: 50, defending: 50)) == .technical)
        // passing == defending > pace → technical.
        #expect(PlayStyle.from(Stats(pace: 10, shooting: 0, passing: 50, defending: 50)) == .technical)
        // defending == pace > passing → physical.
        #expect(PlayStyle.from(Stats(pace: 50, shooting: 0, passing: 10, defending: 50)) == .physical)
    }

    @Test func rpsEdgeIsPaceBeatsPhysicalBeatsTechnicalBeatsPace() {
        #expect(PlayStyle.pace.edge(against: .physical) == 1)
        #expect(PlayStyle.physical.edge(against: .technical) == 1)
        #expect(PlayStyle.technical.edge(against: .pace) == 1)
        #expect(PlayStyle.physical.edge(against: .pace) == -1)
        #expect(PlayStyle.technical.edge(against: .technical) == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run the full test command. Expected: FAIL — `cannot find 'PlayStyle' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// A player's tactical style, derived from their dominant outfield stat.
/// Forms a rock-paper-scissors triangle used in duels and counter-picks.
enum PlayStyle: String, Codable, Sendable, CaseIterable, Equatable {
    case technical   // passing-led
    case physical    // defending-led
    case pace        // speed-led

    /// Derive from base/effective stats. Tie priority: technical > physical > pace.
    static func from(_ s: Stats) -> PlayStyle {
        if s.passing >= s.defending && s.passing >= s.pace { return .technical }
        if s.defending >= s.pace { return .physical }
        return .pace
    }

    /// RPS: pace > physical > technical > pace.
    /// +1 if `self` beats `other`, -1 if it loses, 0 if same style.
    func edge(against other: PlayStyle) -> Int {
        if self == other { return 0 }
        switch (self, other) {
        case (.pace, .physical), (.physical, .technical), (.technical, .pace): return 1
        default: return -1
        }
    }

    var displayName: String {
        switch self {
        case .technical: return "Technical"
        case .physical:  return "Physical"
        case .pace:      return "Pace"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — full test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add Fullball/Domain/Models/PlayStyle.swift FullballTests/PlayStyleTests.swift
git commit -m "feat: PlayStyle RPS triangle (engine domain)"
```

---

### Task 2: `Formation` enum + shape RPS

**Files:**
- Create: `Fullball/Domain/Models/Formation.swift`
- Test: `FullballTests/FormationTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct FormationTests {
    @Test func shapeRPSDefensiveBeatsAttackingBeatsDiamondBeatsDefensive() {
        #expect(Formation.defensive.edge(against: .attacking) == 1)
        #expect(Formation.attacking.edge(against: .diamond) == 1)
        #expect(Formation.diamond.edge(against: .defensive) == 1)
        #expect(Formation.attacking.edge(against: .defensive) == -1)
        #expect(Formation.diamond.edge(against: .diamond) == 0)
    }

    @Test func allCasesHaveDistinctDisplayNames() {
        let names = Set(Formation.allCases.map(\.displayName))
        #expect(names.count == Formation.allCases.count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `cannot find 'Formation'`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// 5-a-side shape (GK fixed + 4 outfield). Forms a shape RPS triangle.
enum Formation: String, Codable, Sendable, CaseIterable, Equatable {
    case diamond     // 1-2-1, balanced
    case defensive   // 2-1-1
    case attacking   // 1-1-2

    /// Shape RPS: defensive > attacking > diamond > defensive.
    func edge(against other: Formation) -> Int {
        if self == other { return 0 }
        switch (self, other) {
        case (.defensive, .attacking), (.attacking, .diamond), (.diamond, .defensive): return 1
        default: return -1
        }
    }

    var displayName: String {
        switch self {
        case .diamond:   return "Diamond 1-2-1"
        case .defensive: return "Defensive 2-1-1"
        case .attacking: return "Attacking 1-1-2"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add Fullball/Domain/Models/Formation.swift FullballTests/FormationTests.swift
git commit -m "feat: Formation shape RPS (engine domain)"
```

---

### Task 3: `Mentality` + `Tactics` value types

**Files:**
- Create: `Fullball/Domain/Models/Tactics.swift`
- Test: `FullballTests/TacticsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct TacticsTests {
    @Test func mentalityRawValuesSpanDefendToAttack() {
        #expect(Mentality.parkBus.rawValue == -2)
        #expect(Mentality.balanced.rawValue == 0)
        #expect(Mentality.allOut.rawValue == 2)
    }

    @Test func tacticsHasBalancedDefaults() {
        let t = Tactics()
        #expect(t.formation == .diamond)
        #expect(t.mentality == .balanced)
        #expect(t.markerID == nil)
        #expect(t.counter == nil)
    }

    @Test func tacticsIsCodableRoundTrips() throws {
        let t = Tactics(formation: .attacking, mentality: .attack, markerID: "c1", counter: .pace)
        let data = try JSONEncoder().encode(t)
        let back = try JSONDecoder().decode(Tactics.self, from: data)
        #expect(back == t)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `cannot find 'Mentality'`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Attack↔Defend dial. Raises (attack) or lowers (defend) both your chances
/// created AND chances conceded.
enum Mentality: Int, Codable, Sendable, CaseIterable, Equatable {
    case parkBus  = -2
    case defend   = -1
    case balanced =  0
    case attack   =  1
    case allOut   =  2

    var displayName: String {
        switch self {
        case .parkBus:  return "Park the Bus"
        case .defend:   return "Defend"
        case .balanced: return "Balanced"
        case .attack:   return "Attack"
        case .allOut:   return "All Out"
        }
    }
}

/// A side's pre-match decisions. Persisted later; pure value type here.
struct Tactics: Codable, Sendable, Equatable {
    var formation: Formation = .diamond
    var mentality: Mentality = .balanced
    var markerID: String? = nil     // your player assigned to mark their danger man
    var counter: PlayStyle? = nil   // your counter-pick vs the opponent's team style

    init(formation: Formation = .diamond, mentality: Mentality = .balanced,
         markerID: String? = nil, counter: PlayStyle? = nil) {
        self.formation = formation
        self.mentality = mentality
        self.markerID = markerID
        self.counter = counter
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add Fullball/Domain/Models/Tactics.swift FullballTests/TacticsTests.swift
git commit -m "feat: Mentality + Tactics value types"
```

---

### Task 4: Engine I/O types — `MatchPlayer`, `MatchSide`, `MatchResult`

**Files:**
- Create: `Fullball/Domain/Models/MatchTypes.swift`
- Test: `FullballTests/MatchTypesTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct MatchTypesTests {
    private func player(_ id: String, _ pos: Position, _ s: Stats) -> MatchPlayer {
        MatchPlayer(id: id, position: pos, stats: s)
    }

    @Test func matchPlayerStyleDerivesFromStats() {
        let p = player("a", .fwd, Stats(pace: 90, shooting: 10, passing: 10, defending: 10))
        #expect(p.style == .pace)
    }

    @Test func matchSideExposesGoalkeeperAndOutfield() {
        let players = [
            player("gk", .gk,  Stats(pace: 40, shooting: 10, passing: 40, defending: 80)),
            player("d",  .def, Stats(pace: 50, shooting: 20, passing: 50, defending: 70)),
            player("m",  .mid, Stats(pace: 60, shooting: 50, passing: 80, defending: 50)),
            player("f1", .fwd, Stats(pace: 70, shooting: 80, passing: 50, defending: 30)),
            player("f2", .fwd, Stats(pace: 80, shooting: 70, passing: 40, defending: 30)),
        ]
        let side = MatchSide(players: players, tactics: Tactics(),
                             teamStyle: .technical, dangerManID: "f1", captainID: "f1")
        #expect(side.goalkeeper?.id == "gk")
        #expect(side.outfield.map(\.id) == ["d", "m", "f1", "f2"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `cannot find 'MatchPlayer'`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// A single player as the engine sees them. `stats` are the FINAL effective
/// stats — the caller has already applied level/star (UpgradeRules) and any
/// energy penalty (EnergyRules) before handing them to the engine. The engine
/// itself is energy-agnostic and pure.
struct MatchPlayer: Sendable, Equatable, Identifiable {
    let id: String
    let position: Position
    let stats: Stats
    var style: PlayStyle { PlayStyle.from(stats) }
}

/// One team entering a match: exactly 5 players (one GK) plus their tactics
/// and the scouting facts the opposing side reacts to.
struct MatchSide: Sendable, Equatable {
    let players: [MatchPlayer]
    let tactics: Tactics
    let teamStyle: PlayStyle    // dominant style, scored by the opponent's counter-pick
    let dangerManID: String     // highest-threat player, target of opponent marking
    let captainID: String?

    var goalkeeper: MatchPlayer? { players.first { $0.position == .gk } }
    var outfield: [MatchPlayer] { players.filter { $0.position != .gk } }
    func player(_ id: String?) -> MatchPlayer? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
}

/// Per-player tallies produced by a match.
struct PlayerContribution: Sendable, Equatable, Identifiable {
    let playerID: String
    var goals = 0
    var assists = 0
    var saves = 0
    var points = 0
    var id: String { playerID }
}

/// One resolved possession, ordered, for later playback animation.
struct PossessionEvent: Sendable, Equatable, Identifiable {
    enum Outcome: String, Sendable, Equatable {
        case turnover, chanceCreated, goal, save, miss
    }
    let index: Int
    let attackingHome: Bool
    let ballPlayerID: String
    let outcome: Outcome
    let assistID: String?
    var id: Int { index }
}

/// Full deterministic result of a match.
struct MatchResult: Sendable, Equatable {
    let homeGoals: Int
    let awayGoals: Int
    let events: [PossessionEvent]
    let homeContributions: [PlayerContribution]
    let awayContributions: [PlayerContribution]
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add Fullball/Domain/Models/MatchTypes.swift FullballTests/MatchTypesTests.swift
git commit -m "feat: futsal engine I/O value types"
```

---

### Task 5: `FutsalRules` tuning constants + `EnergyRules` (pure)

**Files:**
- Modify: `Fullball/Domain/Economy/Economy.swift` (append two enums at end of file)
- Test: `FullballTests/EnergyRulesTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct EnergyRulesTests {
    @Test func fullEnergyHasNoPenalty() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        #expect(EnergyRules.applyPenalty(to: s, energy: 100) == s)
        #expect(EnergyRules.applyPenalty(to: s, energy: 50) == s) // at/above threshold = no penalty
    }

    @Test func lowEnergyScalesStatsDown() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        let tired = EnergyRules.applyPenalty(to: s, energy: 0)
        #expect(tired.shooting < s.shooting)
        #expect(tired.overall < s.overall)
        // ~30% worst-case reduction.
        #expect(tired.shooting == 56) // 80 * (1 - 0.30)
    }

    @Test func penaltyIsMonotonicInEnergy() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        let e10 = EnergyRules.applyPenalty(to: s, energy: 10).overall
        let e40 = EnergyRules.applyPenalty(to: s, energy: 40).overall
        #expect(e10 <= e40)
    }

    @Test func regenIsClampedToMax() {
        #expect(EnergyRules.regen(from: 90, minutesElapsed: 1000) == EnergyRules.maxEnergy)
        #expect(EnergyRules.regen(from: 50, minutesElapsed: 0) == 50)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `cannot find 'EnergyRules'`.

- [ ] **Step 3: Write minimal implementation** (append to `Economy.swift`)

```swift
// MARK: - Futsal engine tuning

/// All tunable constants for the 5-a-side resolution engine. Pure; the engine
/// reads these so balancing is a one-file change.
enum FutsalRules {
    static let possessionCount = 14         // alternating possessions per match

    // Chance creation (per attacking possession).
    static let baseChance = 0.45
    static let strengthWeight = 0.004       // per point of (attack - defense) midfield diff
    static let formationEdgeWeight = 0.05   // per RPS edge step
    static let mentalityWeight = 0.06       // per mentality step, attacker minus defender
    static let counterEdgeWeight = 0.04     // per counter RPS edge step
    static let chanceFloor = 0.05, chanceCeil = 0.90

    // Shot resolution (when a chance is created).
    static let baseGoal = 0.30
    static let shotWeight = 0.004           // per point of (shooting - GK defending)
    static let styleEdgeWeight = 0.03       // per shooter-vs-marker RPS edge step
    static let saveBand = 0.30              // share of non-goal outcomes that are saves vs misses
    static let goalFloor = 0.03, goalCeil = 0.90

    // Marking: a strong marker on the danger man reduces their effective shooting.
    static let markWeight = 0.20            // fraction of marker.defending subtracted

    // Reward premium (used by the rewards phase; defined here with engine tuning).
    static let maxTacticsBonus = 1.5        // cap on the active-play payout multiplier
}

/// Per-player energy: tired players underperform. Pure functions; storage and
/// Gem-refill wiring land in a later phase.
enum EnergyRules {
    static let maxEnergy = 100
    static let penaltyThreshold = 50        // at/above this, no penalty
    static let maxPenaltyFraction = 0.30    // worst-case stat reduction at 0 energy
    static let drainPerMatch = 20           // outfield drain when fielded
    static let captainExtraDrain = 10       // captain drains 30 total (×2 workload)
    static let regenPerMinute = 0.25        // ~6.7h for a full refill

    /// Linear stat scaling below the threshold; identity at/above it.
    static func applyPenalty(to s: Stats, energy: Int) -> Stats {
        guard energy < penaltyThreshold else { return s }
        let t = Double(max(0, energy)) / Double(penaltyThreshold)  // 0..1
        let factor = 1.0 - maxPenaltyFraction * (1.0 - t)          // 0.70..1.0
        func scale(_ v: Int) -> Int { Int((Double(v) * factor).rounded()) }
        return Stats(pace: scale(s.pace), shooting: scale(s.shooting),
                     passing: scale(s.passing), defending: scale(s.defending))
    }

    static func regen(from energy: Int, minutesElapsed: Double) -> Int {
        min(maxEnergy, energy + Int((regenPerMinute * minutesElapsed).rounded(.down)))
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Fullball/Domain/Economy/Economy.swift FullballTests/EnergyRulesTests.swift
git commit -m "feat: FutsalRules tuning + EnergyRules penalty/regen (pure)"
```

---

### Task 6: `FutsalEngine` — determinism + valid scoreline

**Files:**
- Create: `Fullball/Domain/Economy/FutsalEngine.swift`
- Test: `FullballTests/FutsalEngineTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Fullball

struct FutsalEngineTests {
    // Shared fixtures for engine tests.
    static func mp(_ id: String, _ pos: Position, _ s: Stats) -> MatchPlayer {
        MatchPlayer(id: id, position: pos, stats: s)
    }
    static func side(prefix: String, base: Int, tactics: Tactics = Tactics(),
                     style: PlayStyle = .technical) -> MatchSide {
        let s = Stats(pace: base, shooting: base, passing: base, defending: base)
        let players = [
            mp("\(prefix)gk", .gk,  s), mp("\(prefix)d", .def, s),
            mp("\(prefix)m", .mid, s), mp("\(prefix)f1", .fwd, s),
            mp("\(prefix)f2", .fwd, s),
        ]
        return MatchSide(players: players, tactics: tactics, teamStyle: style,
                         dangerManID: "\(prefix)f1", captainID: "\(prefix)f1")
    }

    @Test func sameSeedIsDeterministic() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r1 = FutsalEngine.play(home: h, away: a, seed: 42)
        let r2 = FutsalEngine.play(home: h, away: a, seed: 42)
        #expect(r1 == r2)
    }

    @Test func differentSeedCanDiffer() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r1 = FutsalEngine.play(home: h, away: a, seed: 1)
        let r2 = FutsalEngine.play(home: h, away: a, seed: 2)
        #expect(r1 != r2)
    }

    @Test func eventsAreOrderedAndReferenceRealPlayers() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r = FutsalEngine.play(home: h, away: a, seed: 7)
        #expect(r.events.count == FutsalRules.possessionCount)
        #expect(r.events.map(\.index) == Array(0..<FutsalRules.possessionCount))
        let ids = Set(h.players.map(\.id) + a.players.map(\.id))
        for e in r.events { #expect(ids.contains(e.ballPlayerID)) }
    }

    @Test func goalsEqualCountedGoalEvents() {
        let h = Self.side(prefix: "h", base: 60), a = Self.side(prefix: "a", base: 60)
        let r = FutsalEngine.play(home: h, away: a, seed: 11)
        let homeGoals = r.events.filter { $0.attackingHome && $0.outcome == .goal }.count
        let awayGoals = r.events.filter { !$0.attackingHome && $0.outcome == .goal }.count
        #expect(r.homeGoals == homeGoals)
        #expect(r.awayGoals == awayGoals)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL — `cannot find 'FutsalEngine'`.

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

/// Pure, deterministic 5-a-side match resolver. Alternates possessions between
/// the two sides, rolling chance-creation then shot outcomes from effective
/// stats modulated by the tactical layers. Injected RNG ⇒ reproducible.
enum FutsalEngine {

    static func play(home: MatchSide, away: MatchSide, seed: UInt64) -> MatchResult {
        var rng = SeededRandomProvider(seed: seed)
        var events: [PossessionEvent] = []
        var homeGoals = 0, awayGoals = 0
        var tally: [String: PlayerContribution] = [:]

        func bump(_ id: String, _ change: (inout PlayerContribution) -> Void) {
            var c = tally[id] ?? PlayerContribution(playerID: id)
            change(&c)
            tally[id] = c
        }

        for i in 0..<FutsalRules.possessionCount {
            let attackingHome = (i % 2 == 0)
            let atk = attackingHome ? home : away
            let def = attackingHome ? away : home

            // Ball carrier: an outfield player weighted by passing.
            let carrier = weightedPick(atk.outfield, weight: { Double($0.stats.passing) }, &rng)
                ?? atk.outfield.first!

            let pCreate = chanceProbability(atk: atk, def: def)
            if rng.nextUnit() >= pCreate {
                events.append(PossessionEvent(index: i, attackingHome: attackingHome,
                                              ballPlayerID: carrier.id, outcome: .turnover,
                                              assistID: nil))
                continue
            }

            // Shooter: outfield weighted by shooting.
            let shooter = weightedPick(atk.outfield, weight: { Double($0.stats.shooting) }, &rng)
                ?? carrier
            let assist = shooter.id == carrier.id ? nil : carrier.id

            let pGoal = goalProbability(shooter: shooter, atk: atk, def: def)
            let roll = rng.nextUnit()
            let outcome: PossessionEvent.Outcome
            if roll < pGoal {
                outcome = .goal
                if attackingHome { homeGoals += 1 } else { awayGoals += 1 }
                bump(shooter.id) { $0.goals += 1 }
                if let assist { bump(assist) { $0.assists += 1 } }
            } else if roll < pGoal + (1 - pGoal) * FutsalRules.saveBand {
                outcome = .save
                if let gk = def.goalkeeper { bump(gk.id) { $0.saves += 1 } }
            } else {
                outcome = .miss
            }
            events.append(PossessionEvent(index: i, attackingHome: attackingHome,
                                          ballPlayerID: shooter.id, outcome: outcome,
                                          assistID: assist))
        }

        // Points: goal 100, assist 40, save 20 (pre-captain; captain ×2 applied by rewards phase).
        for (id, _) in tally {
            bump(id) { $0.points = $0.goals * 100 + $0.assists * 40 + $0.saves * 20 }
        }
        let homeIDs = Set(home.players.map(\.id))
        let homeC = tally.values.filter { homeIDs.contains($0.playerID) }.sorted { $0.playerID < $1.playerID }
        let awayC = tally.values.filter { !homeIDs.contains($0.playerID) }.sorted { $0.playerID < $1.playerID }

        return MatchResult(homeGoals: homeGoals, awayGoals: awayGoals, events: events,
                           homeContributions: homeC, awayContributions: awayC)
    }

    // MARK: probability model

    static func chanceProbability(atk: MatchSide, def: MatchSide) -> Double {
        let atkMid = midfieldStrength(atk), defMid = midfieldStrength(def)
        let formation = atk.tactics.formation.edge(against: def.tactics.formation)
        let mentality = atk.tactics.mentality.rawValue - def.tactics.mentality.rawValue
        let counter = counterEdge(atk: atk, def: def)
        let p = FutsalRules.baseChance
            + FutsalRules.strengthWeight * (atkMid - defMid)
            + FutsalRules.formationEdgeWeight * Double(formation)
            + FutsalRules.mentalityWeight * Double(mentality)
            + FutsalRules.counterEdgeWeight * Double(counter)
        return min(FutsalRules.chanceCeil, max(FutsalRules.chanceFloor, p))
    }

    static func goalProbability(shooter: MatchPlayer, atk: MatchSide, def: MatchSide) -> Double {
        let gkDef = def.goalkeeper?.stats.defending ?? 50
        var shooting = Double(shooter.stats.shooting)
        // Marking: if this shooter is the attacker's danger man and the defender
        // assigned a marker, reduce effective shooting by a slice of marker.defending.
        if shooter.id == atk.dangerManID, let marker = def.player(def.tactics.markerID) {
            shooting -= FutsalRules.markWeight * Double(marker.stats.defending)
        }
        let marker = def.player(def.tactics.markerID)
        let styleEdge = shooter.style.edge(against: marker?.style ?? (def.goalkeeper?.style ?? .physical))
        let p = FutsalRules.baseGoal
            + FutsalRules.shotWeight * (shooting - Double(gkDef))
            + FutsalRules.styleEdgeWeight * Double(styleEdge)
        return min(FutsalRules.goalCeil, max(FutsalRules.goalFloor, p))
    }

    static func midfieldStrength(_ side: MatchSide) -> Double {
        let outfield = side.outfield
        guard !outfield.isEmpty else { return 0 }
        let sum = outfield.reduce(0.0) { $0 + Double($1.stats.passing + $1.stats.pace) / 2.0 }
        return sum / Double(outfield.count)
    }

    /// Your counter-pick scored against their telegraphed team style.
    static func counterEdge(atk: MatchSide, def: MatchSide) -> Int {
        guard let pick = atk.tactics.counter else { return 0 }
        return pick.edge(against: def.teamStyle)
    }

    private static func weightedPick<R: RandomProvider>(
        _ items: [MatchPlayer], weight: (MatchPlayer) -> Double, _ rng: inout R
    ) -> MatchPlayer? {
        guard !items.isEmpty else { return nil }
        let weights = items.map { max(0.0001, weight($0)) }
        let total = weights.reduce(0, +)
        var r = rng.nextUnit() * total
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return items[i] }
        }
        return items.last
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS (5 engine tests).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add Fullball/Domain/Economy/FutsalEngine.swift FullballTests/FutsalEngineTests.swift
git commit -m "feat: FutsalEngine core resolution (deterministic)"
```

---

### Task 7: Engine — stats dominate (strong team + good shooters win more)

**Files:**
- Modify: `FullballTests/FutsalEngineTests.swift` (add tests; reuse `side`/`mp` helpers)

- [ ] **Step 1: Write the failing test** (append inside `struct FutsalEngineTests`)

```swift
    @Test func strongerTeamOutscoresOverManySeeds() {
        let strong = Self.side(prefix: "h", base: 90)
        let weak   = Self.side(prefix: "a", base: 40)
        var strongGoals = 0, weakGoals = 0
        for seed in UInt64(0)..<60 {
            let r = FutsalEngine.play(home: strong, away: weak, seed: seed)
            strongGoals += r.homeGoals; weakGoals += r.awayGoals
        }
        #expect(strongGoals > weakGoals)
    }

    @Test func poorShootersConvertLessThanGoodShooters() {
        // Same everything except shooting; compare goals over many seeds.
        func teamShooting(_ shoot: Int, prefix: String) -> MatchSide {
            let s = Stats(pace: 60, shooting: shoot, passing: 60, defending: 60)
            let players = [
                Self.mp("\(prefix)gk", .gk, s), Self.mp("\(prefix)d", .def, s),
                Self.mp("\(prefix)m", .mid, s), Self.mp("\(prefix)f1", .fwd, s),
                Self.mp("\(prefix)f2", .fwd, s),
            ]
            return MatchSide(players: players, tactics: Tactics(), teamStyle: .technical,
                             dangerManID: "\(prefix)f1", captainID: nil)
        }
        let opponent = Self.side(prefix: "a", base: 60)
        var goodGoals = 0, badGoals = 0
        for seed in UInt64(0)..<60 {
            goodGoals += FutsalEngine.play(home: teamShooting(90, prefix: "g"), away: opponent, seed: seed).homeGoals
            badGoals  += FutsalEngine.play(home: teamShooting(20, prefix: "b"), away: opponent, seed: seed).homeGoals
        }
        #expect(goodGoals > badGoals)
    }
```

- [ ] **Step 2: Run test to verify it passes immediately** — these assert behavior the Task 6 engine already provides. Run the full test command. Expected: PASS. (If either fails, the probability weights in `FutsalRules` are too weak — increase `strengthWeight`/`shotWeight` until the monotonic relationship holds, then re-run.)

- [ ] **Step 3: Commit**

```bash
git add FullballTests/FutsalEngineTests.swift
git commit -m "test: engine stats dominance (team strength + shooting)"
```

---

### Task 8: Engine — tactical layers change outcomes

**Files:**
- Modify: `FullballTests/FutsalEngineTests.swift` (add tests)

- [ ] **Step 1: Write the failing test** (append inside `struct FutsalEngineTests`)

```swift
    @Test func correctCounterBeatsWrongCounter() {
        // Opponent team style = .physical. Correct counter = .pace (pace > physical).
        let opp = Self.side(prefix: "a", base: 60, style: .physical)
        let right = Self.side(prefix: "h", base: 60, tactics: Tactics(counter: .pace))
        let wrong = Self.side(prefix: "h", base: 60, tactics: Tactics(counter: .physical))
        var rightGoals = 0, wrongGoals = 0
        for seed in UInt64(0)..<60 {
            rightGoals += FutsalEngine.play(home: right, away: opp, seed: seed).homeGoals
            wrongGoals += FutsalEngine.play(home: wrong, away: opp, seed: seed).homeGoals
        }
        #expect(rightGoals > wrongGoals)
    }

    @Test func markingTheDangerManReducesTheirGoals() {
        // Home attacks; away marks home's danger man with a strong defender.
        let home = Self.side(prefix: "h", base: 70)
        func awayMarking(_ marks: Bool) -> MatchSide {
            let strongMarker = Self.mp("ad", .def, Stats(pace: 60, shooting: 20, passing: 50, defending: 95))
            let s = Stats(pace: 60, shooting: 60, passing: 60, defending: 60)
            let players = [
                Self.mp("agk", .gk, s), strongMarker,
                Self.mp("am", .mid, s), Self.mp("af1", .fwd, s), Self.mp("af2", .fwd, s),
            ]
            let t = Tactics(markerID: marks ? "ad" : nil)
            return MatchSide(players: players, tactics: t, teamStyle: .technical,
                             dangerManID: "af1", captainID: nil)
        }
        var markedGoals = 0, freeGoals = 0
        for seed in UInt64(0)..<60 {
            markedGoals += FutsalEngine.play(home: home, away: awayMarking(true),  seed: seed).homeGoals
            freeGoals   += FutsalEngine.play(home: home, away: awayMarking(false), seed: seed).homeGoals
        }
        #expect(markedGoals < freeGoals)
    }
```

- [ ] **Step 2: Run test to verify it passes** — the Task 6 engine implements counter + marking, so these should pass. Expected: PASS. (If marginal, raise `counterEdgeWeight` / `markWeight` in `FutsalRules` until the relationship is reliable across the 60-seed sample, then re-run.)

- [ ] **Step 3: Commit**

```bash
git add FullballTests/FutsalEngineTests.swift
git commit -m "test: engine tactical layers (counter-pick + marking)"
```

---

### Task 9: Phase-1 wrap — full suite green + count check

**Files:** none (verification task)

- [ ] **Step 1: Regenerate and run the entire test target**

Run: `xcodegen generate` then the full test command.
Expected: PASS. The suite grows by the new files (PlayStyle, Formation, Tactics, MatchTypes, EnergyRules, FutsalEngine ×3 groups) on top of the existing 65 tests. Confirm no existing test regressed.

- [ ] **Step 2: Build the app target (no UI changes, but confirm it compiles)**

Run: `xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit any regen artifacts if needed** (usually none — `.xcodeproj` is gitignored)

```bash
git status   # expect clean working tree
```

---

## Self-review (completed by author)

- **Spec coverage (Phase 1 scope):** resolution engine §2 → Tasks 1–8; player-style RPS → Task 1; formation RPS → Task 2; mentality/marking/counter tactics → Tasks 3, 6, 8; stat mapping incl. "low shooting → more misses" → Task 7; energy penalty/regen pure functions → Task 5; reward-premium constant placeholder (`maxTacticsBonus`) defined for the later rewards phase → Task 5. Deferred to later plans (correctly out of Phase 1): `OpponentGenerator`, `Tactics` persistence, `LiveMatchService` rework, tactics-board UI, futsal playback view, energy storage/Gem-refill wiring, rewards integration, PvP.
- **Placeholder scan:** none — every code/test step contains complete Swift.
- **Type consistency:** `MatchSide`/`MatchPlayer`/`Tactics`/`PlayStyle`/`Formation`/`Mentality`/`MatchResult`/`PossessionEvent`/`PlayerContribution` names and signatures are used identically across Tasks 4, 6, 7, 8. `FutsalRules`/`EnergyRules` member names match between Task 5 definition and Task 6 usage (`possessionCount`, `baseChance`, `strengthWeight`, `formationEdgeWeight`, `mentalityWeight`, `counterEdgeWeight`, `chanceFloor/Ceil`, `baseGoal`, `shotWeight`, `styleEdgeWeight`, `saveBand`, `goalFloor/Ceil`, `markWeight`).
```
