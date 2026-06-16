# Resume prompt

Paste this at the start of a new session to recover full context.

---

You're picking up **Fullball**, an iPhone football-agent game (SwiftUI, Swift 6
strict concurrency, iOS 17, MVVM via `@Observable`, SwiftData, XcodeGen, zero
third-party deps). Repo is at the current working directory; `main` has the full
MVP vertical slice.

**Read these first, in order — do not skip:**

1. `CLAUDE.md` — onboarding: what the app is, the 10 hard constraints, stack, build/run/test, dev launch args, structure, conventions, gotchas. **Start here.**
2. `docs/ROADMAP.md` — current state: what's done, what's stubbed (IAP/networking/auth), known rough edges, prioritized next steps. **Read before proposing work.**
3. `docs/GAMEPLAY.md` — the game loop + every balance constant and its file (tuning table). Read when touching economy/mechanics.
4. `docs/ARCHITECTURE.md` — MVVM layers, AppContainer, service map, SwiftData schema, determinism/seeding, tests. Read when touching code structure.

Then, before building anything:

- `xcodegen generate` (the `.xcodeproj` is gitignored — always regenerate).
- Build/test to confirm green:
  `xcodebuild test -project Fullball.xcodeproj -scheme Fullball -only-testing:FullballTests -destination 'platform=iOS Simulator,name=iPhone 15'`
  (41 tests, 8 suites — pure economy/gacha/generation only.)

**Must-honor constraints** (full list in CLAUDE.md): iPhone-only portrait · SwiftUI + `@Observable` MVVM (never `ObservableObject`) · Swift 6 strict concurrency · iOS 17 · **no real player likeness / names / kits / crests — fictional only** · virtual currency only · disclose gacha odds · zero third-party deps. **Workflow prefs: no "Co-Authored-By" trailer in commits; plans/design docs auto-approved; use context7 MCP to confirm current SwiftUI/SwiftData APIs.**

**Where things live**: balance constants → `Domain/Economy/Economy.swift` (+ `UpgradeRules`, `Rarity`, `Wallet.starter`). Composition root → `App/AppContainer.swift` (+ `schema` — add new `@Model`s there). Portraits → `Resources/Avatars/` via `AvatarView`/`AvatarAssets`. Catalog data → `tools/generate_catalog.py`.

**Open items**: rotate the api-football key (shared in old chat, not in repo); top next step is a StoreKit seam for the Gems buy button. See `docs/ROADMAP.md`.
