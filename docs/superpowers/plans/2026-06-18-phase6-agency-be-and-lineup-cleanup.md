# Phase 6 — Agency rename (backend) + Lineup dead-code cleanup

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Two independent parts. Build-verify (+ tests for any pure change). Run Part B (cleanup) FIRST, then Part A (BE) — both touch `AppContainer`; sequential avoids conflicts.

**Sim UDID** `392871BC-2A9F-4E1A-925D-2235BD1E5E04`. `xcodegen generate` after add/remove. Build: `xcodebuild build -project Fullball.xcodeproj -scheme Fullball -destination 'platform=iOS Simulator,id=392871BC-2A9F-4E1A-925D-2235BD1E5E04'`. Test: same with `test -only-testing:FullballTests`. Firebase is quarantined behind `Services/Auth` + `Services/Firestore` — NEVER import Firebase in Views/VMs.

---

## PART B (do first) — Remove dead Lineup code

The per-match selection rework made the persistent matchday lineup obsolete. Active uses to preserve: `LineupRules.captainMultiplier` (read by `FutsalReward`) and `MatchSide.captainID` (unaffected). `TacticsMatchViewModel` still injects `lineup` only for tactics persistence — drop that (tactics are per-match; default each match).

### Task B1: Move `captainMultiplier`, drop tactics-persistence from the VM
- [ ] **Step 1:** In `Fullball/Domain/Economy/Economy.swift`, add to `enum LiveRules`: `static let captainMultiplier = 2`.
- [ ] **Step 2:** In `Fullball/Domain/Economy/FutsalMatchSupport.swift`, change `LineupRules.captainMultiplier` → `LiveRules.captainMultiplier`.
- [ ] **Step 3:** In `Fullball/Features/LiveMatches/TacticsMatchViewModel.swift`: remove the `private let lineup: any LineupService` property, its `self.lineup = container.lineup` assignment, and the `tactics` `didSet { lineup.setTactics(...) }` persistence. Initialize `var tactics = Tactics()` (plain stored property, default balanced) instead of `container.lineup.tactics`. Confirm `selected`/`captainID` (already local) are untouched and `settle()`/`buildHomeSide()` still use them.
- [ ] **Step 4:** Build → SUCCEEDED (Part-B continues to remove files; intermediate build is a checkpoint).
- [ ] **Step 5:** Commit: `refactor: move captainMultiplier to LiveRules; drop lineup tactics persistence`.

### Task B2: Delete dead files + strip references
- [ ] **Step 1:** Delete:
```bash
git rm Fullball/Features/LiveMatches/LineupSheet.swift \
       Fullball/Services/LineupService.swift \
       Fullball/Domain/Models/Lineup.swift \
       FullballTests/LineupServiceTests.swift
```
- [ ] **Step 2:** `Fullball/App/AppContainer.swift`: remove the `let lineup: any LineupService` property, its `init` assignment (`self.lineup = SwiftDataLineupService(...)`), and remove `Lineup.self` from the `static let schema = Schema([...])` array. (Read the file; also check `bootstrap`/preview init paths for any `lineup` reference and remove.)
- [ ] **Step 3:** `Fullball/App/RootView.swift`: remove the demo-seed `lineup.toggleField(...)`/`lineup.count` block (lines ~70–74). The `-seedDemo` path should still acquire cards into the collection; just drop the lineup-fielding part.
- [ ] **Step 4:** `Fullball/Mocks/PreviewSupport.swift`: remove the `app.lineup.toggleField(...)` calls (~line 76). Keep the rest of preview seeding.
- [ ] **Step 5:** `grep -rn "LineupService\|LineupSheet\|SwiftDataLineupService\|\.lineup\|LineupRules\|Lineup(" Fullball FullballTests` → expect ZERO hits (other than maybe `LineupRules` if any lingering — there should be none after B1). Fix any stragglers.
- [ ] **Step 6:** `xcodegen generate`; build → SUCCEEDED; run tests → PASS (the LineupService test suite is gone; others green).
- [ ] **Step 7:** Launch the app on the sim and confirm it doesn't crash on launch (SwiftData store no longer declares `Lineup` — lightweight migration drops the entity):
```bash
SIM=392871BC-2A9F-4E1A-925D-2235BD1E5E04
APP=$(find ~/Library/Developer/Xcode/DerivedData/Fullball-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "*.app" | head -1)
xcrun simctl install $SIM "$APP" && xcrun simctl launch $SIM com.juanledesma.Fulbo.app -seedDemo 1 -startTab 3 -didSeeIntro YES
sleep 4 && xcrun simctl io $SIM screenshot /tmp/cleanup.png
```
Confirm clean launch (no crash). If it crashes with a SwiftData store mismatch, DELETE the app first (`xcrun simctl uninstall $SIM com.juanledesma.Fulbo.app`) then reinstall — a fresh store is acceptable for this pre-release. Report.
- [ ] **Step 8:** Commit: `chore: remove dead Lineup model/service/sheet/tests`.

---

## PART A (do second) — Persist agency name to Firestore

Make the rename write through the leaderboard service to `/leaderboard/{uid}.name` so other players see it, and seed it locally (`@AppStorage`) so it survives relaunch. Rules already permit own-doc writes; DTO already has `name` — NO rules/DTO change needed.

### Task A1: Service — mutable name + `updateName`
- [ ] **Step 1:** `Fullball/Services/LeaderboardService.swift` — add to the protocol:
```swift
    func updateName(_ name: String, userPoints: Int) async
```
- [ ] **Step 2:** `FirestoreLeaderboardService` — change `let currentUserName` to `private(set) var currentUserName`. Implement:
```swift
    func updateName(_ name: String, userPoints: Int) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentUserName = trimmed
        UserDefaults.standard.set(trimmed, forKey: "agencyName")
        do {
            try await client.putLeaderboardEntry(uid: uid, name: trimmed, points: userPoints)
            await refresh(userPoints: userPoints)
        } catch { print("updateName failed: \(error as NSError)") }
    }
```
- [ ] **Step 3:** `MockLeaderboardService` — make it conform: change to a `final class` (or add mutability) with `private(set) var currentUserName` and:
```swift
    func updateName(_ name: String, userPoints: Int) async {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { currentUserName = t; UserDefaults.standard.set(t, forKey: "agencyName") }
    }
```
(If switching Mock from struct→class, update its construction sites accordingly.)
- [ ] **Step 4:** Build → SUCCEEDED. Commit: `feat: LeaderboardService.updateName persists agency name to Firestore`.

### Task A2: Bootstrap seeds the stored name
- [ ] **Step 1:** `Fullball/App/AppContainer.swift` — where `displayName` is computed (`let displayName = (userName?.isEmpty == false ? userName! : "Agent \(uid.prefix(4))")`), prefer a stored agency name first:
```swift
    let stored = UserDefaults.standard.string(forKey: "agencyName")
    let displayName = (stored?.isEmpty == false ? stored!
                       : (userName?.isEmpty == false ? userName! : "Agent \(uid.prefix(4))"))
```
- [ ] **Step 2:** Build → SUCCEEDED. Commit: `feat: seed leaderboard name from stored agency name on launch`.

### Task A3: View/VM use the service (drop local-only override)
- [ ] **Step 1:** `Fullball/Features/Leaderboard/LeaderboardViewModel.swift` — add:
```swift
    var currentName: String { service.currentUserName }
    func updateName(_ name: String) async {
        await service.updateName(name, userPoints: score.points)
    }
```
- [ ] **Step 2:** `Fullball/Features/Leaderboard/LeaderboardView.swift`:
  - Remove the `@AppStorage("agencyName")` property and the `displayName = ... agencyName ...` override; just display `entry.userName` (it now carries the custom name for the current user after `refresh`).
  - In the rename alert Save button, call the service: `Task { await vm.updateName(trimmed) }`. Pre-fill the text field with `vm.currentName`. Update the alert message to drop "(local display only)".
  - Trigger a `await vm.refresh()` after rename if the list doesn't auto-update (the VM reads `service.standings` which includes the renamed current-user entry).
- [ ] **Step 3:** `xcodegen generate`; build → SUCCEEDED. Launch `-startTab 4`, screenshot `/tmp/agency_be.png`; confirm the edit affordance + that a saved name shows on the user row. Report. (Firestore write needs a signed-in session/`GoogleService-Info.plist`; if running without it, the write path no-ops gracefully via the catch — the local `@AppStorage` seed still updates the name. Note this.)
- [ ] **Step 4:** Commit: `feat: agency rename writes through service (Firestore-backed)`.

### Task A4: Verify
- [ ] Full test suite → PASS. Build → SUCCEEDED. Report results + screenshot.

---

## Self-review (author)
- Agency name now persists to `/leaderboard/{uid}.name` (BE-visible to other players) + `@AppStorage` seed for instant cross-session display; rules/DTO already supported it (no change). — Part A.
- Dead Lineup code removed (`LineupSheet`, `LineupService`, `Lineup` @Model, its tests); `captainMultiplier` moved to `LiveRules`; tactics persistence dropped (per-match default). Schema no longer declares `Lineup`. — Part B.
- Risk flagged: removing a `@Model` from the schema can mismatch an existing on-device store → uninstall/reinstall fixes (acceptable pre-release). Part-B Step B2.7 verifies clean launch.
- Order: Part B before Part A (both edit `AppContainer`; sequential).
