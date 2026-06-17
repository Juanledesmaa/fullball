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
