import SwiftData
import Foundation

@Model
class Meal {
    // MARK: - Cloud Sync Metadata
    var remoteID: String?
    var needsSync: Bool
    var lastModifiedAt: Date

    // MARK: - Core Fields
    var name: String
    var mealType: String       // "breakfast", "lunch", "dinner", "snack"
    var timestamp: Date
    var imageData: Data?

    // MARK: - Macro Totals
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    // MARK: - Detailed Nutrients
    var fiber: Double?
    var calcium: Double?
    var iron: Double?
    var potassium: Double?
    var sodium: Double?
    var zinc: Double?
    var vitaminA: Double?
    var vitaminD: Double?
    var vitaminC: Double?
    var vitaminB1: Double?
    var vitaminB2: Double?
    var vitaminB3: Double?
    var vitaminB5: Double?
    var vitaminB6: Double?
    var vitaminB9: Double?
    var vitaminB12: Double?
    var cholesterol: Double?
    var transFat: Double?
    var saturatedFat: Double?
    var monounsaturatedFat: Double?
    var polyunsaturatedFat: Double?
    var sugar: Double?

    // MARK: - Relationships
    var user: User?
    @Relationship(deleteRule: .cascade, inverse: \Food.meal) var foods: [Food]?

    init(name: String, mealType: String, timestamp: Date = Date()) {
        self.remoteID = nil
        self.needsSync = true
        self.lastModifiedAt = Date()
        self.name = name
        self.mealType = mealType
        self.timestamp = timestamp
        self.calories = 0
        self.protein = 0
        self.carbs = 0
        self.fat = 0
    }
}
