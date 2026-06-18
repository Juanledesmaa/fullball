import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAppCheck

/// App Check provider: App Attest on real builds (proves requests come from this
/// genuine app), debug provider on simulator/DEBUG (prints a token to register
/// in the Firebase console). Must be set BEFORE `FirebaseApp.configure()`.
private final class FullballAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        AppCheckDebugProvider(app: app)
        #else
        AppAttestProvider(app: app)
        #endif
    }
}

@main
struct FullballApp: App {
    let modelContainer: ModelContainer

    init() {
        // Configure Firebase only when the (gitignored) GoogleService-Info.plist
        // is bundled. This keeps the unit-test host (which has no plist) from
        // aborting at launch in `FirebaseApp.configure()`; in production the
        // plist is present so Firebase configures normally.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            // App Check factory MUST be registered before configure().
            AppCheck.setAppCheckProviderFactory(FullballAppCheckFactory())
            FirebaseApp.configure()
            // Firestore settings can only be set once, before any use — do it here
            // (the app builds multiple FirestoreClients).
            FirestoreClient.configureSettings()
        }
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
