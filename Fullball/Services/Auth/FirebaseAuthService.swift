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
