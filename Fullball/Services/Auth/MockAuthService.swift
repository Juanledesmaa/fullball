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

    func signInAnonymously() async throws {
        currentUser = AuthUser(uid: "anon-uid", displayName: nil, isAnonymous: true)
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String { "mock-nonce" }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        currentUser = AuthUser(uid: "preview-uid", displayName: "Preview Agent")
    }

    func linkApple(authorization: ASAuthorization, rawNonce: String) async throws {
        currentUser = AuthUser(uid: currentUser?.uid ?? "preview-uid", displayName: "Tester", isAnonymous: false)
    }

    func signOut() throws { currentUser = nil }
}
