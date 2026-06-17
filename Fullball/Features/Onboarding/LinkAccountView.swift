import SwiftUI
import AuthenticationServices

/// Account status + optional "Link Apple ID" upgrade for an anonymous player.
/// Used inline on the Agencies screen (`.inline`) and as the one-time soft
/// prompt sheet (`.prompt`). Links the Apple identity to the current anonymous
/// account (preserving data); if that Apple ID already owns an account, Firebase
/// switches to it (handled upstream).
struct LinkAccountView: View {
    enum Mode { case inline, prompt }

    let auth: any AuthService
    var mode: Mode = .inline
    var onDismiss: (() -> Void)? = nil

    @State private var rawNonce: String?
    @State private var message: String?
    @State private var working = false
    @Environment(\.colorScheme) private var colorScheme

    private var isAnonymous: Bool { auth.currentUser?.isAnonymous ?? true }

    var body: some View {
        if mode == .prompt {
            promptCard
        } else {
            inlineRow
        }
    }

    // MARK: inline (Agencies)

    @ViewBuilder private var inlineRow: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: isAnonymous ? "person.crop.circle.badge.questionmark" : "checkmark.seal.fill")
                        .foregroundStyle(isAnonymous ? WC.sub : WC.gold)
                    Text(isAnonymous ? "Guest agency" : "Linked · \(auth.currentUser?.displayName ?? "Apple ID")")
                        .font(WC.display(13)).foregroundStyle(WC.inkText)
                    Spacer()
                }
                if isAnonymous {
                    Text("Link your Apple ID to save your agency across devices and reinstalls.")
                        .font(WC.ui(12)).foregroundStyle(WC.sub)
                    appleButton.frame(height: 44)
                }
                if let message {
                    Text(message).font(WC.ui(12)).foregroundStyle(WC.coral)
                }
            }
            .padding(14)
        }
    }

    // MARK: prompt (soft sheet)

    @ViewBuilder private var promptCard: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "icloud.and.arrow.up").font(.system(size: 44)).foregroundStyle(WC.coral)
            Text("Save your agency").font(WC.display(24)).foregroundStyle(WC.inkText)
            Text("You're playing as a guest. Link your Apple ID so your roster, Cash and rank survive a reinstall or a new device.")
                .font(WC.ui(15)).foregroundStyle(WC.sub).multilineTextAlignment(.center)
            Spacer()
            appleButton.frame(height: 50)
            Button("Later") { onDismiss?() }
                .font(WC.ui(15)).foregroundStyle(WC.sub)
            if let message {
                Text(message).font(WC.ui(12)).foregroundStyle(WC.coral).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 40)
        .background(WC.screenBG.ignoresSafeArea())
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            rawNonce = auth.prepareAppleRequest(request)
        } onCompletion: { result in
            handle(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(working)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let rawNonce else { message = "Sign-in expired. Try again."; return }
            working = true
            Task {
                do {
                    try await auth.linkApple(authorization: authorization, rawNonce: rawNonce)
                    onDismiss?()
                } catch AuthError.switchedToExistingAccount {
                    message = "Switched to your existing agency for this Apple ID."
                    onDismiss?()
                } catch {
                    print("Link Apple failed: \(error as NSError)")
                    message = "Couldn't link right now. Try again."
                }
                working = false
            }
        case .failure(let error):
            print("Apple authorization failed: \(error as NSError)")
        }
    }
}
