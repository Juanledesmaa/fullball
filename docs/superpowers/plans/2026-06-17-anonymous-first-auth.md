# Anonymous-First Auth Implementation Plan

> **For agentic workers:** implement task-by-task; build + test (64 baseline) green after each.

**Goal:** Remove the SIWA launch wall → anonymous-first auth with optional Apple linking; fix the uid-keyed container reset.

**Spec:** `docs/superpowers/specs/2026-06-17-anonymous-first-auth-design.md`

Test/build: pinned sim `id=392871BC-2A9F-4E1A-925D-2235BD1E5E04`. `xcodegen generate` after any file add. No Co-Authored-By trailer.

## Task 1 — Pure prompt policy + test (TDD)
- Create `Fullball/Domain/Economy/LinkPromptPolicy.swift`:
  ```swift
  enum LinkPromptPolicy {
      static func shouldPrompt(isAnonymous: Bool, alreadyPrompted: Bool, firstMilestoneReached: Bool) -> Bool {
          isAnonymous && !alreadyPrompted && firstMilestoneReached
      }
  }
  ```
- Test `FullballTests/LinkPromptPolicyTests.swift`: truth table (true only when anon & !prompted & milestone). Run → green.
- Commit.

## Task 2 — AuthService API
- `AuthUser` + `isAnonymous: Bool`.
- Protocol: `+ signInAnonymously() async throws`, `+ linkApple(authorization:rawNonce:) async throws`.
- `FirebaseAuthService`: implement both; map `isAnonymous` from `user.isAnonymous`. `linkApple` builds the OAuth Apple credential (reuse the existing nonce/credential code), calls `currentUser.link(with:)`; on `AuthErrorCode.credentialAlreadyInUse` call `Auth.auth().signIn(with:)` and map result. Update `currentUser`.
- `MockAuthService`: `signInAnonymously` sets a fake anon `AuthUser(uid:"anon", isAnonymous:true)`; `linkApple` flips to `isAnonymous:false`, displayName "Tester".
- Build green. Commit.

## Task 3 — Expose auth in AppContainer
- Add `let auth: any AuthService` to `AppContainer`; init param (default `MockAuthService()`); `bootstrap` takes `auth:` and stores it. `RootView` passes its `auth` instance into bootstrap.
- Build green. Commit.

## Task 4 — RootView anon-first + container reset
- Remove `SignInView` branch. `Group`: `if let container { MainTabView()… } else { ProgressView() }`.
- `.task(id: auth.currentUser?.uid)`: if `currentUser == nil` → `try? await auth.signInAnonymously()`; rebuild container when the built-for uid differs (track `@State builtUID`); set `container = nil` then bootstrap with `auth.currentUser?.uid` and `auth:`.
- Keep the seedDemo block + LoopIntro cover.
- Build green; launch on sim → lands in-game (not the wall). Commit.

## Task 5 — Navigator signal + soft prompt
- `Navigator` + `var linkPromptPending = false`.
- In the milestone-grant path (`LiveMatchesViewModel.grantMilestones`), after granting, if `LinkPromptPolicy.shouldPrompt(isAnonymous: container.auth.currentUser?.isAnonymous ?? false, alreadyPrompted: UserDefaults didPromptLink, firstMilestoneReached: true)` → set `navigator.linkPromptPending = true`. (VM needs `auth` + `navigator` — inject from container.)
- `MainTabView`: `.sheet(isPresented: bound to navigator.linkPromptPending)` → `LinkAccountView(mode: .prompt)`; on appear set `@AppStorage("didPromptLink") = true`.
- Build green. Commit.

## Task 6 — Link UI (LinkAccountView + Agencies section)
- New `Fullball/Features/Onboarding/LinkAccountView.swift`: shows status (Guest vs Linked) + `SignInWithAppleButton` when anon (reuse `auth.prepareAppleRequest` + `auth.linkApple`); "Later"/dismiss in `.prompt` mode. Error → friendly message; `credentialAlreadyInUse` → "Switched to your existing agency".
- `LeaderboardView`: add an account section at top rendering `LinkAccountView(mode: .inline)` (or equivalent) reading `container.auth`.
- Retire `SignInView` as a gate (delete if unused, or keep its button logic in `LinkAccountView`).
- `xcodegen generate`; build green; full test run (65 tests). Commit.

## Task 7 — Docs
- Update CLAUDE.md (current state: anon-first, no wall), ROADMAP (auth-invasiveness rework → done; note sign-out bug fixed), ARCHITECTURE (auth flow). Commit.
