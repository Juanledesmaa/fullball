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
                    .foregroundStyle(WC.sub)
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
