import Foundation

/// Full representation of a user profile as it travels across the network boundary.
/// Zero relationship to SwiftData — mapping happens exclusively in AppStateManager.
struct UserProfileDTO: Codable {
    let remoteID: String
    let googleSub: String?
    let email: String
    let name: String?
    let isProfileComplete: Bool

    // Physical profile (nil until onboarding is complete)
    let dateOfBirth: Date?
    let weightKg: Double?
    let heightCm: Double?
    let gender: String?
    let primaryGoal: String?
    let exerciseHoursPerWeek: Int?
    let allergens: [String]?

    // Backend-computed nutrition targets (nil until onboarding computes them)
    let dailyCalorieGoal: Double?
    let proteinGoal: Double?
    let carbsGoal: Double?
    let fatGoal: Double?

    let createdAt: Date?
    let lastModifiedAt: Date?

    // convertFromSnakeCase turns "remote_id" → "remoteId" (lowercase d),
    // but our property is "remoteID" (uppercase D).
    // CodingKeys raw values must match the CONVERTED camelCase form,
    // not the original snake_case, because the decoder converts first.
    private enum CodingKeys: String, CodingKey {
        case remoteID = "remoteId"
        case googleSub, email, name, isProfileComplete
        case dateOfBirth, weightKg, heightCm, gender
        case primaryGoal, exerciseHoursPerWeek, allergens
        case dailyCalorieGoal, proteinGoal, carbsGoal, fatGoal
        case createdAt, lastModifiedAt
    }
}

/// Sent to the backend after the user completes the onboarding flow.
/// The backend uses this to compute personalised calorie and macro targets.
struct OnboardingProfileDTO: Codable {
    let dateOfBirth: Date
    let weightKg: Double
    let heightCm: Double
    let gender: String
    let primaryGoal: String
    let exerciseHoursPerWeek: Int
    let allergens: [String]
}
