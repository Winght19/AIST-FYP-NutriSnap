import Foundation

/// Every possible state the app can be in. No screen transition happens
/// without going through one of these cases.
enum AppState {
    /// Between app open and the first async check completing — shows splash screen.
    case launching
    /// No valid session — shows LandingView.
    case unauthenticated
    /// Authenticated but isProfileComplete is false — shows OnboardingView.
    case onboarding
    /// Authenticated and complete, but initial cloud pull is in progress — shows loading UI.
    case syncing
    /// Everything is ready — shows DashboardView.
    case authenticated
    /// A non-fatal failure with a recovery path back to unauthenticated.
    case error(String)
}

extension AppState: Equatable {
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.launching, .launching): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.onboarding, .onboarding): return true
        case (.syncing, .syncing): return true
        case (.authenticated, .authenticated): return true
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}
