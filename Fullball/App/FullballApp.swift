import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FullballApp: App {
    let modelContainer: ModelContainer

    init() {
        // Configure Firebase only when the (gitignored) GoogleService-Info.plist
        // is bundled. This keeps the unit-test host (which has no plist) from
        // aborting at launch in `FirebaseApp.configure()`; in production the
        // plist is present so Firebase configures normally.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
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
