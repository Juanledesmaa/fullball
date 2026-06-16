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
            if Int(random) < charset.count {            // avoid modulo bias
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
