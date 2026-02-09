import SwiftUI
import SwiftData

@main
struct NutriSnapApp: App {
    // 1. Define the container for your FoodLog model
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            FoodLog.self, // <--- Make sure FoodLog is listed here!
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        // 2. Inject it into the window
        .modelContainer(sharedModelContainer)
    }
}

