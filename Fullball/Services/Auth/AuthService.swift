import Foundation
import AuthenticationServices

/// The authenticated player, abstracted away from Firebase's `User`.
struct AuthUser: Equatable, Sendable {
    let uid: String
    let displayName: String?
    var isAnonymous: Bool = false
}

/// Authentication seam. ViewModels/Views depend on this, never on Firebase.
@MainActor
protocol AuthService: AnyObject {
    /// The currently signed-in user, or nil. Observable so the UI can react.
    var currentUser: AuthUser? { get }

    /// Zero-friction anonymous session (gives a stable uid for cloud save).
    func signInAnonymously() async throws

    /// Configure an `ASAuthorizationAppleIDRequest` with the scopes + hashed
    /// nonce. Returns the raw nonce to retain until the credential comes back.
    @discardableResult
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String

    /// Exchange a completed Apple authorization for a Firebase session.
    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws

    /// Upgrade the current anonymous user to an Apple identity, preserving the
    /// uid + data. If that Apple ID already owns an account, switches to it
    /// (uid changes).
    func linkApple(authorization: ASAuthorization, rawNonce: String) async throws

    func signOut() throws
}
