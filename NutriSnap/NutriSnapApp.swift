import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct NutriSnapApp: App {
    // @State is the correct wrapper for @Observable objects owned by a Scene.
    @State private var appStateManager = AppStateManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Meal.self,
            Food.self,
            FoodLog.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appStateManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
