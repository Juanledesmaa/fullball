# Futsal Tactics Match — Phase 4 (Energy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Per-player energy — fielding in an active (tactics) match drains a player; tired players underperform (stat penalty already in `EnergyRules`); energy regenerates over real time; a **Gem refill** is the new premium sink. Energy bars surface on the Live XI; refill lives on Card Detail.

**Architecture:** `EnergyRules` (pure, already built+tested in P1: `applyPenalty`, `regen`, `drainPerMatch=20`, `captainExtraDrain=10`, `regenPerMinute=0.25`, `maxEnergy=100`, `penaltyThreshold=50`). Add two pure bits (drain-after-match, refill cost) with tests. Add `energy` + `lastEnergyUpdate` to the `CardInstance` `@Model`. New `EnergyService` (MainActor) does regen-on-read, post-match drain, and Gem refill via `WalletService`. Wire the penalty into `TacticsMatchViewModel.buildHomeSide`, drain on `settle()`. UI: energy bars on Live XI chips + a refill button on Card Detail.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, Swift Testing. No new deps.

**Conventions:** `xcodegen generate` after file add/remove. Sim by UDID. Test: `xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`. Build: same with `build`. Tests ONLY for pure logic (Task 1). Model/service/UI = build + manual verify.

**Existing facts:** `CardInstance{ @Attribute(.unique) cardID, level, stars, xp, copies, dateAcquired: Date }`. `AppContainer.schema = Schema([Wallet.self, CardInstance.self, BannerPity.self, LiveProgress.self, Lineup.self, MatchRecord.self])`. `WalletService.balance(_:Currency)/debit(_:_:)->Bool/credit/save`; `Currency.gems`. `CollectionService.owned()->[OwnedCard]`, `.instance(forCardID:)->CardInstance?`. `OwnedCard{ id, card, instance: CardInstance, effectiveStats: Stats }`. `RefreshRules.cost(forCount:)` is the existing escalating-Gem-sink pattern (in `Economy.swift`). `TacticsMatchViewModel.buildHomeSide()` builds `(id,position,stats)` from `oc.effectiveStats`; `settle()` runs after playback. `EnergyRules` lives in `Economy.swift`.

---

### Task 1: Pure energy drain + refill cost (tested)

**Files:**
- Modify: `Fullball/Domain/Economy/Economy.swift` (extend `EnergyRules`)
- Test: `FullballTests/EnergyRulesTests.swift` (add tests to the existing struct)

- [ ] **Step 1: Add failing tests** to the existing `struct EnergyRulesTests`:

```swift
    @Test func drainAfterMatchSubtractsBaseAndCaptainExtra() {
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: false) == 80)  // -20
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: true) == 70)   // -30
        #expect(EnergyRules.afterMatch(energy: 10, isCaptain: true) == 0)     // clamps at 0
    }

    @Test func refillCostIsProportionalToMissingEnergy() {
        #expect(EnergyRules.refillCost(currentEnergy: 100) == 0)              // full → free/no-op
        #expect(EnergyRules.refillCost(currentEnergy: 0) == EnergyRules.maxRefillGems)
        let half = EnergyRules.refillCost(currentEnergy: 50)
        #expect(half > 0 && half < EnergyRules.maxRefillGems)
    }
```

- [ ] **Step 2: Run tests → verify FAIL** (`afterMatch`/`refillCost` not found).

- [ ] **Step 3: Implement** — add to `enum EnergyRules` in `Economy.swift`:

```swift
    static let maxRefillGems = 60       // Gems to fully refill from empty

    /// Energy left after fielding in one match (captain works harder).
    static func afterMatch(energy: Int, isCaptain: Bool) -> Int {
        let drain = drainPerMatch + (isCaptain ? captainExtraDrain : 0)
        return max(0, energy - drain)
    }

    /// Gem cost to refill to full, proportional to the energy missing.
    static func refillCost(currentEnergy: Int) -> Int {
        let missing = max(0, maxEnergy - currentEnergy)
        return Int((Double(missing) / Double(maxEnergy) * Double(maxRefillGems)).rounded())
    }
```

- [ ] **Step 4: Run tests → verify PASS.**

- [ ] **Step 5: Commit.**
```bash
git add Fullball/Domain/Economy/Economy.swift FullballTests/EnergyRulesTests.swift
git commit -m "feat: EnergyRules.afterMatch + refillCost (pure)"
```

---

### Task 2: Energy fields on `CardInstance`

**Files:**
- Modify: `Fullball/Domain/Models/CardInstance.swift`

Build-only (SwiftData).

- [ ] **Step 1: Read** `CardInstance.swift`. Add two stored properties WITH DEFAULTS (lightweight migration; the model is already in `AppContainer.schema`, so no schema array change needed):

```swift
    var energy: Int = EnergyRules.maxEnergy
    var lastEnergyUpdate: Date = Date()
```

Keep the existing initializer working (new props default; do not add required params).

- [ ] **Step 2: Build** (`xcodegen generate` then build). Expected BUILD SUCCEEDED.

- [ ] **Step 3: Commit.**
```bash
git add Fullball/Domain/Models/CardInstance.swift
git commit -m "feat: energy + lastEnergyUpdate on CardInstance"
```

---

### Task 3: `EnergyService` (regen-on-read · drain · Gem refill)

**Files:**
- Create: `Fullball/Services/EnergyService.swift`
- Modify: `Fullball/App/AppContainer.swift` (construct + expose)

Build-only.

- [ ] **Step 1: Read** `Fullball/App/AppContainer.swift` to see how services are built/exposed (e.g. `let wallet`, `let collection`, the `init` body, and how a `ModelContext` is available). Read `WalletService.swift` and `CollectionService.swift` for exact signatures.

- [ ] **Step 2: Create `Fullball/Services/EnergyService.swift`:**

```swift
import Foundation
import SwiftData

/// Per-player energy: regenerates over real time, drains after active matches,
/// refillable for Gems. Reads/writes `CardInstance.energy` directly.
@MainActor
protocol EnergyService: AnyObject {
    /// Current energy with elapsed-time regen applied (and persisted).
    func current(_ instance: CardInstance) -> Int
    /// Drain the given fielded players after a match (captain drains more).
    func drainAfterMatch(fieldedIDs: [String], captainID: String?)
    /// Gem cost to refill this instance to full right now.
    func refillCost(_ instance: CardInstance) -> Int
    /// Refill to full for Gems. Returns false if unaffordable or already full.
    @discardableResult func refill(_ instance: CardInstance) -> Bool
}

@MainActor
final class DefaultEnergyService: EnergyService {
    private let context: ModelContext
    private let wallet: any WalletService
    private let collection: any CollectionService

    init(context: ModelContext, wallet: any WalletService, collection: any CollectionService) {
        self.context = context
        self.wallet = wallet
        self.collection = collection
    }

    func current(_ instance: CardInstance) -> Int {
        let minutes = Date().timeIntervalSince(instance.lastEnergyUpdate) / 60.0
        let regened = EnergyRules.regen(from: instance.energy, minutesElapsed: minutes)
        if regened != instance.energy {
            instance.energy = regened
            instance.lastEnergyUpdate = Date()
            try? context.save()
        }
        return instance.energy
    }

    func drainAfterMatch(fieldedIDs: [String], captainID: String?) {
        for id in fieldedIDs {
            guard let inst = collection.instance(forCardID: id) else { continue }
            _ = current(inst)  // settle regen first
            inst.energy = EnergyRules.afterMatch(energy: inst.energy, isCaptain: id == captainID)
            inst.lastEnergyUpdate = Date()
        }
        try? context.save()
    }

    func refillCost(_ instance: CardInstance) -> Int {
        EnergyRules.refillCost(currentEnergy: current(instance))
    }

    @discardableResult
    func refill(_ instance: CardInstance) -> Bool {
        let cost = refillCost(instance)
        guard cost > 0, wallet.debit(.gems, cost) else { return false }
        instance.energy = EnergyRules.maxEnergy
        instance.lastEnergyUpdate = Date()
        try? context.save()
        wallet.save()
        return true
    }
}
```

- [ ] **Step 3: Wire into `AppContainer`.** Add a stored `let energy: any EnergyService`. In `init`, after `wallet`/`collection` exist, construct:
```swift
        self.energy = DefaultEnergyService(context: context, wallet: wallet, collection: collection)
```
Match the real construction order/parameter names in the file. If the app uses a preview/mock container path, give it the same `DefaultEnergyService` (it works with any wallet/collection) — no separate mock needed unless a protocol-only path requires it.

- [ ] **Step 4: Build.** Expected BUILD SUCCEEDED.

- [ ] **Step 5: Commit.**
```bash
git add Fullball/Services/EnergyService.swift Fullball/App/AppContainer.swift
git commit -m "feat: EnergyService (regen/drain/Gem refill)"
```

---

### Task 4: Apply energy in the match (penalty + drain)

**Files:**
- Modify: `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`

Build-only.

- [ ] **Step 1:** Add an `EnergyService` dependency. In the VM, add `private let energy: any EnergyService` and set `self.energy = container.energy` in `init`.

- [ ] **Step 2: Apply the penalty in `buildHomeSide()`.** Change the input mapping so each fielded player's effective stats are reduced by their current energy:

```swift
    func buildHomeSide() -> MatchSide {
        let owned = collection.owned()
        let inputs: [(id: String, position: Position, stats: Stats)] = lineup.fielded().compactMap { id in
            guard let oc = owned.first(where: { $0.id == id }) else { return nil }
            let e = energy.current(oc.instance)
            let stats = EnergyRules.applyPenalty(to: oc.effectiveStats, energy: e)
            return (id, oc.card.player.position, stats)
        }
        return MatchSideAssembly.build(players: inputs, tactics: tactics, captainID: lineup.captainID)
    }
```
(Confirm `OwnedCard` exposes `.instance` — the map says it does. If `current(_:)` needs the `CardInstance`, use `oc.instance`.)

- [ ] **Step 3: Drain on settle.** In `settle()`, after rewards are awarded and persisted, add:
```swift
        energy.drainAfterMatch(fieldedIDs: lineup.fielded(), captainID: lineup.captainID)
```

- [ ] **Step 4: Build.** Expected BUILD SUCCEEDED.

- [ ] **Step 5: Commit.**
```bash
git add Fullball/Features/LiveMatches/TacticsMatchViewModel.swift
git commit -m "feat: apply energy penalty + post-match drain in tactics match"
```

---

### Task 5: Energy bars on the Live XI + scouting note

**Files:**
- Modify: `Fullball/Features/LiveMatches/LiveMatchesView.swift`
- Modify: `Fullball/Features/LiveMatches/LiveMatchesViewModel.swift`

Build + manual verify.

- [ ] **Step 1: Expose energy per fielded card on the Live VM.** Read `LiveMatchesViewModel.swift`; it has `collection` and now the container exposes `energy`. Add an injected `energy` service (set in init from the container or services it already receives) and:
```swift
    func energy(forCardID id: String) -> Int {
        guard let inst = collection.instance(forCardID: id) else { return EnergyRules.maxEnergy }
        return energyService.current(inst)
    }
```
(Use whatever the VM already holds; if it doesn't hold the container, add `energyService` to its init from the same site that constructs it — read `LiveMatchesView.init` / `RootView` to match injection. The VM already has `collection`, so prefer passing `EnergyService` alongside it.)

- [ ] **Step 2: Add an energy bar under each XI chip.** Read the chip/tile builder in `LiveMatchesView.swift` ("YOUR MATCHDAY XI" row showing Haru/Jin/Daichi). Under each tile add a thin bar:
```swift
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(WC.fill)
            Capsule().fill(energyColor(pct)).frame(width: geo.size.width * pct)
        }
    }
    .frame(height: 4)
```
where `pct = Double(vm.energy(forCardID: card.id)) / 100.0`, and add a helper:
```swift
    private func energyColor(_ pct: Double) -> Color { pct < 0.25 ? WC.coral : (pct < 0.5 ? WC.gold : WC.spectrum.first ?? WC.coral) }
```
(Use real WC tokens — confirm `WC.fill`, `WC.gold`, `WC.coral`; for the healthy color use an existing green-ish token if present, else `WC.gold`. Keep it simple.)

- [ ] **Step 3: Build + screenshot sanity.** Build, then:
```bash
SIM=392871BC-2A9F-4E1A-925D-2235BD1E5E04
APP=$(find ~/Library/Developer/Xcode/DerivedData/Fullball-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)
xcrun simctl install $SIM "$APP" && xcrun simctl launch $SIM com.juanledesma.Fulbo.app -seedDemo 1 -startTab 3 -didSeeIntro YES
sleep 4 && xcrun simctl io $SIM screenshot /tmp/energy_live.png
```
Confirm energy bars render under the XI chips. Report the screenshot path.

- [ ] **Step 4: Commit.**
```bash
git add Fullball/Features/LiveMatches/LiveMatchesView.swift Fullball/Features/LiveMatches/LiveMatchesViewModel.swift
git commit -m "feat: energy bars on Live matchday XI"
```

---

### Task 6: Gem refill on Card Detail

**Files:**
- Modify: the Card Detail feature view + view model under `Fullball/Features/CardDetail/`

Build + manual verify.

- [ ] **Step 1: Read** the CardDetail feature (`Fullball/Features/CardDetail/` — list files; find the view + VM and how it gets the `CardInstance`/`AppContainer`). Confirm how train/limit-break actions are presented (energy refill should match that button style).

- [ ] **Step 2: Add a refill control.** Show current energy and a refill button:
```swift
    HStack {
        Text("Energy \(energy)/100").font(WC.ui(13)).foregroundStyle(WC.sub)
        Spacer()
        Button { vm.refillEnergy() } label: {
            Label("\(refillCost)", systemImage: "bolt.fill").font(WC.ui(13))
        }
        .disabled(refillCost == 0 || !vm.canAffordRefill)
    }
```
Add to the CardDetail VM (reading its real shape): `energy`, `refillCost`, `canAffordRefill`, and `refillEnergy()` that calls `container.energy.refill(instance)` then refreshes. Use the real injection the VM already has.

- [ ] **Step 3: Build.** Expected BUILD SUCCEEDED. If CardDetail's architecture makes this invasive, STOP and report — the energy bars (Task 5) already make energy visible; refill placement can be reconsidered.

- [ ] **Step 4: Commit.**
```bash
git add -A && git commit -m "feat: Gem energy refill on Card Detail"
```

---

### Task 7: Verify

- [ ] **Step 1:** Full test suite (Task 1 added pure tests). `xcodegen generate` then test command → PASS, no regressions.
- [ ] **Step 2:** Build → BUILD SUCCEEDED.
- [ ] **Step 3:** Launch seeded demo (`-startTab 3`), screenshot `/tmp/p4_live.png`; confirm energy bars. Report screenshot + test count + build result.

---

## Self-review (author)

- **Spec §4 coverage:** energy 0–100 on CardInstance — Task 2; drain per match incl. captain extra — Task 1 (pure) + Task 4 (applied); tired→penalty via existing `applyPenalty` — Task 4; regen over real time — Task 3 (`current` regen-on-read); Gem refill sink — Task 1 (cost) + Task 3 (`refill`) + Task 6 (UI); energy visible — Task 5 (bars) + Task 6 (detail).
- **Scope decision (flagged):** energy applies to the **active rung only** (the tactics match drains + penalizes). The existing auto "ENTER" path is untouched — it resolves via nation scripted events, not your players' stats, so the penalty is irrelevant there and auto stays the unpunished floor. Documented intentionally; revisit if auto should also drain.
- **Placeholder scan:** UI tasks include real scaffold + explicit instruction to reconcile tokens/VM shape against actual files (CardDetail, LiveMatchesView). Pure task exact.
- **Type consistency:** `EnergyRules.afterMatch/refillCost/applyPenalty/regen` names consistent across Tasks 1/3/4; `EnergyService.current/drainAfterMatch/refillCost/refill` consistent across Tasks 3/4/5/6; `OwnedCard.instance` used in Task 4.
- **Migration:** new `CardInstance` props have defaults → lightweight migration; model already in schema.
```
