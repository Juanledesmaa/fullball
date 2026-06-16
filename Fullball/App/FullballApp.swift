import SwiftUI
import SwiftData
import FirebaseCore

@main
struct FullballApp: App {
    let modelContainer: ModelContainer

    init() {
        FirebaseApp.configure()
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
