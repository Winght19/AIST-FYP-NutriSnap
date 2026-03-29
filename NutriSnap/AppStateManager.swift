import SwiftUI
import SwiftData

/// The single object that owns `appState` and drives every screen transition.
/// @MainActor ensures all state mutations happen on the main thread — required
/// for SwiftUI reactivity and SwiftData's ModelContext threading rules.
@MainActor
@Observable
final class AppStateManager {
    var appState: AppState = .launching
    var currentUser: User?

    private let keychainManager: KeychainManager
    private let userProfileService: UserProfileService
    private let syncService: SyncService
    let authManager: AuthenticationManager

    init(
        keychainManager: KeychainManager = .shared,
        userProfileService: UserProfileService = UserProfileService(),
        syncService: SyncService = SyncService(),
        authManager: AuthenticationManager = AuthenticationManager()
    ) {
        self.keychainManager = keychainManager
        self.userProfileService = userProfileService
        self.syncService = syncService
        self.authManager = authManager
    }

    // MARK: - Event Handlers

    /// Called once on app launch from RootView's .task modifier.
    func handleAppLaunch(modelContext: ModelContext) async {
        guard let token = keychainManager.retrieveToken() else {
            appState = .unauthenticated
            return
        }

        do {
            let profileDTO = try await userProfileService.fetchProfile(token: token)
            upsertUser(from: profileDTO, modelContext: modelContext)

            guard let user = currentUser else {
                appState = .unauthenticated
                return
            }

            if !user.isProfileComplete {
                appState = .onboarding
                return
            }

            appState = .syncing
            if let remoteID = user.remoteID {
                try await syncService.initialSync(for: remoteID, modelContext: modelContext)
            }
            FoodLogImageStore.shared.reconcileStorage(modelContext: modelContext)
            appState = .authenticated

        } catch APIError.unauthenticated {
            keychainManager.deleteToken()
            appState = .unauthenticated
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    /// Called when the user taps "Sign In with Google" on LandingView.
    func handleGoogleSignIn(modelContext: ModelContext) async {
        do {
            let idToken = try await authManager.getGoogleIDToken()
            let response = try await userProfileService.authenticate(idToken: idToken)
            try keychainManager.saveToken(response.jwt)

            if response.isNewUser {
                // Create a minimal stub so the onboarding view has a user to reference.
                // Fields are filled once onboarding completes.
                if let profile = response.profile {
                    upsertUser(from: profile, modelContext: modelContext)
                } else {
                    // Backend should always return a profile stub for new users.
                    // If it doesn't, insert a placeholder from the Google user info.
                    let stub = User(
                        googleSub: authManager.googleSub,
                        email: authManager.userEmail,
                        name: authManager.userName
                    )
                    modelContext.insert(stub)
                    try? modelContext.save()
                    currentUser = stub
                }
                appState = .onboarding
            } else {
                if let profile = response.profile {
                    upsertUser(from: profile, modelContext: modelContext)
                }
                appState = .syncing
                if let remoteID = currentUser?.remoteID {
                    try await syncService.initialSync(for: remoteID, modelContext: modelContext)
                }
                appState = .authenticated
            }

        } catch AuthenticationManager.AuthError.canceled {
            // User dismissed the sheet — stay on LandingView, no error message needed.
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    /// Called by OnboardingView after the user submits the last onboarding step.
    /// Saves profile to backend and receives computed nutrition targets.
    /// Does NOT transition to .authenticated — that happens via finishOnboarding().
    func completeOnboarding(with data: OnboardingProfileDTO, modelContext: ModelContext) async {
        guard let token = keychainManager.retrieveToken() else {
            appState = .unauthenticated
            return
        }
        do {
            let updatedProfile = try await userProfileService.saveOnboardingProfile(data, token: token)
            upsertUser(from: updatedProfile, modelContext: modelContext)
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    /// Called when the user taps "Start Tracking" on the ProfileReadyView.
    func finishOnboarding() {
        appState = .authenticated
    }

    /// Triggered by scenePhase becoming .active in DashboardView.
    /// Retries all dirty records and pulls a lightweight cloud refresh.
    func handleForegroundActivation(modelContext: ModelContext) async {
        if let remoteID = currentUser?.remoteID,
           let token = keychainManager.retrieveToken() {
            try? await syncService.flushPendingSync(for: remoteID, token: token, modelContext: modelContext)
        }
        FoodLogImageStore.shared.reconcileStorage(modelContext: modelContext)
    }

    /// Called from ProfileView. Clears Google session, JWT, and local user reference.
    /// SwiftData records are left on device — they reload from the cloud on next sign-in,
    /// making re-login feel instant on a personal device.
    func signOut(modelContext: ModelContext) {
        authManager.signOut()
        keychainManager.deleteToken()
        currentUser = nil
        appState = .unauthenticated
    }

    // MARK: - Upsert Pattern

    /// Creates or updates the local User record from a DTO, matching by remoteID.
    private func upsertUser(from dto: UserProfileDTO, modelContext: ModelContext) {
        let remoteID = dto.remoteID
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            apply(dto: dto, to: existing)
            currentUser = existing
        } else {
            let newUser = User(googleSub: dto.googleSub ?? "", email: dto.email, name: dto.name ?? "")
            apply(dto: dto, to: newUser)
            modelContext.insert(newUser)
            try? modelContext.save()
            currentUser = newUser
        }
    }

    /// Single mapping function used by both the create and update paths.
    private func apply(dto: UserProfileDTO, to user: User) {
        user.remoteID = dto.remoteID
        user.googleSub = dto.googleSub ?? user.googleSub
        user.email = dto.email
        user.name = dto.name ?? user.name
        user.isProfileComplete = dto.isProfileComplete
        user.dateOfBirth = dto.dateOfBirth
        user.weight = dto.weightKg
        user.height = dto.heightCm
        user.gender = dto.gender
        user.primaryGoal = dto.primaryGoal
        user.exerciseHoursPerWeek = dto.exerciseHoursPerWeek
        user.allergens = dto.allergens ?? user.allergens
        user.preferredCuisines = dto.preferredCuisines ?? user.preferredCuisines
        user.preferredMealTypes = dto.preferredMealTypes ?? user.preferredMealTypes
        user.preferredDiets = dto.preferredDiets ?? user.preferredDiets
        user.dailyCalorieGoal = dto.dailyCalorieGoal ?? user.dailyCalorieGoal
        user.proteinGoal = dto.proteinGoal ?? user.proteinGoal
        user.carbsGoal = dto.carbsGoal ?? user.carbsGoal
        user.fatGoal = dto.fatGoal ?? user.fatGoal
        user.lastModifiedAt = dto.lastModifiedAt ?? user.lastModifiedAt
        user.needsSync = false
    }
}
