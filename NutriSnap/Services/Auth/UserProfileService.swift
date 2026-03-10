import Foundation

/// Handles all API calls related to user identity and profile.
/// Returns raw DTOs only — never touches SwiftData directly.
final class UserProfileService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Exchanges a Google ID token for the app's own JWT.
    /// The `isNewUser` flag in the response drives the routing decision.
    func authenticate(idToken: String) async throws -> AuthResponseDTO {
        try await apiClient.post("/auth-google", body: AuthRequestDTO(idToken: idToken), token: nil)
    }

    /// Validates a stored JWT and returns the current user profile.
    /// A 401 response means the token is expired or revoked — caller should sign out.
    func fetchProfile(token: String) async throws -> UserProfileDTO {
        try await apiClient.get("/user-profile", token: token)
    }

    /// Sends onboarding form data and receives back the computed nutrition targets.
    /// The backend owns the TDEE / macro calculation — not the client.
    func saveOnboardingProfile(_ profile: OnboardingProfileDTO, token: String) async throws -> UserProfileDTO {
        try await apiClient.post("/user-onboarding", body: profile, token: token)
    }

    /// Updates an already-complete user profile (e.g. after the user edits their settings).
    func updateProfile(_ profile: OnboardingProfileDTO, token: String) async throws -> UserProfileDTO {
        try await apiClient.put("/user-profile", body: profile, token: token)
    }
}
