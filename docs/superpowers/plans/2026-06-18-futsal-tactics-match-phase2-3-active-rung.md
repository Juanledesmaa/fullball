# Futsal Tactics Match — Phase 2+3 (Active Rung) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]` checkboxes.

**Goal:** Add an optional "active rung" to each Live match: a pre-game tactics board (formation · mentality · marking · counter-pick) + a watch-only futsal playback (your 5 vs a generated opponent 5, resolved by `FutsalEngine`), awarding a tactics-driven premium. The existing auto "ENTER" flow is untouched.

**Architecture:** Pure, testable pieces first — `OpponentGenerator` (deterministic opponent `MatchSide` from a fixture + catalog), `MatchSideAssembly` (builds your `MatchSide` from fielded cards + persisted `Tactics`), `FutsalReward` (maps `MatchResult` contributions → currency). Then `Tactics` persistence on the `Lineup` model, a `TacticsMatchViewModel`, two SwiftUI screens (tactics board + playback), and wiring from `LiveMatchesView`/`AppContainer`. Reuses existing `WalletService`, `ScoreBoard`, `MilestoneService`, `MatchProgressStore`, `CollectionService`, `CatalogService`.

**Tech Stack:** Swift 6, SwiftUI (`@Observable`, `NavigationStack`/`fullScreenCover`), SwiftData (`Lineup` model), Swift Testing. No new third-party deps.

**Conventions (apply to every task):**
- After adding/removing any `.swift` file: `xcodegen generate` before building.
- Sim is ambiguous by name — use UDID. Test: `xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`. Build: `xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`.
- Theme: use `WC` tokens (`WC.screenBG`, `WC.inkText`, `WC.sub`, `WC.coral`, `WC.gold`, `WC.display(_:)`, `WC.ui(_:)`). Never hardcode hex in views.
- ViewModels: `@MainActor @Observable final class`, built in the View's `init` from injected `AppContainer`.
- Per CLAUDE.md: write unit tests ONLY for pure deterministic logic (Tasks A2/A3). UI/SwiftData-wiring tasks (A1, B1–B5) are verified by build + manual run, NOT unit tests.

**Key facts from the codebase map (verbatim signatures you will call):**
- `FutsalEngine.play(home: MatchSide, away: MatchSide, seed: UInt64) -> MatchResult`
- `MatchPlayer(id: String, position: Position, stats: Stats)`; `MatchSide(players:tactics:teamStyle:dangerManID:captainID:)`; `MatchSide.goalkeeper/outfield`.
- `MatchResult.homeGoals/awayGoals/events:[PossessionEvent]/homeContributions/awayContributions:[PlayerContribution]`. `PossessionEvent(index, attackingHome, ballPlayerID, outcome: .turnover/.goal/.save/.miss, assistID)`. `PlayerContribution(playerID, goals, assists, saves, points)`.
- `Tactics(formation:Formation = .diamond, mentality:Mentality = .balanced, markerID:String? = nil, counter:PlayStyle? = nil)`. `Formation: .diamond/.defensive/.attacking` (+`displayName`, `edge`). `Mentality: .parkBus/.defend/.balanced/.attack/.allOut` (Int raw, +`displayName`). `PlayStyle: .technical/.physical/.pace` (+`displayName`, `from(_:)`, `edge`).
- `Card{ id, player: Player{ id, displayName, nationTag, shirtNumber, position: Position, name?, epithet?, stats: Stats }, rarity }`. `Stats{ pace, shooting, passing, defending; overall }`.
- `UpgradeRules.effectiveStats(base: Stats, level: Int, stars: Int) -> Stats`.
- `CatalogService { var cards:[Card]; var nations:[Nation]; func card(id:)->Card?; func nationName(_:)->String }`.
- `CollectionService { func owned() -> [OwnedCard]; func instance(forCardID:) -> CardInstance? }`. `OwnedCard{ instance: CardInstance, card: Card, effectiveStats: Stats }`. `CardInstance{ cardID, level, stars, ... }`.
- `LineupService { var maxFielded; func fielded()->[String]; var captainID:String?; isFielded/isCaptain/toggleField/setCaptain }`. `SwiftDataLineupService(context:validIDs:)`. `Lineup{ @Model var fieldedIDs:[String]; var captainID:String? }`.
- `WalletService { balance(_:Currency)->Int; credit(_:_:); @discardableResult debit(_:_:)->Bool; save() }`. `Currency: .coins/.gems/.tickets/.formTokens`.
- `ScoreBoard.award(points:Int, formTokens:Int)`; `.points`. `MilestoneService.claim(points:Int)->[MilestoneTier]`.
- `MatchProgressStore { func record(slateID:fixtureID:)->MatchRecord; func save() }`. `MatchRecord{ statusRaw:"entered"/"finished", pointsEarned, formEarned, home, away, wonBonus }`.
- `MatchSlateService{ var fixtures:[Fixture]; var slateID:String }`. `Fixture{ id, homeTag, awayTag, group, venue, status }`. `DeviceSeed.sharedSeed(for slateID:String)->UInt64`.
- `LiveRules.entryFeeCoins = 200`, `.winBonusTarget = 150`, `.winBonusTickets = 1`. `AgentRules.commission(forPoints:)->Int`. `LineupRules.captainMultiplier = 2`. `FutsalRules.maxTacticsBonus = 1.5`.
- `AppContainer` builds services in `init`, exposes them as `let`s; `static let schema = Schema([... Lineup.self ...])`.

---

## PART A — Pure logic & persistence

### Task A1: `Tactics` persistence on `Lineup` + `LineupService`

**Files:**
- Modify: `Fullball/Domain/Models/Lineup.swift`
- Modify: `Fullball/Services/LineupService.swift`

No unit test (SwiftData wiring). Verify by build.

- [ ] **Step 1: Add tactics fields to the `Lineup` @Model.** Open `Fullball/Domain/Models/Lineup.swift`. Add stored properties with defaults (lightweight migration-safe) so existing rows load. The model currently has `fieldedIDs` and `captainID`. Add:

```swift
    var formationRaw: String = Formation.diamond.rawValue
    var mentalityRaw: Int = Mentality.balanced.rawValue
    var markerID: String? = nil
    var counterRaw: String? = nil
```

Keep the existing `init` working — if it has an initializer, add defaulted params or just rely on property defaults. If there is an `init()`, leave the new properties to their defaults (do not require them as params).

- [ ] **Step 2: Extend the `LineupService` protocol.** In `Fullball/Services/LineupService.swift`, add to the protocol:

```swift
    var tactics: Tactics { get }
    func setTactics(_ tactics: Tactics)
```

- [ ] **Step 3: Implement in `SwiftDataLineupService`.** Add:

```swift
    var tactics: Tactics {
        Tactics(
            formation: Formation(rawValue: model.formationRaw) ?? .diamond,
            mentality: Mentality(rawValue: model.mentalityRaw) ?? .balanced,
            markerID: model.markerID,
            counter: model.counterRaw.flatMap { PlayStyle(rawValue: $0) }
        )
    }

    func setTactics(_ tactics: Tactics) {
        model.formationRaw = tactics.formation.rawValue
        model.mentalityRaw = tactics.mentality.rawValue
        model.markerID = tactics.markerID
        model.counterRaw = tactics.counter?.rawValue
        try? context.save()
    }
```

(The service already holds `model` and `context` — see existing `toggleField`.)

- [ ] **Step 4: Update any Mock lineup service** if one exists (search `class Mock`...`LineupService`). Add a stored `var tactics: Tactics = Tactics()` and `func setTactics(_ t: Tactics) { tactics = t }` so it still conforms.

- [ ] **Step 5: Build.** Run `xcodegen generate` then the build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit.**
```bash
git add Fullball/Domain/Models/Lineup.swift Fullball/Services/LineupService.swift
git commit -m "feat: persist Tactics on Lineup + LineupService"
```

---

### Task A2: `OpponentGenerator` (pure, tested)

**Files:**
- Create: `Fullball/Domain/Economy/OpponentGenerator.swift`
- Test: `FullballTests/OpponentGeneratorTests.swift`

- [ ] **Step 1: Write the failing test.**

```swift
import Testing
@testable import Fullball

struct OpponentGeneratorTests {
    private let cat = MockCatalogService()

    private func anyTag() -> String { cat.cards.first!.player.nationTag }

    @Test func deterministicForSameSeed() {
        let a = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        let b = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        #expect(a == b)
    }

    @Test func producesFivePlayersWithOneKeeper() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 7)
        #expect(side.players.count == 5)
        #expect(side.goalkeeper != nil)
        #expect(side.outfield.count == 4)
    }

    @Test func dangerManIsHighestShootingOutfielder() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 11)
        let topShooter = side.outfield.max { $0.stats.shooting < $1.stats.shooting }
        #expect(side.dangerManID == topShooter?.id)
    }

    @Test func fallsBackToGlobalPoolWhenNationTooSmall() {
        // A tag that doesn't exist still yields a full 5 from the global pool.
        let side = OpponentGenerator.opponent(awayTag: "ZZZ", cards: cat.cards, seed: 3)
        #expect(side.players.count == 5)
    }
}
```

- [ ] **Step 2: Run tests, verify FAIL** (`cannot find 'OpponentGenerator'`).

- [ ] **Step 3: Implement.**

```swift
import Foundation

/// Builds a deterministic opponent `MatchSide` for a fixture. Prefers the away
/// nation's players; backfills from the global catalog so a thin nation still
/// fields a full 5. Pure + seedable (mirrors `FixtureGenerator`).
enum OpponentGenerator {

    static func opponent(awayTag: String, cards: [Card], seed: UInt64) -> MatchSide {
        var rng = SeededRandomProvider(seed: seed)

        // Candidate pool: away-nation first, then everyone else (both shuffled),
        // so we deterministically prefer the nation but never run short.
        let nationPool = FixtureGenerator.shuffle(cards.filter { $0.player.nationTag == awayTag }, &rng)
        let restPool   = FixtureGenerator.shuffle(cards.filter { $0.player.nationTag != awayTag }, &rng)
        let ordered = nationPool + restPool

        // Pick a GK (first GK available; else synthesize from the first card).
        let gkCard = ordered.first { $0.player.position == .gk } ?? ordered.first
        var chosen: [Card] = []
        if let gkCard { chosen.append(gkCard) }
        for c in ordered where c.id != gkCard?.id {
            if chosen.count >= 5 { break }
            chosen.append(c)
        }

        let players: [MatchPlayer] = chosen.map {
            MatchPlayer(id: $0.id, position: $0.player.position, stats: $0.player.stats)
        }

        // Deterministic tactics for the AI.
        let formations = Formation.allCases
        let mentalities = Mentality.allCases
        let tactics = Tactics(
            formation: formations[rng.nextInt(formations.count)],
            mentality: mentalities[rng.nextInt(mentalities.count)]
        )

        let outfield = players.filter { $0.position != .gk }
        let dangerMan = outfield.max { $0.stats.shooting < $1.stats.shooting } ?? players.first!
        let teamStyle = dominantStyle(outfield.isEmpty ? players : outfield)

        return MatchSide(players: players, tactics: tactics, teamStyle: teamStyle,
                         dangerManID: dangerMan.id, captainID: dangerMan.id)
    }

    /// Most common derived style across the given players (ties → technical>physical>pace).
    static func dominantStyle(_ players: [MatchPlayer]) -> PlayStyle {
        var counts: [PlayStyle: Int] = [:]
        for p in players { counts[p.style, default: 0] += 1 }
        let order: [PlayStyle] = [.technical, .physical, .pace]
        return order.max { (counts[$0] ?? 0, -order.firstIndex(of: $0)!) < (counts[$1] ?? 0, -order.firstIndex(of: $1)!) } ?? .technical
    }
}
```

- [ ] **Step 4: Run tests, verify PASS.** If `dangerManIsHighestShootingOutfielder` is flaky because the away nation has fewer than required, the global backfill covers it — confirm `MockCatalogService` has cards (it does; `FixtureGeneratorTests` uses it).

- [ ] **Step 5: Commit.**
```bash
xcodegen generate
git add Fullball/Domain/Economy/OpponentGenerator.swift FullballTests/OpponentGeneratorTests.swift
git commit -m "feat: OpponentGenerator (deterministic opponent MatchSide)"
```

---

### Task A3: `MatchSideAssembly` + `FutsalReward` (pure, tested)

**Files:**
- Create: `Fullball/Domain/Economy/FutsalMatchSupport.swift`
- Test: `FullballTests/FutsalMatchSupportTests.swift`

- [ ] **Step 1: Write the failing test.**

```swift
import Testing
@testable import Fullball

struct FutsalMatchSupportTests {
    private func mp(_ id: String, _ pos: Position, _ s: Stats) -> (id: String, position: Position, stats: Stats) {
        (id, pos, s)
    }

    @Test func assemblyBuildsSideWithDangerManAndStyle() {
        let inputs = [
            mp("gk", .gk,  Stats(pace: 40, shooting: 10, passing: 40, defending: 80)),
            mp("d",  .def, Stats(pace: 50, shooting: 20, passing: 50, defending: 70)),
            mp("m",  .mid, Stats(pace: 60, shooting: 50, passing: 90, defending: 50)),
            mp("f1", .fwd, Stats(pace: 70, shooting: 95, passing: 50, defending: 30)),
            mp("f2", .fwd, Stats(pace: 80, shooting: 70, passing: 40, defending: 30)),
        ]
        let side = MatchSideAssembly.build(players: inputs, tactics: Tactics(counter: .pace), captainID: "f1")
        #expect(side.players.count == 5)
        #expect(side.dangerManID == "f1")          // highest shooting outfielder
        #expect(side.captainID == "f1")
        #expect(side.tactics.counter == .pace)
        #expect(side.teamStyle == PlayStyle.technical) // mid passing 90 dominates
    }

    @Test func rewardScalesWithPointsAndCaptainDoubles() {
        // Two contributions; f1 is captain and should count double in points.
        let contribs = [
            PlayerContribution(playerID: "f1", goals: 1, assists: 0, saves: 0, points: 100),
            PlayerContribution(playerID: "m",  goals: 0, assists: 1, saves: 0, points: 40),
        ]
        let r = FutsalReward.from(contributions: contribs, captainID: "f1")
        #expect(r.points == 240)                     // 100*2 + 40
        #expect(r.cash == AgentRules.commission(forPoints: 240))
        #expect(r.rep == 3)                          // goals 1 + assists 1 ... see formula
        #expect(r.wonBonus == (240 >= LiveRules.winBonusTarget))
    }

    @Test func rewardIsZeroForEmptyContributions() {
        let r = FutsalReward.from(contributions: [], captainID: nil)
        #expect(r.points == 0)
        #expect(r.cash == 0)
        #expect(r.wonBonus == false)
    }
}
```

- [ ] **Step 2: Run, verify FAIL.**

- [ ] **Step 3: Implement.** (Note the Rep formula chosen so the test passes: `rep = sum(goals*2 + assists + saves)`; for the test, f1 goals1→2, m assists1→1, total 3.)

```swift
import Foundation

/// Assembles your `MatchSide` from already-resolved effective stats + tactics.
/// Pure: the MainActor caller computes effective stats first.
enum MatchSideAssembly {
    static func build(players: [(id: String, position: Position, stats: Stats)],
                      tactics: Tactics,
                      captainID: String?) -> MatchSide {
        let mps = players.map { MatchPlayer(id: $0.id, position: $0.position, stats: $0.stats) }
        let outfield = mps.filter { $0.position != .gk }
        let dangerMan = outfield.max { $0.stats.shooting < $1.stats.shooting } ?? mps.first
        let style = OpponentGenerator.dominantStyle(outfield.isEmpty ? mps : outfield)
        return MatchSide(players: mps, tactics: tactics, teamStyle: style,
                         dangerManID: dangerMan?.id ?? "", captainID: captainID)
    }
}

/// Maps a side's match contributions to currency rewards. Captain points double.
enum FutsalReward {
    struct Payout: Equatable {
        var points = 0
        var cash = 0
        var rep = 0
        var wonBonus = false
    }

    static func from(contributions: [PlayerContribution], captainID: String?) -> Payout {
        var points = 0
        var rep = 0
        for c in contributions {
            let mult = (c.playerID == captainID) ? LineupRules.captainMultiplier : 1
            points += c.points * mult
            rep += c.goals * 2 + c.assists + c.saves
        }
        let cash = AgentRules.commission(forPoints: points)
        let wonBonus = points >= LiveRules.winBonusTarget
        return Payout(points: points, cash: cash, rep: rep, wonBonus: wonBonus)
    }
}
```

- [ ] **Step 4: Run, verify PASS.** (If `teamStyle` assertion fails, recheck `PlayStyle.from`: passing 90 is the max stat for "m", so dominant style across outfield with one technical, others physical/pace — confirm the mid's technical wins the count or adjust the test's expectation to the actual dominant; the provided inputs make `m`=technical, `d`=physical, `f1`=pace, `f2`=pace → dominant is pace. **FIX:** change the test expectation to `.pace` OR change inputs. Use `.pace` to match the data.)

  Resolve this now: set the test expectation to `#expect(side.teamStyle == PlayStyle.pace)` (with these inputs, two pace outfielders outnumber one technical and one physical). Re-run, verify PASS.

- [ ] **Step 5: Commit.**
```bash
xcodegen generate
git add Fullball/Domain/Economy/FutsalMatchSupport.swift FullballTests/FutsalMatchSupportTests.swift
git commit -m "feat: MatchSideAssembly + FutsalReward (pure)"
```

---

## PART B — ViewModel, UI, wiring (build + manual verify; no unit tests)

### Task B1: `TacticsMatchViewModel`

**Files:**
- Create: `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`

Scene: this VM owns one fixture's active-rung session. It generates the opponent (for scouting), exposes editable `Tactics` (persisted via `LineupService`), assembles your side, runs `FutsalEngine`, steps playback through `MatchResult.events` on a timer (~compressed), then awards rewards once and finalizes the `MatchRecord`.

- [ ] **Step 1: Implement the ViewModel.**

```swift
import Foundation
import Observation

@MainActor @Observable
final class TacticsMatchViewModel {
    enum Phase: Equatable { case setup, playing, fullTime }

    let fixture: Fixture
    private let catalog: any CatalogService
    private let collection: any CollectionService
    private let lineup: any LineupService
    private let wallet: any WalletService
    private let score: ScoreBoard
    private let milestones: any MilestoneService
    private let store: any MatchProgressStore
    private let slateID: String

    // Scouting (opponent) + your editable tactics.
    let opponent: MatchSide
    var tactics: Tactics { didSet { lineup.setTactics(tactics) } }

    // Playback state.
    var phase: Phase = .setup
    var minuteIndex = 0            // index into events
    var homeGoals = 0
    var awayGoals = 0
    var lastEvent: PossessionEvent?
    private(set) var result: MatchResult?
    private(set) var payout: FutsalReward.Payout?
    var awardedTiers: [MilestoneTier] = []

    let entryFee = LiveRules.entryFeeCoins
    var canAfford: Bool { wallet.balance(.coins) >= entryFee }
    var alreadyFinished: Bool {
        store.record(slateID: slateID, fixtureID: fixture.id).statusRaw == "finished"
    }

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        self.fixture = fixture
        self.catalog = container.catalog
        self.collection = container.collection
        self.lineup = container.lineup
        self.wallet = container.wallet
        self.score = container.score
        self.milestones = container.milestones
        self.store = container.matchStore
        self.slateID = slateID
        self.opponent = OpponentGenerator.opponent(
            awayTag: fixture.awayTag,
            cards: container.catalog.cards,
            seed: DeviceSeed.sharedSeed(for: slateID) &+ UInt64(bitPattern: Int64(fixture.id.hashValue)))
        self.tactics = container.lineup.tactics
    }

    /// Build your side from the fielded XI's effective stats + current tactics.
    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        let fieldedIDs = lineup.fielded()
        let inputs: [(id: String, position: Position, stats: Stats)] = fieldedIDs.compactMap { id in
            guard let oc = owned.first(where: { $0.id == id }) else { return nil }
            return (id, oc.card.player.position, oc.effectiveStats)
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: lineup.captainID)
    }

    var seed: UInt64 {
        DeviceSeed.sharedSeed(for: slateID) &+ UInt64(bitPattern: Int64(fixture.id.hashValue))
    }

    /// Pay entry, run engine, begin stepping playback.
    func kickOff() {
        guard phase == .setup, !alreadyFinished, canAfford else { return }
        guard lineup.fielded().count >= 1 else { return }
        wallet.debit(.coins, entryFee)
        let home = buildHomeSide()
        let res = FutsalEngine.play(home: home, away: opponent, seed: seed)
        self.result = res
        self.phase = .playing
        self.minuteIndex = 0
    }

    /// Advance playback by one event; call from a timer in the view. Returns
    /// false when there are no more events (caller stops the timer + settles).
    @discardableResult
    func step() -> Bool {
        guard let res = result, phase == .playing else { return false }
        guard minuteIndex < res.events.count else { settle(); return false }
        let e = res.events[minuteIndex]
        lastEvent = e
        if e.outcome == .goal { if e.attackingHome { homeGoals += 1 } else { awayGoals += 1 } }
        minuteIndex += 1
        if minuteIndex >= res.events.count { settle() ; return false }
        return true
    }

    private func settle() {
        guard phase == .playing, let res = result else { return }
        phase = .fullTime
        let pay = FutsalReward.from(contributions: res.homeContributions, captainID: lineup.captainID)
        self.payout = pay
        // Award once.
        score.award(points: pay.points, formTokens: pay.rep)
        if pay.cash > 0 { wallet.credit(.coins, pay.cash) }
        if pay.wonBonus { wallet.credit(.tickets, LiveRules.winBonusTickets) }
        wallet.save()
        // Persist match as finished.
        let rec = store.record(slateID: slateID, fixtureID: fixture.id)
        rec.statusRaw = "finished"
        rec.pointsEarned = pay.points
        rec.formEarned = pay.rep
        rec.home = res.homeGoals
        rec.away = res.awayGoals
        rec.wonBonus = pay.wonBonus
        store.save()
        // Milestones.
        awardedTiers = milestones.claim(points: score.points)
    }

    // Scouting helpers for the board.
    var opponentName: String { catalog.nationName(fixture.awayTag) }
    var dangerMan: MatchPlayer? { opponent.player(opponent.dangerManID) }
    var yourFieldedCount: Int { lineup.fielded().count }
    func myFieldedCards() -> [OwnedCard] {
        let ids = Set(lineup.fielded())
        return collection.owned().filter { ids.contains($0.id) }
    }
}
```

- [ ] **Step 2: Build.** `xcodegen generate` then build. Fix any signature mismatches against the real `AppContainer`/services by reading the actual files (`AppContainer.swift`, `ScoreBoard.swift`, `MatchProgressStore.swift`). Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit.**
```bash
git add Fullball/Features/LiveMatches/TacticsMatchViewModel.swift
git commit -m "feat: TacticsMatchViewModel (assemble, run engine, award)"
```

---

### Task B2: Tactics board view (`TacticsMatchView`)

**Files:**
- Create: `Fullball/Features/LiveMatches/TacticsMatchView.swift`

Scene: the entry screen of the active rung. Shows opponent scouting + the 4 decisions + KICK OFF. On kickoff, swaps to the playback view (Task B3) in the same screen via the VM's `phase`.

- [ ] **Step 1: Implement.** Follow existing view patterns (look at `LiveMatchesView.swift` for `WC` usage, `ScreenHeader`, card styling). Concrete scaffold:

```swift
import SwiftUI

struct TacticsMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm: TacticsMatchViewModel

    init(fixture: Fixture, container: AppContainer, slateID: String) {
        _vm = State(initialValue: TacticsMatchViewModel(fixture: fixture, container: container, slateID: slateID))
    }

    var body: some View {
        ZStack {
            WC.screenBG.ignoresSafeArea()
            switch vm.phase {
            case .setup:    setup
            case .playing, .fullTime: FutsalPitchView(vm: vm, onClose: { dismiss() })
            }
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scouting
                formationPicker
                mentalityPicker
                markerPicker
                counterPicker
                kickOff
            }
            .padding(20)
        }
    }

    private var scouting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SCOUTING").font(WC.ui(12)).foregroundStyle(WC.sub)
            Text(vm.opponentName).font(WC.display(22)).foregroundStyle(WC.inkText)
            Text("Shape: \(vm.opponent.tactics.formation.displayName)").foregroundStyle(WC.sub)
            Text("Style: \(vm.opponent.teamStyle.displayName)").foregroundStyle(WC.sub)
            if let d = vm.dangerMan, let c = vm.catalogCard(d.id) {
                Text("Danger: \(c.displayName) (SHO \(d.stats.shooting))").foregroundStyle(WC.coral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(WC.cardBG).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var formationPicker: some View {
        picker("FORMATION", Formation.allCases, vm.tactics.formation, \.displayName) { vm.tactics.formation = $0 }
    }
    private var mentalityPicker: some View {
        picker("MENTALITY", Mentality.allCases, vm.tactics.mentality, \.displayName) { vm.tactics.mentality = $0 }
    }
    private var counterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COUNTER-PICK").font(WC.ui(12)).foregroundStyle(WC.sub)
            HStack {
                chip("None", vm.tactics.counter == nil) { vm.tactics.counter = nil }
                ForEach(PlayStyle.allCases, id: \.self) { s in
                    chip(s.displayName, vm.tactics.counter == s) { vm.tactics.counter = s }
                }
            }
        }
    }
    private var markerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MARK THEIR DANGER MAN").font(WC.ui(12)).foregroundStyle(WC.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("None", vm.tactics.markerID == nil) { vm.tactics.markerID = nil }
                    ForEach(vm.myFieldedCards()) { oc in
                        chip(oc.card.displayName, vm.tactics.markerID == oc.id) { vm.tactics.markerID = oc.id }
                    }
                }
            }
        }
    }

    private var kickOff: some View {
        VStack(spacing: 8) {
            if vm.alreadyFinished {
                Text("Already played this block.").foregroundStyle(WC.sub)
            } else if vm.yourFieldedCount == 0 {
                Text("Field at least one client first.").foregroundStyle(WC.coral)
            } else if !vm.canAfford {
                Text("Need \(vm.entryFee) Cash to play.").foregroundStyle(WC.coral)
            }
            Button { vm.kickOff() } label: {
                Text("KICK OFF · \(vm.entryFee)")
                    .font(WC.ui(16)).frame(maxWidth: .infinity).padding()
                    .background(WC.coral).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(vm.alreadyFinished || vm.yourFieldedCount == 0 || !vm.canAfford)
            .opacity((vm.alreadyFinished || vm.yourFieldedCount == 0 || !vm.canAfford) ? 0.5 : 1)
        }
    }

    // Generic single-select pill row.
    private func picker<T: Hashable>(_ title: String, _ all: [T], _ sel: T,
                                     _ label: KeyPath<T, String>, _ set: @escaping (T) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(WC.ui(12)).foregroundStyle(WC.sub)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { ForEach(all, id: \.self) { v in chip(v[keyPath: label], v == sel) { set(v) } } }
            }
        }
    }
    private func chip(_ text: String, _ on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(text).font(WC.ui(13)).padding(.horizontal, 12).padding(.vertical, 8)
                .background(on ? WC.coral : WC.fillBG)
                .foregroundStyle(on ? .white : WC.inkText)
                .clipShape(Capsule())
        }
    }
}
```

Add the small helper the view uses to resolve a catalog card name, on the VM (`TacticsMatchViewModel`):
```swift
    func catalogCard(_ id: String) -> Card? { catalog.card(id: id) }
```

- [ ] **Step 2: Build.** Reconcile token names against `Theme.swift` (`WC.cardBG`, `WC.fillBG`, `WC.ui`, `WC.display`, `WC.sub`, `WC.coral`, `WC.inkText`, `WC.screenBG` — confirm each exists; substitute the nearest real token if a name differs). Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit.**
```bash
git add Fullball/Features/LiveMatches/TacticsMatchView.swift Fullball/Features/LiveMatches/TacticsMatchViewModel.swift
git commit -m "feat: tactics board UI (scouting + 4 decisions)"
```

---

### Task B3: Futsal playback view (`FutsalPitchView`)

**Files:**
- Create: `Fullball/Features/LiveMatches/FutsalPitchView.swift`

Scene: watch-only. Round profiles for both 5s on a vertical pitch; a ball marker hops to the current event's `ballPlayerID`; score + a one-line event ticker update; a timer calls `vm.step()` to compress the ~14 events into ~30–40s; at full time, show the payout + a close button.

- [ ] **Step 1: Implement.**

```swift
import SwiftUI

struct FutsalPitchView: View {
    @Bindable var vm: TacticsMatchViewModel
    var onClose: () -> Void

    // ~14 events compressed into ~35s → ~2.5s/event. Tune to taste.
    private let tick = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            scoreboard
            pitch
            ticker
            if vm.phase == .fullTime { fullTime }
            Spacer(minLength: 0)
        }
        .padding(18)
        .onReceive(tick) { _ in if vm.phase == .playing { vm.step() } }
    }

    private var scoreboard: some View {
        HStack {
            Text("YOU").font(WC.ui(13)).foregroundStyle(WC.sub)
            Spacer()
            Text("\(vm.homeGoals) – \(vm.awayGoals)").font(WC.display(30)).foregroundStyle(WC.inkText)
            Spacer()
            Text(vm.opponentName.uppercased()).font(WC.ui(13)).foregroundStyle(WC.sub)
        }
    }

    private var pitch: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x13402A))
                Rectangle().fill(WC.line).frame(height: 1).position(x: geo.size.width/2, y: geo.size.height/2)
                // Away 5 top half, your 5 bottom half.
                ForEach(Array(slots(vm.opponent.players, top: true, in: geo.size).enumerated()), id: \.0) { _, item in
                    profile(item.player, tag: vm.fixture.awayTag, isBall: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == false).position(item.point)
                }
                ForEach(Array(slots(homePlayers(), top: false, in: geo.size).enumerated()), id: \.0) { _, item in
                    profile(item.player, tag: vm.fixture.homeTag, isBall: item.player.id == vm.lastEvent?.ballPlayerID && vm.lastEvent?.attackingHome == true).position(item.point)
                }
            }
        }
        .frame(height: 360)
    }

    private var ticker: some View {
        Text(eventText).font(WC.ui(14)).foregroundStyle(WC.inkText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.default, value: vm.minuteIndex)
    }

    private var fullTime: some View {
        VStack(spacing: 8) {
            Text("FULL TIME").font(WC.display(20)).foregroundStyle(WC.gold)
            if let p = vm.payout {
                Text("+\(p.points) pts · +\(p.cash) Cash · +\(p.rep) Rep" + (p.wonBonus ? " · +1 Scout" : ""))
                    .font(WC.ui(14)).foregroundStyle(WC.inkText).multilineTextAlignment(.center)
            }
            Button("Done") { onClose() }
                .font(WC.ui(15)).padding(.horizontal, 24).padding(.vertical, 10)
                .background(WC.coral).foregroundStyle(.white).clipShape(Capsule())
        }
    }

    // MARK: helpers
    private func homePlayers() -> [MatchPlayer] {
        let owned = vm.myFieldedCards()
        return owned.map { MatchPlayer(id: $0.id, position: $0.card.player.position, stats: $0.effectiveStats) }
    }

    private struct Slot { let player: MatchPlayer; let point: CGPoint }
    private func slots(_ players: [MatchPlayer], top: Bool, in size: CGSize) -> [Slot] {
        guard !players.isEmpty else { return [] }
        let rowYs: [CGFloat] = top ? [0.12, 0.30] : [0.88, 0.70]   // GK row, outfield row
        let gk = players.first { $0.position == .gk }
        let outs = players.filter { $0.position != .gk }
        var result: [Slot] = []
        if let gk { result.append(Slot(player: gk, point: CGPoint(x: size.width*0.5, y: size.height*rowYs[0]))) }
        for (i, p) in outs.enumerated() {
            let x = size.width * CGFloat(Double(i + 1) / Double(outs.count + 1))
            result.append(Slot(player: p, point: CGPoint(x: x, y: size.height*rowYs[1])))
        }
        return result
    }

    private func profile(_ p: MatchPlayer, tag: String, isBall: Bool) -> some View {
        ZStack {
            Circle().fill(WC.cardBG).frame(width: 42, height: 42)
                .overlay(Circle().stroke(isBall ? WC.gold : WC.line, lineWidth: isBall ? 3 : 1))
            Text(tag.prefix(3)).font(WC.ui(10)).foregroundStyle(WC.sub)
            if isBall { Circle().fill(.white).frame(width: 10, height: 10).offset(x: 16, y: -16) }
        }
    }

    private var eventText: String {
        guard let e = vm.lastEvent else { return "Kick off!" }
        let who = vm.catalogCard(e.ballPlayerID)?.displayName ?? e.ballPlayerID
        switch e.outcome {
        case .goal: return "⚽️ GOAL — \(who)"
        case .save: return "🧤 Save"
        case .miss: return "😬 Miss — \(who)"
        case .turnover: return "Turnover"
        }
    }
}
```

- [ ] **Step 2: Build.** Confirm `Color(hex:)` exists (it does — `Rarity.color` uses it). Confirm `WC.line`, `WC.cardBG`, `WC.gold` exist; substitute nearest real tokens if needed. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit.**
```bash
git add Fullball/Features/LiveMatches/FutsalPitchView.swift
git commit -m "feat: futsal playback view (round profiles + ball)"
```

---

### Task B4: Wire the active rung into `LiveMatchesView`

**Files:**
- Modify: `Fullball/Features/LiveMatches/LiveMatchesView.swift`

Scene: each match card gets a "MANAGE & PLAY" button that presents `TacticsMatchView` for that fixture. The existing auto "ENTER" button stays.

- [ ] **Step 1: Read** `LiveMatchesView.swift` fully to find the match-card builder and how it accesses the container/slate. The view needs `AppContainer` and `slateID`. The VM has `slateService.slateID`; check how the view already reads the container (likely `@Environment` injected). Confirm how to get the `AppContainer` in the view (the app injects services via `.environment`; if the whole container isn't in the environment, add a parameter to the card or read the needed services — prefer presenting `TacticsMatchView` with the container the parent already holds).

- [ ] **Step 2: Add presentation state + button.** In the match-card view add:

```swift
    @State private var activeFixture: Fixture?
```

and on the card, next to the existing ENTER button (lobby phase only), add:

```swift
    Button {
        activeFixture = match.fixture
    } label: {
        Text("MANAGE & PLAY").font(WC.ui(13))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(WC.fillBG).foregroundStyle(WC.inkText).clipShape(Capsule())
    }
```

and attach the cover on the list/container:

```swift
    .fullScreenCover(item: $activeFixture) { fx in
        TacticsMatchView(fixture: fx, container: container, slateID: vm.slateID)
    }
```

`Fixture` is already `Identifiable`. Expose `slateID` on `LiveMatchesViewModel` if not public: add `var slateID: String { slateService.slateID }`. Obtain `container`: if the view doesn't already hold an `AppContainer`, add an `let container: AppContainer` to the view's init (the parent `RootView`/tab already constructs it — pass it through). Read the existing init to match the established injection style; do NOT introduce a new global.

- [ ] **Step 3: After a match is played via the active rung, refresh the list.** On cover dismiss, call the VM's existing restore/refresh path so the played fixture shows as finished:

```swift
    .onChange(of: activeFixture) { _, newValue in
        if newValue == nil { vm.restore() }   // use the real method name from the VM
    }
```

Read `LiveMatchesViewModel` for the actual reload method (the map noted `restore()`); use whatever re-reads `MatchRecord`s.

- [ ] **Step 4: Build + manual sanity.** `xcodegen generate`, build. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit.**
```bash
git add Fullball/Features/LiveMatches/LiveMatchesView.swift Fullball/Features/LiveMatches/LiveMatchesViewModel.swift
git commit -m "feat: wire MANAGE & PLAY active rung into Live"
```

---

### Task B5: Full verification

**Files:** none.

- [ ] **Step 1: Full test suite** (the pure tasks added tests; confirm green + no regressions). `xcodegen generate` then the test command. Expected: PASS (89 + the A2/A3 tests).

- [ ] **Step 2: Build the app.** Build command → BUILD SUCCEEDED.

- [ ] **Step 3: Launch on the simulator and drive the flow** (best-effort; navigation taps may be unavailable from CLI — at minimum confirm launch + no crash):
```bash
SIM=392871BC-2A9F-4E1A-925D-2235BD1E5E04
xcrun simctl boot $SIM 2>/dev/null; true
APP=$(find ~/Library/Developer/Xcode/DerivedData/Fullball-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)
xcrun simctl install $SIM "$APP" && xcrun simctl launch $SIM com.juanledesma.Fulbo.app -seedDemo 1 -startTab 3
```
Take a screenshot: `xcrun simctl io $SIM screenshot /tmp/live.png`. Confirm the Live tab shows match cards with a "MANAGE & PLAY" button. Report the screenshot path.

- [ ] **Step 4: Report** the test count, build result, and what the screenshot shows.

---

## Self-review (author)

- **Spec coverage:** active rung (auto+active coexist) — Task B4; tactics board with formation/mentality/marking/counter + scouting — B2; your-5-vs-opponent-5 via FutsalEngine — B1 + A2 + A3; watch-only playback with round profiles + ball — B3; tactics persistence — A1; reward premium via contributions (captain ×2, commission, Rep, win bonus, milestones) — A3 + B1. Energy (P4) intentionally deferred. PvP (phase B) deferred.
- **Placeholder scan:** UI tasks include real scaffold code but explicitly instruct verifying token/component/init names against the actual files (`Theme.swift`, `LiveMatchesView.swift`, `AppContainer.swift`) — these are integration reconciliations, not placeholders. Pure tasks (A2/A3) are exact.
- **Type consistency:** `MatchSide`/`MatchPlayer`/`Tactics`/`MatchResult`/`PlayerContribution` usage matches Phase-1 definitions; `OpponentGenerator.dominantStyle` reused by `MatchSideAssembly`; `FutsalReward.Payout` consumed by `TacticsMatchViewModel.settle`/`FutsalPitchView.fullTime`; `LineupService.tactics/setTactics` defined in A1 and used in B1.
- **Known reconciliations the implementer MUST do (flagged, not hidden):** exact `AppContainer` injection into `LiveMatchesView`; real reload method name on `LiveMatchesViewModel`; exact `WC` token names; presence of `Color(hex:)`. Each task says to read the real file and adapt.
