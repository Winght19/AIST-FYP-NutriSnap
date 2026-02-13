import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct NutriSnapApp: App {
    @State private var authManager = AuthenticationManager()
    
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
            Group {
                if authManager.isSignedIn && authManager.hasCompletedOnboarding {
                    DashboardView()
                } else if authManager.isSignedIn {
                    OnboardingView()
                } else {
                    LandingView()
                }
            }
            .environment(authManager)
            .onOpenURL { url in
                // Handle the Google Sign-In redirect URL
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        // 2. Inject it into the window
        .modelContainer(sharedModelContainer)
    }
}

