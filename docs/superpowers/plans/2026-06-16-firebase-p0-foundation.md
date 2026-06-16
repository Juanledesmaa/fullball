# Firebase P0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Firebase (Auth + Firestore) to Fullball and gate the app behind Sign in with Apple, with the dependency quarantined behind a new `AuthService` protocol and a thin `FirestoreClient` wrapper — no ViewModel/View changes beyond a new sign-in screen.

**Architecture:** Firebase is initialized once at app launch (`FirebaseApp.configure()`). A new `AuthService` protocol abstracts Sign in with Apple → Firebase credential exchange; `FirebaseAuthService` implements it, `MockAuthService` backs previews. `RootView` owns the auth state and shows `SignInView` until a user is authenticated, only then building `AppContainer` + `MainTabView`. A `FirestoreClient` wrapper (used heavily in P1–P5) is introduced minimally here with offline persistence enabled. Cloud data sync is **not** part of P0 — that is P1.

**Tech Stack:** Swift 6 (strict concurrency `complete`), SwiftUI, iOS 17, Firebase iOS SDK 11.x (FirebaseAuth + FirebaseFirestore), `AuthenticationServices` (`SignInWithAppleButton`), `CryptoKit` (nonce SHA256), XcodeGen.

**Testing note (project rule):** Per [CLAUDE.md](../../../CLAUDE.md), tests cover only deterministic economy/gacha/generation logic — **no view/navigation/Firebase-wiring tests**. P0 is almost entirely wiring, so only the pure `Nonce` utility is unit-tested (TDD). Every other task ends in a **build-verify**, not a test. This is intentional and overrides the writing-plans default of a test per task.

---

## Manual prerequisites (human, before any code task)

These cannot be automated from the repo. Do them first; the app will crash at launch (`FirebaseApp.configure()` with no plist) until Task 0 is complete.

- [ ] **Create a Firebase project** at <https://console.firebase.google.com> (e.g. "Fullball").
- [ ] **Register an iOS app** in it with bundle id **`com.juanledesma.Fulbo.app`** (must match `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`).
- [ ] **Download `GoogleService-Info.plist`** from that app's settings.
- [ ] In Firebase console → **Authentication → Sign-in method**, enable **Apple**.
- [ ] In Firebase console → **Firestore Database**, create a database in **production mode** (rules locked; we open per-user rules in later phases).
- [ ] In the **Apple Developer** portal, ensure the App ID `com.juanledesma.Fulbo.app` has the **Sign in with Apple** capability enabled (Task 1 adds the matching entitlement file).

> Free **Spark** plan is sufficient for all of P0–P5 as specced. No billing required.

---

## File structure (P0)

- Create: `Fullball/Fullball.entitlements` — Sign in with Apple capability.
- Manual/gitignored: `Fullball/GoogleService-Info.plist` — Firebase config (secrets; never commit).
- Modify: `.gitignore` — ignore `GoogleService-Info.plist`.
- Modify: `project.yml` — Firebase SPM packages, target deps, entitlements, plist in sources.
- Modify: `Fullball/App/FullballApp.swift` — `FirebaseApp.configure()` + Firestore offline persistence.
- Create: `Fullball/Services/Auth/AuthService.swift` — `AuthService` protocol + `AuthUser` value type.
- Create: `Fullball/Services/Auth/Nonce.swift` — pure nonce generation + SHA256 (the only tested unit).
- Create: `Fullball/Services/Auth/FirebaseAuthService.swift` — SIWA → Firebase credential exchange.
- Create: `Fullball/Services/Auth/MockAuthService.swift` — preview/test backing.
- Create: `Fullball/Services/Firestore/FirestoreClient.swift` — thin Firestore wrapper.
- Create: `Fullball/Features/Onboarding/SignInView.swift` — `SignInWithAppleButton` screen.
- Modify: `Fullball/App/RootView.swift` — auth gate before `AppContainer`/`MainTabView`.
- Create: `FullballTests/NonceTests.swift` — unit tests for the nonce utility.

---

## Task 1: Firebase SPM, entitlements, gitignore (project.yml)

**Files:**
- Modify: `project.yml`
- Create: `Fullball/Fullball.entitlements`
- Modify: `.gitignore`

- [ ] **Step 1: Add Sign in with Apple entitlement file**

Create `Fullball/Fullball.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Add Firebase package + target deps + entitlements to `project.yml`**

Add a top-level `packages:` block (after the `settings:` block, before `targets:`):

```yaml
packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk
    from: "11.0.0"
```

In the `Fullball` target, add `dependencies:` and `CODE_SIGN_ENTITLEMENTS` to its `settings.base`. The target block becomes:

```yaml
  Fullball:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Fullball
    dependencies:
      - package: Firebase
        product: FirebaseAuth
      - package: Firebase
        product: FirebaseFirestore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.juanledesma.Fulbo.app
        TARGETED_DEVICE_FAMILY: "1"   # iPhone only (target-level overrides the universal default)
        CODE_SIGN_ENTITLEMENTS: Fullball/Fullball.entitlements
        INFOPLIST_KEY_CFBundleDisplayName: Fullball Manager
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
        INFOPLIST_KEY_UIStatusBarStyle: UIStatusBarStyleDefault
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
```

> `GoogleService-Info.plist` lives under `Fullball/`, which is already a source path, so XcodeGen bundles it automatically once present. No extra `sources` entry needed.

- [ ] **Step 3: Gitignore the Firebase secrets plist**

Add to `.gitignore` (under a new section):

```
# Firebase config (secrets — never commit; each dev downloads from console)
Fullball/GoogleService-Info.plist
```

- [ ] **Step 4: Place the plist and regenerate the project**

Copy the `GoogleService-Info.plist` downloaded in the manual prerequisites into `Fullball/GoogleService-Info.plist`, then:

Run: `xcodegen generate`
Expected: `Created project at .../Fullball.xcodeproj` with no errors.

- [ ] **Step 5: Resolve packages and build (first Firebase fetch is slow)**

Run:
```bash
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16' -resolvePackageDependencies
```
Expected: Firebase and its transitive packages (abseil, GoogleUtilities, gRPC, leveldb, nanopb, etc.) resolve. Then a full build:
```bash
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **` (app code unchanged yet; this only proves Firebase links).

- [ ] **Step 6: Commit**

```bash
git add project.yml Fullball/Fullball.entitlements .gitignore
git commit -m "P0: add Firebase SPM (Auth+Firestore) + Sign in with Apple entitlement"
```

---

## Task 2: Nonce utility (pure, TDD)

The only unit-tested code in P0. Sign in with Apple requires a random nonce sent SHA256-hashed to Apple, with the raw nonce handed to Firebase. `randomNonceString` must produce the right length and a URL-safe charset; `sha256` must be deterministic.

**Files:**
- Create: `Fullball/Services/Auth/Nonce.swift`
- Test: `FullballTests/NonceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `FullballTests/NonceTests.swift`:

```swift
import Testing
import Foundation
@testable import Fullball

struct NonceTests {
    @Test func randomNonceHasRequestedLength() {
        #expect(Nonce.randomNonceString(length: 32).count == 32)
        #expect(Nonce.randomNonceString(length: 16).count == 16)
    }

    @Test func randomNonceUsesURLSafeCharset() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = Nonce.randomNonceString(length: 64)
        #expect(nonce.allSatisfy { allowed.contains($0) })
    }

    @Test func randomNoncesDiffer() {
        #expect(Nonce.randomNonceString() != Nonce.randomNonceString())
    }

    @Test func sha256IsDeterministicAndKnown() {
        // Precomputed SHA256 of "abc".
        #expect(Nonce.sha256("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project Fullball.xcodeproj -scheme Fullball \
  -only-testing:FullballTests/NonceTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: FAIL — `cannot find 'Nonce' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Fullball/Services/Auth/Nonce.swift`:

```swift
import Foundation
import CryptoKit

/// Pure helpers for the Sign in with Apple nonce. A random nonce is sent to
/// Apple SHA256-hashed; the raw nonce is later handed to Firebase to prove the
/// credential was minted for this request. No Firebase/Apple types here so it
/// stays unit-testable.
enum Nonce {
    private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    /// A cryptographically-random nonce of `length` URL-safe characters.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            precondition(status == errSecSuccess, "Unable to generate secure random bytes")
            if random < charset.count {            // avoid modulo bias
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    /// Lowercase hex SHA256 of `input` — the form Apple expects for the nonce.
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
```

> Charset is 64 chars, so `random < charset.count` (random < 64) keeps the distribution unbiased over a `UInt8`.

- [ ] **Step 4: Regenerate (new file) and run the test**

Run:
```bash
xcodegen generate
xcodebuild test -project Fullball.xcodeproj -scheme Fullball \
  -only-testing:FullballTests/NonceTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Fullball/Services/Auth/Nonce.swift FullballTests/NonceTests.swift
git commit -m "P0: pure Sign in with Apple nonce utility (+ tests)"
```

---

## Task 3: AuthService protocol + value type + mock

Abstracts authentication so ViewModels/Views never see Firebase. P0 only needs current-user + sign-in-with-Apple + sign-out.

**Files:**
- Create: `Fullball/Services/Auth/AuthService.swift`
- Create: `Fullball/Services/Auth/MockAuthService.swift`

- [ ] **Step 1: Write the protocol + value type**

Create `Fullball/Services/Auth/AuthService.swift`:

```swift
import Foundation
import AuthenticationServices

/// The authenticated player, abstracted away from Firebase's `User`.
struct AuthUser: Equatable, Sendable {
    let uid: String
    let displayName: String?
}

/// Authentication seam. ViewModels/Views depend on this, never on Firebase.
@MainActor
protocol AuthService: AnyObject {
    /// The currently signed-in user, or nil. Observable so the UI can gate on it.
    var currentUser: AuthUser? { get }

    /// Configure an `ASAuthorizationAppleIDRequest` with the scopes + hashed
    /// nonce. Returns the raw nonce to retain until the credential comes back.
    @discardableResult
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String

    /// Exchange a completed Apple authorization for a Firebase session.
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws

    func signOut() throws
}
```

- [ ] **Step 2: Write the mock (for previews/tests)**

Create `Fullball/Services/Auth/MockAuthService.swift`:

```swift
import Foundation
import AuthenticationServices

/// In-memory auth for previews. Starts signed-in so screens render.
@MainActor
@Observable
final class MockAuthService: AuthService {
    var currentUser: AuthUser?

    init(signedIn: Bool = true) {
        currentUser = signedIn ? AuthUser(uid: "preview-uid", displayName: "Preview Agent") : nil
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String { "mock-nonce" }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        currentUser = AuthUser(uid: "preview-uid", displayName: "Preview Agent")
    }

    func signOut() throws { currentUser = nil }
}
```

- [ ] **Step 3: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Fullball/Services/Auth/AuthService.swift Fullball/Services/Auth/MockAuthService.swift
git commit -m "P0: AuthService protocol + AuthUser + MockAuthService"
```

---

## Task 4: FirebaseAuthService (SIWA → Firebase credential)

Concrete `AuthService` backed by FirebaseAuth. `@Observable` so `currentUser` drives the gate; seeded from `Auth.auth().currentUser` at init and updated on sign-in/out.

**Files:**
- Create: `Fullball/Services/Auth/FirebaseAuthService.swift`

- [ ] **Step 1: Write the implementation**

Create `Fullball/Services/Auth/FirebaseAuthService.swift`:

```swift
import Foundation
import AuthenticationServices
import FirebaseAuth

/// Firebase-backed authentication. Quarantines FirebaseAuth behind `AuthService`.
@MainActor
@Observable
final class FirebaseAuthService: AuthService {
    var currentUser: AuthUser?

    init() {
        currentUser = Self.map(Auth.auth().currentUser)
    }

    @discardableResult
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String {
        let rawNonce = Nonce.randomNonceString()
        request.requestedScopes = [.fullName]
        request.nonce = Nonce.sha256(rawNonce)
        return rawNonce
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        guard
            let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = appleCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.missingAppleToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName)

        let result = try await Auth.auth().signIn(with: credential)
        currentUser = Self.map(result.user)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }

    private static func map(_ user: User?) -> AuthUser? {
        user.map { AuthUser(uid: $0.uid, displayName: $0.displayName) }
    }
}

enum AuthError: Error { case missingAppleToken }
```

- [ ] **Step 2: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **`. (If `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` is unavailable on the resolved Firebase version, use `OAuthProvider.credential(providerID: AuthProviderID.apple, idToken: idToken, rawNonce: rawNonce)` — same result.)

- [ ] **Step 3: Commit**

```bash
git add Fullball/Services/Auth/FirebaseAuthService.swift
git commit -m "P0: FirebaseAuthService — Sign in with Apple credential exchange"
```

---

## Task 5: FirestoreClient wrapper (minimal) + Firebase init

`FirestoreClient` is the single Firestore entry point later phases build on; P0 introduces it minimally and enables offline persistence. Firebase is configured once at app launch.

**Files:**
- Create: `Fullball/Services/Firestore/FirestoreClient.swift`
- Modify: `Fullball/App/FullballApp.swift`

- [ ] **Step 1: Write the FirestoreClient wrapper**

Create `Fullball/Services/Firestore/FirestoreClient.swift`:

```swift
import Foundation
import FirebaseFirestore

/// Thin wrapper over Firestore. The single place the rest of the app reaches
/// the database; later phases add typed read/write helpers here. Offline
/// persistence is on by default in the Firebase SDK, set explicitly for clarity.
@MainActor
final class FirestoreClient {
    let db: Firestore

    init() {
        let store = Firestore.firestore()
        let settings = store.settings
        settings.cacheSettings = PersistentCacheSettings()   // offline persistence
        store.settings = settings
        self.db = store
    }

    /// Per-user document root: `users/{uid}`.
    func userDoc(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }
}
```

- [ ] **Step 2: Configure Firebase at launch**

Modify `Fullball/App/FullballApp.swift` to configure Firebase before the model container. New file contents:

```swift
import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FullballApp: App {
    let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
        do {
            modelContainer = try ModelContainer(for: AppContainer.schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
```

> `FirebaseCore` is pulled in transitively by FirebaseAuth/FirebaseFirestore; no extra `project.yml` product needed for `FirebaseApp.configure()`.

- [ ] **Step 3: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Fullball/Services/Firestore/FirestoreClient.swift Fullball/App/FullballApp.swift
git commit -m "P0: FirestoreClient wrapper + FirebaseApp.configure at launch"
```

---

## Task 6: SignInView (Sign in with Apple button)

The gate UI. Uses SwiftUI's `SignInWithAppleButton`, wiring the request nonce and the completion through `AuthService`.

**Files:**
- Create: `Fullball/Features/Onboarding/SignInView.swift`

- [ ] **Step 1: Write the view**

Create `Fullball/Features/Onboarding/SignInView.swift`:

```swift
import SwiftUI
import AuthenticationServices

/// First-launch gate. Players must sign in with Apple before the game loads
/// (server-authoritative backend needs a stable identity). Themed via `WC`.
struct SignInView: View {
    let auth: any AuthService

    @State private var rawNonce: String?
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            WC.screenBG.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("Fullball Manager")
                    .font(WC.display(34))
                    .foregroundStyle(WC.inkText)
                Text("Sign in to sync your agency across devices.")
                    .font(WC.ui(15))
                    .foregroundStyle(WC.subText)
                    .multilineTextAlignment(.center)
                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    rawNonce = auth.prepareAppleRequest(request)
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let errorMessage {
                    Text(errorMessage)
                        .font(WC.ui(13))
                        .foregroundStyle(WC.coral)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let rawNonce else {
                errorMessage = "Sign-in request expired. Try again."
                return
            }
            Task {
                do {
                    try await auth.signInWithApple(authorization: authorization, rawNonce: rawNonce)
                } catch {
                    errorMessage = "Couldn't sign in. Try again."
                }
            }
        case .failure:
            // User cancellations land here too — stay silent unless it's worth surfacing.
            errorMessage = nil
        }
    }
}

#Preview {
    SignInView(auth: MockAuthService(signedIn: false))
}
```

> Verify the `WC` token names (`screenBG`, `inkText`, `subText`, `coral`, `display(_:)`, `ui(_:)`) against [Theme.swift](../../../Fullball/Features/Components/Theme.swift) before building; use the exact existing names. If a token is missing, reuse the closest existing one rather than hardcoding hex (per CLAUDE.md theme rule).

- [ ] **Step 2: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Fullball/Features/Onboarding/SignInView.swift
git commit -m "P0: SignInView — Sign in with Apple gate screen"
```

---

## Task 7: RootView auth gate

`RootView` owns the `AuthService` and shows `SignInView` until authenticated; only then does it build `AppContainer` and `MainTabView`. The existing intro cover and demo-seed logic are preserved, moved behind the auth gate.

**Files:**
- Modify: `Fullball/App/RootView.swift`

- [ ] **Step 1: Rewrite RootView with the gate**

Replace the contents of `Fullball/App/RootView.swift`:

```swift
import SwiftUI
import SwiftData

/// Gates the app behind Sign in with Apple, then builds the `AppContainer`
/// from the environment model context and shows the tab shell.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth: any AuthService = FirebaseAuthService()
    @State private var container: AppContainer?
    @AppStorage("didSeeIntro") private var didSeeIntro = false

    var body: some View {
        Group {
            if auth.currentUser == nil {
                SignInView(auth: auth)
            } else if let container {
                MainTabView()
                    .environment(container)
                    .fullScreenCover(isPresented: Binding(
                        get: { !didSeeIntro },
                        set: { if $0 { didSeeIntro = false } })) {
                        LoopIntroView { didSeeIntro = true }
                    }
            } else {
                ProgressView().tint(WC.coral)
            }
        }
        .task(id: auth.currentUser?.uid) {
            guard auth.currentUser != nil, container == nil else { return }
            let c = await AppContainer.bootstrap(context: modelContext,
                                                 loader: FullballConfig.catalogLoader)
            // Launch-arg demo seed for UI verification only (`-seedDemo 1`).
            if UserDefaults.standard.bool(forKey: "seedDemo"), c.collection.owned().isEmpty {
                let seeded = Array(c.catalog.cards.prefix(14))
                for card in seeded { c.collection.acquire(cardID: card.id) }
                // Own + field clients from the first live match's nations
                // so the earners row is populated for the demo.
                if let first = c.slate.fixtures.first(where: { $0.status == .live }) {
                    let picks = c.catalog.cards.filter {
                        $0.player.nationTag == first.homeTag || $0.player.nationTag == first.awayTag
                    }.prefix(3)
                    for card in picks {
                        c.collection.acquire(cardID: card.id)
                        c.lineup.toggleField(card.id)
                    }
                }
                if c.lineup.count == 0 {
                    for card in seeded.prefix(3) { c.lineup.toggleField(card.id) }
                }
            }
            container = c
        }
    }
}
```

> `@State private var auth: any AuthService = FirebaseAuthService()` constructs `FirebaseAuthService` on the main actor (the View `body`/init is `@MainActor`), which is required since the service is `@MainActor`. The `.task(id:)` re-runs when the uid appears, building the container exactly once.

- [ ] **Step 2: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Fullball.xcodeproj -scheme Fullball \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Full test run (regression — confirm the 42 + 4 nonce tests pass)**

Run:
```bash
xcodebuild test -project Fullball.xcodeproj -scheme Fullball \
  -only-testing:FullballTests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```
Expected: `** TEST SUCCEEDED **`, 46 tests pass (42 existing + 4 nonce).

- [ ] **Step 4: Manual launch verification (human — requires real device or signed sim)**

Sign in with Apple needs an iCloud-signed simulator or device. On a booted sim signed into an Apple ID:
```bash
xcrun simctl install <udid> "$(find ~/Library/Developer/Xcode/DerivedData/Fullball-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)"
xcrun simctl launch <udid> com.juanledesma.Fulbo.app
```
Expected: app shows `SignInView`; tapping "Sign in with Apple" presents the Apple sheet; on success the gate falls through to the game. (If the sim isn't signed into iCloud, the sheet errors — verify on a device.)

- [ ] **Step 5: Commit**

```bash
git add Fullball/App/RootView.swift
git commit -m "P0: gate app behind Sign in with Apple in RootView"
```

---

## Done criteria (P0)

- App builds and links Firebase on a clean `xcodegen generate` + build.
- Launch shows `SignInView`; successful Sign in with Apple reveals the existing game shell.
- `currentUser` persists across relaunch (FirebaseAuth caches the session) — second launch skips the gate.
- All 46 tests pass.
- Firebase confined to `Services/Auth` + `Services/Firestore` + `FullballApp`; no ViewModel/View imports Firebase except `SignInView` (which uses only `AuthenticationServices`, not Firebase).

## Implementation notes (deviations from the as-written plan)

Two guards were added during Task 7 to keep the **unit-test host** from trapping at launch
(the test bundle is hosted by the app, which launches `RootView` → `FirebaseAuthService()` →
`Auth.auth()`, which aborts when no `GoogleService-Info.plist` is bundled and Firebase is
unconfigured). Both are production-safe — when the plist is present, Firebase configures and
authenticates normally:

- `FullballApp.init()` calls `FirebaseApp.configure()` only when `GoogleService-Info.plist` is
  bundled (`Bundle.main.url(forResource:withExtension:) != nil`).
- `FirebaseAuthService.init()` `guard FirebaseApp.app() != nil` before reading
  `Auth.auth().currentUser`; starts signed-out when unconfigured.

Final count: **45 unit tests** pass (41 pre-existing + 4 new `NonceTests`).

## Out of scope (later phases)

- Writing/reading any player data to Firestore (wallet, collection) — **P1**.
- Real leaderboard, shared slate, remote catalog, server gacha — **P2–P5**.
- "Link Apple ID" account management, sign-out UI in Settings — future (no Settings screen yet).
