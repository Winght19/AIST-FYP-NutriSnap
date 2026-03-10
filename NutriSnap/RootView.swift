import SwiftUI
import SwiftData

/// Pure routing view — contains no user-facing UI of its own.
/// Every screen transition in the app flows through here.
struct RootView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            switch appStateManager.appState {
            case .launching:
                SplashView()
            case .unauthenticated:
                LandingView()
            case .onboarding:
                OnboardingView()
            case .syncing:
                SyncingView()
            case .authenticated:
                DashboardView()
            case .error(let message):
                ErrorView(message: message) {
                    appStateManager.appState = .unauthenticated
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appStateManager.appState)
        // .task ties the async work to the view's lifetime and cancels on disappear.
        .task {
            await appStateManager.handleAppLaunch(modelContext: modelContext)
        }
    }
}

// MARK: - Splash Screen

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.88, blue: 0.72),
                    Color(red: 0.90, green: 0.96, blue: 0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("nutrisnap_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)

                Text("NutriSnap")
                    .font(.title)
                    .fontWeight(.bold)

                ProgressView()
                    .tint(Color(red: 0.40, green: 0.75, blue: 0.50))
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Syncing Screen

private struct SyncingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(red: 0.40, green: 0.75, blue: 0.50))

                Text("Syncing your data…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Error Screen

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)

                VStack(spacing: 8) {
                    Text("Something went wrong")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button(action: onRetry) {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 160, height: 48)
                        .background(Color(red: 0.40, green: 0.75, blue: 0.50))
                        .cornerRadius(24)
                }
            }
        }
    }
}
