# Anonymous-First Auth — Design

> Status: approved 2026-06-17. Replaces the mandatory Sign-in-with-Apple launch
> wall with anonymous-first auth: play instantly, optionally link an Apple ID
> later to preserve the agency across reinstall/devices. Also fixes the latent
> sign-out/account-switch container leak.

## Goal

Remove the first-launch SIWA wall (too invasive for a casual game) while keeping
a stable uid for the server-authoritative backend. Anonymous Firebase auth gives
zero-friction entry; Apple linking becomes optional and contextual.

See memory `fullball-auth-invasiveness`. Pairs with App Check (anon requests
still carry an App Check token) and the auth-only rules (anon users have a uid,
so `request.auth != null` passes).

## Decisions (locked)

1. **Anonymous-first**: auto anon sign-in on launch, no wall.
2. **Link surface**: an account section on the **Agencies** (leaderboard) screen.
3. **Soft prompt**: one-time, on the **first milestone reached**, if still anonymous.
4. No explicit "Sign out" button (YAGNI) — the uid-keyed container reset handles
   account switching generically.

## Architecture / flow

- **Launch**: if `auth.currentUser == nil`, call `signInAnonymously()`, then
  `AppContainer.bootstrap(uid:)`. Existing Apple-linked users skip anon and
  bootstrap as today.
- **Offline first launch**: anon sign-in needs network. On failure, bootstrap
  with `uid == nil` (local/mock services, fully playable offline) and retry anon
  when connectivity returns / on next launch. The game never blocks on auth.
- **Cloud save** is unchanged: it only needs *a* stable uid, which anon provides.

## `AuthService` API changes

- `AuthUser` gains `isAnonymous: Bool`.
- `+ func signInAnonymously() async throws`
- `+ func linkApple(authorization: ASAuthorization, rawNonce: String) async throws`
  - Links the Apple credential to the current anonymous user → **same uid, data
    preserved**, `isAnonymous` flips to false.
  - On Firebase `AuthErrorCode.credentialAlreadyInUse` (the Apple ID already owns
    an account): sign in to that existing account instead (**uid changes**),
    surfacing a "switched to your existing agency" message. The anon account's
    local data is abandoned (acceptable).
- Impls: `FirebaseAuthService` (real) + `MockAuthService` (previews/tests).
- `signOut()` stays in the protocol (used by the uid-reset path / future), but no
  UI entry is added now.

## `RootView` rework + latent-bug fix

- Remove the `SignInView` gate. The `Group` shows: `ProgressView` until a
  container exists, else `MainTabView`.
- `.task`: ensure a session — if `currentUser == nil`, `try? signInAnonymously()`;
  then bootstrap with `currentUser?.uid` (may be nil offline).
- **Container reset fix**: track the uid the current container was built for. When
  `currentUser?.uid` changes (link-to-existing, future sign-out), set
  `container = nil` and rebuild. Replaces the `guard container == nil` that never
  rebuilt. Kills the cross-account leak (memory note).
- `SignInView` is retired as a gate; the Apple button lives in the link surfaces.
  (Keep the file only if reused; otherwise delete.)

## Link UI

- **Agencies account section** (`LeaderboardView`): top section showing
  - anonymous → "Guest agency" + a `SignInWithAppleButton` ("Link Apple ID");
  - linked → "Linked · {displayName or 'Apple ID'}".
  Wires to `auth.linkApple`; on success refreshes; on `credentialAlreadyInUse`
  shows the switch message.
- **Soft prompt**: when the first milestone is granted AND `isAnonymous` AND not
  yet prompted (`@AppStorage("didPromptLink")`), present a one-time dismissible
  sheet "Save your agency — Link Apple ID" (Apple button + "Later"). The milestone
  path signals via `Navigator` (e.g. `navigator.linkPromptPending = true`);
  `MainTabView` presents the sheet and sets the AppStorage flag.

## Edge cases

- Existing Apple-linked TestFlight users: `currentUser` non-nil at launch → no
  anon, no prompt, Agencies shows linked.
- Anon → link new Apple ID: uid retained, data preserved.
- Anon → link Apple ID already in use: switch accounts (uid change → container
  rebuild), warn.
- App Check + anon: token issued regardless of auth; rules pass.

## Testing (pure-logic only, constraint #8)

- Extract the prompt decision into a pure predicate, e.g.
  `LinkPromptPolicy.shouldPrompt(isAnonymous:alreadyPrompted:firstMilestoneReached:) -> Bool`,
  and unit-test its truth table.
- Auth/Firebase wiring + views stay untested (no view/wiring tests). Nonce already
  covered.

## Components / files

- Modify: `Services/Auth/AuthService.swift` (protocol + `AuthUser.isAnonymous`),
  `Services/Auth/FirebaseAuthService.swift`, `Services/Auth/MockAuthService.swift`.
- Modify: `App/RootView.swift` (anon-first, uid-keyed container reset).
- Modify: `App/Navigator.swift` (`linkPromptPending` signal).
- Modify: `Features/Leaderboard/LeaderboardView.swift` (account section) — read its
  VM to wire `auth` + link action; add `auth` to the VM or pass via container.
- Modify: `Features/MainTabView.swift` (present the soft-prompt sheet).
- New: `Features/Onboarding/LinkAccountView.swift` (shared link sheet/section UI) —
  optional, or inline in the two surfaces.
- New: `Domain/.../LinkPromptPolicy.swift` (pure predicate) + test.
- `AppContainer`: expose `auth` so views/VMs can reach link actions (currently
  `auth` lives in `RootView` only). Add `let auth: any AuthService` to the
  container, injected by `RootView` at bootstrap.

## Out of scope

- Explicit sign-out UI, full Settings screen (separate roadmap item), account
  deletion, multi-provider linking beyond Apple.
