import SwiftData
import Foundation

@Model
class User {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var email: String
    var name: String
    var passwordHash: String // Store hashed password (we'll add encryption later)
    var createdAt: Date
    
    // Profile
    var age: Int?
    var weight: Double? // kg
    var height: Double? // cm
    var gender: String?
    var activityLevel: String?
    
    // Goals
    var dailyCalorieGoal: Double
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    
    // Relationships
    @Relationship(deleteRule: .cascade) var meals: [Meal]?
    
    init(email: String, name: String, passwordHash: String) {
        self.id = UUID()
        self.email = email.lowercased()
        self.name = name
        self.passwordHash = passwordHash
        self.createdAt = Date()
        
        // Default goals
        self.dailyCalorieGoal = 2000
        self.proteinGoal = 150
        self.carbsGoal = 250
        self.fatGoal = 70
    }
}