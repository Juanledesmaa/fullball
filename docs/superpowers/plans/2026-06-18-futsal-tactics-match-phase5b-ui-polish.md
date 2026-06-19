# Futsal Tactics Match — Phase 5B (UI rework + polish) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`. SwiftUI/UI tasks — verified by build + on-sim screenshot, not unit tests (per CLAUDE.md).

**Goal:** Make the feature look good and match the new model. (1) Live = active-only: drop the persistent Matchday XI + auto ENTER; each match you pick players per game and play. (2) Tactics board: per-match player selection (energy-gated) + the two simplified knobs with plain-English impact text. (3) Futsal playback: **horizontal** pitch, player circles show **card images**, **animated ball** that travels/bounces between players. (4) Card Detail: energy-restore explanation ("~4/hour, full in ~24h") + Gem icon on refill. (5) **Currency icons on every spend button** (styled like the top bar), not the generic red. (6) Roster: clear **multiple-copies** indicator. (7) Agencies: **rename your agency**.

**Conventions:** Sim by UDID `392871BC-2A9F-4E1A-925D-2235BD1E5E04`. `xcodegen generate` after add/remove. Build: `xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`. Theme via `WC` tokens (read `Theme.swift`). Screenshot: `xcrun simctl io <SIM> screenshot /tmp/x.png` after `xcrun simctl launch <SIM> com.juanledesma.Fulbo.app -seedDemo 1 -startTab N -didSeeIntro YES`.

**New-model facts (post-5A):** `Tactics{ intensity: Intensity, focus: Focus }`. `Intensity.allCases` (.conservative/.balanced/.aggressive) + `.displayName` + `.impact`. `Focus.allCases` (.defend/.balanced/.attack) + `.displayName` + `.impact`. `MatchSide{ players, tactics, captainID }`. `EnergyRules.maxEnergy=100`, `regenPerMinute=4/60`. `Currency` has `.symbol` (SF Symbol) + `.tint` (Color) + `.label` — used by the top wallet bar.

---

### Task 1: Reusable `CurrencyCost` label + button styling

**Files:**
- Create: `Fullball/Features/Components/CurrencyCost.swift`

- [ ] **Step 1: Read** how the top wallet bar renders a currency (search `Currency` usage in `Fullball/Features/Wallet/` and `SharedUI`/Components — find the icon+amount+tint pattern). Match it.

- [ ] **Step 2: Create a small view** that shows a currency icon + amount in the currency's tint, for use inside buttons:

```swift
import SwiftUI

/// A cost shown as the currency's icon + amount, tinted like the wallet bar.
/// Use inside spend buttons instead of a bare red number.
struct CurrencyCost: View {
    let currency: Currency
    let amount: Int
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: currency.symbol)
            Text("\(amount)")
        }
        .foregroundStyle(currency.tint)
        .font(WC.ui(14))
    }
}
```
Adapt property names (`symbol`/`tint`) to the real `Currency` API. If the wallet bar uses an asset image rather than SF Symbol, mirror that.

- [ ] **Step 3:** `xcodegen generate`, build → SUCCEEDED. Commit:
```bash
git add Fullball/Features/Components/CurrencyCost.swift
git commit -m "feat: reusable CurrencyCost label for spend buttons"
```

---

### Task 2: Live screen — drop Matchday XI + auto ENTER; single PLAY entry

**Files:**
- Modify: `Fullball/Features/LiveMatches/LiveMatchesView.swift`
- Modify: `Fullball/Features/LiveMatches/LiveMatchesViewModel.swift`

- [ ] **Step 1: Read** both files fully. Identify: the "YOUR MATCHDAY XI" section + "SET LINEUP" button, the per-match card footer with "ENTER · 200" (auto) and "MANAGE & PLAY", and the feed/earners UI driven by the auto path.

- [ ] **Step 2:** Remove from the view: the **"YOUR MATCHDAY XI"** section and its "SET LINEUP" button; the **"ENTER · 200"** auto button (and its `vm.enter(...)` call site); the live **feed/earners** rows that only the auto path populated. Keep the matchday hero (points/next reward), the slate refresh, and the match list.

- [ ] **Step 3:** The match card footer becomes a single primary action: **PLAY** → presents `TacticsMatchView` (existing `.fullScreenCover(item: $activeFixture)`). Rename the "MANAGE & PLAY" button to "PLAY" and make it the only action. If a match record is `finished`, show the result (score + points) instead of the button.

- [ ] **Step 4:** In `LiveMatchesViewModel`, leave the auto methods if removing them cascades, but stop calling them from the view; ensure `restore()` (finished-state display) and `slateID` still work. If `enter(...)`/feed handling is now fully unused, you may delete it for cleanliness (optional — only if it doesn't break compile).

- [ ] **Step 5:** Build → SUCCEEDED. Launch `-startTab 3`, screenshot `/tmp/live_rework.png`. Confirm: no Matchday XI section, each match card has a single PLAY button. Report what you see.

- [ ] **Step 6: Commit.**
```bash
git add -A
git commit -m "feat: Live active-only — drop Matchday XI + auto ENTER, single PLAY entry"
```

---

### Task 3: Tactics board — per-match player selection + simplified knobs w/ impact text

**Files:**
- Modify: `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`
- Modify: `Fullball/Features/LiveMatches/TacticsMatchView.swift`

- [ ] **Step 1: Per-match selection in the VM.** Add local match selection (NOT LineupService):
```swift
    var selected: [String] = []      // chosen card ids, max 5
    var captainID: String? = nil
    let maxPlayers = 5
    func toggle(_ id: String) {
        if let i = selected.firstIndex(of: id) { selected.remove(at: i); if captainID == id { captainID = selected.first } }
        else if selected.count < maxPlayers { selected.append(id); if captainID == nil { captainID = id } }
    }
    func setCaptain(_ id: String) { if selected.contains(id) { captainID = id } }
    var canKickOff: Bool { !selected.isEmpty && canAfford && !alreadyFinished }
```
Change `buildHomeSide()` to use `selected` (effective stats with energy penalty per chosen card) instead of `lineup.fielded()`. Change `settle()` drain to `energy.drainAfterMatch(fieldedIDs: selected, captainID: captainID, intensity: tactics.intensity)`. Expose `func ownedForSelection() -> [OwnedCard]` (all owned, sorted by overall/energy) and `func energy(_ id: String) -> Int`. Drop reliance on `lineup` for selection (you can keep the `lineup` reference unused or remove it).

- [ ] **Step 2: Selection UI in the setup view.** Above the tactics pickers, add a horizontally-scrolling (or grid) roster picker: each owned card as a small card-image tile with an energy bar; tap toggles selection (highlight + order badge), long-press/secondary sets captain (or a small "C" toggle on selected tiles). Show "Selected n/5". Use `AvatarView`/card portrait (read its real init from `Fullball/Features/Components/` — `AvatarView`/`CardPortraitFull`).

- [ ] **Step 3: Simplified tactics with impact text.** Replace the two raw pickers so each shows the selected option's `.impact` line under it:
```swift
    private func tacticRow<T: CaseIterable & Hashable>(_ title: String, _ all: [T], _ sel: T,
        _ name: KeyPath<T,String>, _ impact: KeyPath<T,String>, _ set: @escaping (T)->Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(WC.ui(12)).foregroundStyle(WC.sub)
            HStack { ForEach(Array(all), id: \.self) { v in chip(v[keyPath: name], v == sel) { set(v) } } }
            Text(sel[keyPath: impact]).font(WC.ui(12)).foregroundStyle(WC.sub).italic()
        }
    }
```
Use it for Intensity (`\.displayName`, `\.impact`) and Focus. Remove leftover formation/marker/counter UI if any remains.

- [ ] **Step 4: KICK OFF uses the currency icon.** Replace the bare "KICK OFF · 200" label with the cost rendered via `CurrencyCost(currency: .coins, amount: vm.entryFee)` beside a "KICK OFF" title; disable unless `vm.canKickOff`. Show a small note if a selected player is low-energy (e.g. "Some players are tired — they'll underperform").

- [ ] **Step 5:** Build → SUCCEEDED. Launch, open a match → screenshot the board `/tmp/board.png` (best-effort; if taps unavailable, at least confirm build + no crash). Report.

- [ ] **Step 6: Commit.**
```bash
git add -A
git commit -m "feat: per-match player selection + simplified tactics with impact text"
```

---

### Task 4: Futsal playback — horizontal pitch, card-image circles, animated ball

**Files:**
- Rewrite: `Fullball/Features/LiveMatches/FutsalPitchView.swift`

- [ ] **Step 1: Read** `AvatarView`/`CardPortraitFull` (in `Fullball/Features/Components/`) for the exact way to render a player's portrait from a card id (it uses `PlayerImageStore` via `\.playerImageStore` environment). Confirm how to get a card id → portrait.

- [ ] **Step 2: Horizontal pitch.** Rework the pitch so it's landscape-oriented within the portrait screen (wider than tall, e.g. `aspectRatio(1.6, contentMode: .fit)`), halves split LEFT (you) / RIGHT (opponent) with a center line. Place each team's GK near its end line and outfielders spread vertically in a forward column. Compute slot points accordingly (mirror the existing `slots` helper but along the X axis).

- [ ] **Step 3: Card-image circles.** Replace the placeholder circle (tag text) with the player's portrait clipped to a `Circle()` (44pt), rarity/ball-highlight ring overlay. For your side use the selected cards' ids; for the opponent use `vm.opponent.players` ids (catalog cards). Use the real `AvatarView` API; fall back to a position-tinted circle if no image.

- [ ] **Step 4: Animated ball.** Track the ball position as `@State var ballPoint: CGPoint`. On each `vm.step()` (event), animate the ball from its current point to the involved player's slot with motion that reads as a pass/shot:
  - For a shot/goal/miss/save: move ball to the shooter, then toward the attacked goal, with `withAnimation(.spring(response: 0.5, dampingFraction: 0.6))` and a brief scale "bounce".
  - For turnover: small nudge toward midfield.
  Drive via `.onChange(of: vm.minuteIndex)` recomputing `ballPoint` from `vm.lastEvent`. Keep it lightweight (no physics engine — spring animation + an arc offset is enough to feel alive).
- [ ] **Step 5: Full-time panel** stays (score + payout). Payout line should render costs/earnings clearly; earned currencies can use small icons too.

- [ ] **Step 6:** Build → SUCCEEDED. Launch a match if possible, screenshot `/tmp/pitch.png`. Report what renders (orientation, portraits, ball).

- [ ] **Step 7: Commit.**
```bash
git add -A
git commit -m "feat: horizontal pitch, card-image players, animated ball"
```

---

### Task 5: Card Detail — energy explanation + Gem icon on refill

**Files:**
- Modify: `Fullball/Features/CardDetail/CardDetailView.swift` (+ VM if needed)

- [ ] **Step 1:** In the energy panel added in P4, add an explanatory caption under the bar: `"Restores ~4 energy per hour (full in ~24h). Refill instantly with Gems."` (font `WC.ui(11)`, `WC.sub`).
- [ ] **Step 2:** Make the refill button show the Gem cost via `CurrencyCost(currency: .gems, amount: vm.refillCost)` instead of a plain number, matching the new style.
- [ ] **Step 3:** Build → SUCCEEDED. Commit:
```bash
git add -A
git commit -m "feat: energy regen explanation + Gem icon on Card Detail refill"
```

---

### Task 6: Currency icons on all spend buttons

**Files:**
- Modify: spend buttons across features (Scout/PackOpening, Market, LiveMatches slate refresh, Wallet, anywhere a cost is shown)

- [ ] **Step 1: Find every spend button.** `grep -rn` in `Fullball/Features` for cost/price labels and currency debits — e.g. pull buttons (`Scout`/`PackOpening`), transfer "Sign" (`Market`), slate "REFRESH MATCHES · 150" (`LiveMatchesView`), Rep exchange (`Wallet`), gem "buy" stub. List them.
- [ ] **Step 2:** Replace each bare/red cost with `CurrencyCost(currency: <the currency>, amount: <cost>)` (or the icon+amount inline), keeping the action title. Match the correct currency per button (single pull = Scouts/tickets, 10-pull = Gems, sign = Cash/coins, refresh = Gems, refill = Gems, kickoff = Cash). Keep buttons disabled+dimmed when unaffordable.
- [ ] **Step 3:** Build → SUCCEEDED. Launch each relevant tab (Scout=0, Market=1, Live=3), screenshot `/tmp/icons_scout.png`, `/tmp/icons_market.png`. Confirm icons render with correct tints. Report.
- [ ] **Step 4: Commit.**
```bash
git add -A
git commit -m "feat: currency icons on all spend buttons (match wallet bar)"
```

---

### Task 7: Roster — clear multiple-copies indicator

**Files:**
- Modify: the Collection/Roster grid tile (`Fullball/Features/Collection/`)

- [ ] **Step 1: Read** the Roster grid + tile view. Find where an owned card tile renders, and how copies are available (`CardInstance.copies`). 
- [ ] **Step 2:** When `copies > 0` (a card you own duplicates of), show a clear badge on the tile — e.g. a top-corner pill `"×\(copies + 1)"` (total owned incl. the base) or `"+\(copies)"`, styled with `WC` tokens, legible on the portrait. Pick the interpretation that matches how copies are used elsewhere (read `UpgradeRules.copiesForStar`/limit-break to confirm whether `copies` is extra-beyond-one). State your interpretation in the commit.
- [ ] **Step 3:** Build → SUCCEEDED. Launch `-startTab 2`, screenshot `/tmp/roster.png`. Confirm the copies badge appears on duplicated cards (the seeded demo may need a dup — if none, just confirm build + the badge code path). Report.
- [ ] **Step 4: Commit.**
```bash
git add -A
git commit -m "feat: roster multiple-copies badge"
```

---

### Task 8: Agencies — rename your agency

**Files:**
- Modify: `Fullball/Features/Leaderboard/` (the Agencies view + VM), and persistence for the name.

- [ ] **Step 1: Read** the Agencies/Leaderboard feature. Find how the player's own entry/name is shown (the map noted a "Guest agency" + Link button). Determine where to persist a custom agency name — prefer an existing store (e.g. a field on `LiveProgress`/profile, or `@AppStorage("agencyName")` if there's no obvious model). Read what the leaderboard uses for the player's display name.
- [ ] **Step 2:** Add an editable agency name: a pencil/Edit affordance near the player's row/header that presents a text field (alert with `TextField`, or a small sheet). On save, persist it and use it as the player's leaderboard display name. Keep a sensible default if empty.
- [ ] **Step 3:** If the leaderboard name is server-driven (Firestore) and wiring a write is invasive, persist locally (`@AppStorage`) and use it for the local display at minimum; note the limitation. Do NOT attempt a risky backend change without confirmation — local persistence is acceptable for this task.
- [ ] **Step 4:** Build → SUCCEEDED. Launch `-startTab 4`, screenshot `/tmp/agencies.png`. Confirm an edit affordance is present. Report.
- [ ] **Step 5: Commit.**
```bash
git add -A
git commit -m "feat: rename your agency on Agencies tab"
```

---

### Task 9: Final verification

- [ ] **Step 1:** Full test suite → PASS (UI changes shouldn't touch tests; confirm no regression).
- [ ] **Step 2:** Build → SUCCEEDED.
- [ ] **Step 3:** Launch and screenshot Live (`-startTab 3`) and, if possible, drive into a match to capture the horizontal pitch. Save `/tmp/final_live.png` (+ `/tmp/final_pitch.png` if reachable). Report all screenshot paths + test/build results.

---

## Self-review (author)
- Covers every feedback item: horizontal pitch + card images + ball animation (Task 4); remove Matchday XI + per-match selection (Tasks 2–3); simplified tactics w/ impact text incl. "aggressive tires more" (Task 3, model from 5A); card-detail energy regen text (Task 5); currency icons on all spend buttons (Tasks 1,3,5,6); roster copies badge (Task 7); agency rename (Task 8).
- UI tasks verified by build + screenshot, not unit tests (CLAUDE.md). Flags the two judgment calls (copies interpretation; agency-name persistence local vs server) for the implementer to resolve against real code and note.
```
