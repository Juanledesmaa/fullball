import Foundation
import AuthenticationServices
import FirebaseCore
import FirebaseAuth

/// Firebase-backed authentication. Quarantines FirebaseAuth behind `AuthService`.
@MainActor
@Observable
final class FirebaseAuthService: AuthService {
    var currentUser: AuthUser?

    init() {
        // `Auth.auth()` traps if no FirebaseApp is configured (e.g. the unit-test
        // host, which bundles no GoogleService-Info.plist). When unconfigured
        // there is no session anyway, so start signed-out.
        guard FirebaseApp.app() != nil else {
            currentUser = nil
            return
        }
        currentUser = Self.map(Auth.auth().currentUser)
    }

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        currentUser = Self.map(result.user)
    }

    @discardableResult
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) -> String {
        let rawNonce = Nonce.randomNonceString()
        request.requestedScopes = [.fullName]
        request.nonce = Nonce.sha256(rawNonce)
        return rawNonce
    }

    func signInWithApple(authorization: ASAuthorization, rawNonce: String) async throws {
        let credential = try Self.appleCredential(authorization, rawNonce: rawNonce)
        let result = try await Auth.auth().signIn(with: credential)
        currentUser = Self.map(result.user)
    }

    func linkApple(authorization: ASAuthorization, rawNonce: String) async throws {
        let credential = try Self.appleCredential(authorization, rawNonce: rawNonce)
        guard let user = Auth.auth().currentUser else {
            let result = try await Auth.auth().signIn(with: credential)
            currentUser = Self.map(result.user)
            return
        }
        do {
            let result = try await user.link(with: credential)   // same uid, data preserved
            currentUser = Self.map(result.user)
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // That Apple ID already owns an account → switch to it (uid changes).
            let result = try await Auth.auth().signIn(with: credential)
            currentUser = Self.map(result.user)
            throw AuthError.switchedToExistingAccount
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }

    private static func appleCredential(_ authorization: ASAuthorization, rawNonce: String) throws -> AuthCredential {
        guard
            let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = appleCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.missingAppleToken
        }
        return OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName)
    }

    private static func map(_ user: User?) -> AuthUser? {
        user.map { AuthUser(uid: $0.uid, displayName: $0.displayName, isAnonymous: $0.isAnonymous) }
    }
}

enum AuthError: Error { case missingAppleToken, switchedToExistingAccount }
