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
