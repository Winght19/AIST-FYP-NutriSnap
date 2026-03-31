import SwiftData
import Foundation

@Model
class User {
    // MARK: - Cloud Sync Metadata
    var remoteID: String?
    var needsSync: Bool
    var lastModifiedAt: Date

    // MARK: - Profile State
    var isProfileComplete: Bool

    // MARK: - Identity (Google sub claim is the stable, immutable identifier)
    @Attribute(.unique) var googleSub: String
    var email: String
    var name: String
    var createdAt: Date

    // MARK: - Physical Profile
    var dateOfBirth: Date?
    var weight: Double?            // kg
    var targetWeight: Double? = nil // custom goal weight in kg
    var height: Double?            // cm
    var gender: String?
    var primaryGoal: String?
    var exerciseHoursPerWeek: Int?
    var allergens: [String] = []
    var preferredCuisines: [String] = []
    var preferredMealTypes: [String] = []
    var preferredDiets: [String] = []

    // MARK: - Derived (not stored — always accurate regardless of when it is read)
    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    // MARK: - Computed Goals (backend-calculated after onboarding)
    var dailyCalorieGoal: Double
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade, inverse: \Meal.user) var meals: [Meal]?
    @Relationship(deleteRule: .cascade, inverse: \FoodLog.user) var foodLogs: [FoodLog]?
    @Relationship(deleteRule: .cascade) var weightHistory: [WeightEntry]?

    init(googleSub: String, email: String, name: String) {
        self.remoteID = nil
        self.needsSync = true
        self.lastModifiedAt = Date()
        self.isProfileComplete = false
        self.googleSub = googleSub
        self.email = email.lowercased()
        self.name = name
        self.createdAt = Date()
        self.allergens = []
        self.preferredCuisines = []
        self.preferredMealTypes = []
        self.preferredDiets = []
        self.dailyCalorieGoal = 2000
        self.proteinGoal = 150
        self.carbsGoal = 250
        self.fatGoal = 70
    }
}
