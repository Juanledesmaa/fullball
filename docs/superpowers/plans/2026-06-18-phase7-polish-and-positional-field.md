# Phase 7 — Polish + positional drag field

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Four parts. Pure logic gets a test (Part C penalty); UI parts are build + screenshot. Run order: A, B, D, then C (C is the largest and edits the match VM/view; D also edits the VM — do D before C to avoid churn).

**Sim UDID** `392871BC-2A9F-4E1A-925D-2235BD1E5E04`. `xcodegen generate` after add/remove. Build/test as in prior plans. Theme via `WC`. Currency: `.coins`(Cash) `.gems`(Gems) `.tickets`(Scouts) `.formTokens`(Rep), each has `.symbol`/`.tint`/`.label`. `CurrencyCost` view exists in `Fullball/Features/Components/CurrencyCost.swift`.

---

## PART A — Currency-button contrast + rarity tag wrap

Problem (screenshot 1): on the green SIGN button and red PULL button the cost uses the currency tint, which is invisible against the colored fill. The top wallet bar shows a currency as a tinted icon + **light** amount on a dark chip — match that contrast.

### Task A1: `CurrencyCost` on-color variant
- [ ] **Step 1:** In `Fullball/Features/Components/CurrencyCost.swift`, add an `onColor` style so the label reads on a saturated button. Keep the default (tinted, for dark backgrounds):
```swift
struct CurrencyCost: View {
    let currency: Currency
    let amount: Int
    var onColor: Bool = false      // true when placed on a saturated button fill
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: currency.symbol)
            Text("\(amount)")
        }
        .font(WC.ui(14))
        .foregroundStyle(onColor ? Color.white : currency.tint)
    }
}
```
(Adapt to the real symbol/tint API. If the wallet bar uses a dark pill, you may instead wrap the on-color variant in a `.background(.black.opacity(0.22))` capsule to mirror the bar — pick whichever matches the bar most closely and note it.)
- [ ] **Step 2:** Apply `onColor: true` to every cost rendered INSIDE a colored button:
  - Market SIGN/RE-SIGN button (`Fullball/Features/Market/MarketView.swift`) — the in-button price.
  - Scout PULL ×1 / ×10 buttons (`Fullball/Features/PackOpening/PackOpeningView.swift`) — the red/coral pull buttons.
  - Any other cost shown on a coral/green/red fill (KICK OFF is on coral — set `onColor: true` there too).
  Costs shown on dark backgrounds (top bar, the Live card's dark "200" pill, slate refresh dark pill) keep the default tinted style.
- [ ] **Step 3: Build** → SUCCEEDED. Launch Scout (tab 0) + Market (tab 1), screenshots `/tmp/a_scout.png`, `/tmp/a_market.png`. Confirm costs are legible on the buttons. Report.
- [ ] **Step 4: Commit:** `fix: legible currency cost on colored buttons (white on-color variant)`.

### Task A2: rarity tag must not wrap
- [ ] **Step 1:** Screenshot 1 shows the "ICON" rarity pill wrapping to two lines ("ICO\nN"). Find the rarity tag/pill view (likely `RarityTag` in `Fullball/Features/Components/` or in `CardFace.swift`/`MarketView`). Add `.lineLimit(1)` + `.fixedSize(horizontal: true, vertical: false)` (and if needed `.minimumScaleFactor(0.8)`) so it never wraps. Check the Market row layout doesn't over-constrain its width — give the tag its intrinsic width.
- [ ] **Step 2: Build** → SUCCEEDED. Screenshot Market `/tmp/a_tag.png`; confirm "ICON" is one line. Report.
- [ ] **Step 3: Commit:** `fix: rarity tag never wraps to two lines`.

---

## PART B — Roster energy bars + sorting

### Task B1: Energy bar on each roster card tile
- [ ] **Step 1:** Read `Fullball/Features/Collection/` (the roster grid + `CollectionViewModel`) and `Fullball/Features/Components/CardFace.swift` (the `CardTile`). The roster needs each owned card's current energy. Add to `CollectionViewModel` an energy accessor using the injected container's `energy` service + `collection.instance(forCardID:)`:
```swift
    func energy(_ id: String) -> Int {
        guard let inst = collection.instance(forCardID: id) else { return EnergyRules.maxEnergy }
        return energyService.current(inst)
    }
```
(Inject `EnergyService` into the VM from the container the same way other services are.)
- [ ] **Step 2:** In the roster tile, add a thin energy bar pinned to the BOTTOM of each card (4pt capsule, same color tiers as the Live XI bar: coral <25%, gold <50%, green ≥50%). Compute pct from `vm.energy(card.id)`.
- [ ] **Step 3: Build** → SUCCEEDED. Launch tab 2, screenshot `/tmp/b_roster.png`. Confirm bottom energy bars. Report.
- [ ] **Step 4: Commit:** `feat: energy bar on roster card tiles`.

### Task B2: Sort by name or quality
- [ ] **Step 1:** Add a sort control to the roster header (a `Menu` or segmented control): options **Quality** (effective overall desc — current default) and **Name** (A→Z by displayName). Store `enum RosterSort { case quality, name }` on `CollectionViewModel` as a `var sort` and apply it to the `items`/grid source:
```swift
    var sortedItems: [OwnedCard] {
        switch sort {
        case .quality: return items.sorted { $0.effectiveStats.overall > $1.effectiveStats.overall }
        case .name:    return items.sorted { $0.card.displayName.localizedCaseInsensitiveCompare($1.card.displayName) == .orderedAscending }
        }
    }
```
Render the grid from `sortedItems`; respect any existing rarity/position filter (apply sort after filter).
- [ ] **Step 2: Build** → SUCCEEDED. Launch tab 2, screenshot `/tmp/b_sort.png`. Confirm a sort control + ordering changes. Report.
- [ ] **Step 3: Commit:** `feat: roster sort by quality or name`.

---

## PART D — Live match fixes

### Task D1: Fix Rep (and ensure all rewards) credited to the wallet
- [ ] **Step 1:** In `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift` `settle()`, Rep is earned (`pay.rep`) and added to the career counter via `score.award(points:formTokens:)` but is NEVER credited to the wallet balance (`wallet.formTokens` = the Rep shown in the top bar / spent in Rep Exchange). Add the wallet credit so earned Rep is visible:
```swift
        score.award(points: pay.points, formTokens: pay.rep)
        if pay.cash > 0 { wallet.credit(.coins, pay.cash) }
        if pay.rep > 0  { wallet.credit(.formTokens, pay.rep) }   // <-- add: Rep into the wallet
        if pay.wonBonus { wallet.credit(.tickets, LiveRules.winBonusTickets) }
        wallet.save()
```
Confirm against `ScoreBoard.award` (it only bumps `points`/`formTokensEarned`, no wallet credit) and `WalletService.credit`. Verify `Currency.formTokens` is the Rep balance the top bar reads.
- [ ] **Step 2: Build** → SUCCEEDED. Commit: `fix: credit earned Rep to the wallet after a tactics match`.

### Task D2: Playback UI — centered score, match clock, grouped rewards
- [ ] **Step 1:** In `Fullball/Features/LiveMatches/FutsalPitchView.swift`:
  - **Center the score.** Screenshot 3 shows "YOU POR" / score / "OPP GERMANY" misaligned. Use a 3-column layout where the center score is truly centered: `HStack { side(.leading); Spacer(); scoreText; Spacer(); side(.trailing) }` with both side blocks given equal frame width (`.frame(maxWidth: .infinity)`), or an overlay-centered score. Ensure the big score sits dead-center regardless of team-name lengths.
  - **Show a match clock.** Display a minute/progress readout that advances with `vm.minuteIndex` (map the 14 possessions onto 0–90′: `minute = Int(Double(vm.minuteIndex) / Double(possessionCount) * 90)`), e.g. `"\(minute)'"` near the score, and `"FULL TIME"` at the end. Add a `var clock: String`/`var minuteLabel: String` to the VM (read `result?.events.count` or `FutsalRules.possessionCount`).
  - **Group the full-time rewards onto one line that fits.** Screenshot 3's reward line wrapped/cropped. Render the payout as a single horizontal row of compact icon+amount chips that fits the width (e.g. `HStack(spacing:10){ chip(.coins, cash); chip(.formTokens, rep); chip points; if wonBonus chip(.tickets,1) }`), each using a small `CurrencyCost`-style icon+amount, with `.minimumScaleFactor(0.7)` / `.lineLimit(1)` so it never wraps to two lines. Points can be shown as "＋N pts".
- [ ] **Step 2: Build** → SUCCEEDED. (Driving into a match from CLI may be unavailable; at least confirm build + clean launch. If you can capture the pitch, screenshot `/tmp/d_pitch.png`.) Report.
- [ ] **Step 3: Commit:** `fix: center score, add match clock, group full-time rewards`.

---

## PART C — Positional drag field + off-position penalty

Replace the flat "select up to 5" strip with a **field preview of 5 positioned slots**; the player drags cards from a roster strip into slots. A player in a slot whose required position differs from the player's position plays at **0.5× stats**.

Slots (fixed futsal 1-2-1): index→required `Position`: `[.gk, .def, .mid, .mid, .fwd]`.

### Task C1: Off-position penalty (pure, tested)
**Files:** `Fullball/Domain/Economy/FutsalMatchSupport.swift` (add helper), `FullballTests/FutsalMatchSupportTests.swift`.
- [ ] **Step 1: Failing test** (add to the existing struct):
```swift
    @Test func offPositionHalvesStatsOnPositionDoesNot() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        let onPos = OffPosition.adjust(stats: s, playerPosition: .fwd, slot: .fwd)
        let offPos = OffPosition.adjust(stats: s, playerPosition: .fwd, slot: .def)
        #expect(onPos == s)
        #expect(offPos == Stats(pace: 40, shooting: 40, passing: 40, defending: 40))
    }
```
- [ ] **Step 2: Implement** (append to `FutsalMatchSupport.swift`):
```swift
/// 5-a-side slot shape and the off-position penalty. A player fielded in a slot
/// whose required position differs from their own plays at half effectiveness.
enum OffPosition {
    static let slots: [Position] = [.gk, .def, .mid, .mid, .fwd]
    static let penalty = 0.5

    static func adjust(stats: Stats, playerPosition: Position, slot: Position) -> Stats {
        guard playerPosition != slot else { return stats }
        func h(_ v: Int) -> Int { Int((Double(v) * penalty).rounded()) }
        return Stats(pace: h(stats.pace), shooting: h(stats.shooting),
                     passing: h(stats.passing), defending: h(stats.defending))
    }
}
```
- [ ] **Step 3:** Run tests → PASS. Commit: `feat: OffPosition 0.5x penalty for off-position fielding (pure)`.

### Task C2: VM — slot assignments drive the squad
**Files:** `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`.
- [ ] **Step 1:** Replace the flat selection with slot assignments. Add:
```swift
    let slots: [Position] = OffPosition.slots          // 5 slots
    var assignments: [String?] = Array(repeating: nil, count: 5)   // slotIndex -> cardID

    var assignedIDs: [String] { assignments.compactMap { $0 } }
    func assign(_ id: String, toSlot i: Int) {
        // remove the card from any slot it already occupies, then place it
        if let prev = assignments.firstIndex(of: id) { assignments[prev] = nil }
        assignments[i] = id
        if captainID == nil || !assignedIDs.contains(captainID!) { captainID = assignedIDs.first }
    }
    func clearSlot(_ i: Int) {
        if assignments[i] == captainID { captainID = nil }
        assignments[i] = nil
        if captainID == nil { captainID = assignedIDs.first }
    }
```
Keep `captainID`. Update `canKickOff` to `!assignedIDs.isEmpty && canAfford && !alreadyFinished`. Update `yourFieldedCount` → `assignedIDs.count`. Replace `selected` usage: in `kickOff()`/`settle()` drain use `assignedIDs`. Remove/replace the old `selected`/`toggle`/`maxPlayers` API.
- [ ] **Step 2: `buildHomeSide()` applies the off-position penalty per slot:**
```swift
    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        var inputs: [(id: String, position: Position, stats: Stats)] = []
        for (i, idOpt) in assignments.enumerated() {
            guard let id = idOpt, let oc = owned.first(where: { $0.id == id }) else { continue }
            let withEnergy = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: energy.current(oc.instance))
            let adjusted = OffPosition.adjust(stats: withEnergy, playerPosition: oc.card.player.position, slot: slots[i])
            // engine reads the player's own position; place them in the slot's position so GK/outfield split is correct
            inputs.append((id, slots[i], adjusted))
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: captainID)
    }
```
(Note: feeding `slots[i]` as the position keeps the engine's GK/outfield split aligned with the slot layout.) Update `myFieldedCards()` similarly for playback (return MatchPlayers from assignments, position = slot).
- [ ] **Step 3:** Add a view helper `func ownedForSelection() -> [OwnedCard]` (keep) and `func slotPlayer(_ i: Int) -> OwnedCard?` and `func isOffPosition(_ i: Int) -> Bool` (player at slot i exists and its position != slots[i]).
- [ ] **Step 4: Build** → SUCCEEDED. Commit: `feat: slot-based squad assignment in match VM`.

### Task C3: UI — field preview with drag-and-drop
**Files:** `Fullball/Features/LiveMatches/TacticsMatchView.swift`.
- [ ] **Step 1:** Replace the "YOUR SQUAD · Selected n/5" strip with:
  - A **field preview** (reuse the horizontal pitch look from `FutsalPitchView`): render the 5 slots at fixed points (GK near your goal, DEF/MID/MID/FWD spread forward). Each slot is a circle showing the required position label when empty; when filled, the player's `AvatarView` portrait + a small position label, and a **red "0.5×" badge** if `vm.isOffPosition(i)`. A "C" badge marks the captain. Each slot is a `.dropDestination(for: String.self) { ids, _ in if let id = ids.first { vm.assign(id, toSlot: i) }; return true }`. Tapping a filled slot sets captain; a long-press or an "x" clears it (`vm.clearSlot(i)`).
  - A **roster strip** below: horizontally scrolling `ownedForSelection()` as draggable avatar tiles (with energy bar + overall). Each is `.draggable(oc.id)` (String is Transferable) with a drag preview. Dim/markers for cards already assigned.
- [ ] **Step 2:** Keep the Intensity/Focus pickers + impact text below the field, and KICK OFF (`CurrencyCost(.coins, vm.entryFee, onColor: true)`), disabled unless `vm.canKickOff`. Show the off-position hint ("Off-position players play at 0.5×") when any slot is mismatched.
- [ ] **Step 3: Build** → SUCCEEDED. Launch, open a match if possible; screenshot `/tmp/c_setup.png`. (If drag can't be driven from CLI, at least confirm build + the field renders with 5 slots + roster strip.) Report what renders.
- [ ] **Step 4: Commit:** `feat: positional field with drag-to-field squad selection + off-position penalty`.

### Task C4: Verify
- [ ] Full test suite → PASS. Build → SUCCEEDED. Screenshot Live + (if reachable) setup. Report.

---

## Self-review (author)
- A: legible costs on colored buttons (white on-color variant) + rarity tag no-wrap. B: roster energy bars + name/quality sort. D: Rep credited to wallet (the reported missing reward), centered score, match clock, grouped non-wrapping rewards. C: 5-slot positional field, drag-to-assign, 0.5× off-position penalty (pure+tested), captain among assigned.
- Reward bug root cause confirmed in `settle()` (Rep never `wallet.credit(.formTokens,...)`); fix is additive and won't double-count (career counter via `score.award` is separate from the wallet balance).
- C replaces the flat `selected` API with slot `assignments`; all call sites (`kickOff`/`settle`/drain/playback) switch to `assignedIDs`. Engine GK/outfield split preserved by feeding the slot position.
- Order D-before-C avoids two agents editing the match VM concurrently.
