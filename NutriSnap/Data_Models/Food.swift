import SwiftData
import Foundation

@Model
class Food {
    @Attribute(.unique) var id: UUID
    var name: String
    var servingSize: Double
    var servingUnit: String
      
    // Nutrition totals
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

     // Detailed nutrients
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
    var meal: Meal?
    
    init(name: String, servingSize: Double = 1, servingUnit: String = "serving") {
        self.id = UUID()
        self.name = name
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.calories = 0
        self.protein = 0
        self.carbs = 0
        self.fat = 0
    }
}