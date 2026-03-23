//
//  FoodLog.swift
//  NutriSnap


import Foundation
import SwiftData

@Model
final class FoodLog {
    // MARK: - Cloud Sync Metadata
    var remoteID: String?
    var needsSync: Bool
    var lastModifiedAt: Date

    // MARK: - Core Fields
    var timestamp: Date
    var foodName: String
    var mealType: String = "Meal"
    var mass: Double = 0
    
    // For syncing to backend later
    var imagePath: String?

    // MARK: - Nutrients
    var Calories: Double
    var Protein: Double
    var Carbohydrate: Double
    var Fat: Double
    var Fiber: Double
    var Calcium: Double
    var Iron: Double
    var Potassium: Double
    var Sodium: Double
    var Zinc: Double
    var VitaminA: Double
    var VitaminC: Double
    var VitaminD: Double
    var VitaminB1: Double
    var VitaminB2: Double
    var VitaminB3: Double
    var VitaminB5: Double
    var VitaminB6: Double
    var VitaminB9: Double
    var VitaminB12: Double
    var Cholesterol: Double
    var TransFat: Double
    var SaturatedFat: Double
    var MonoUnsaturatedFat: Double
    var PolyUnsaturatedFat: Double
    var Sugar: Double
    
    // The Initializer (This is what you were missing!)
// MARK: - Relationship
    var user: User?

    // The Initializer (This is what you were missing!)
    init(
        name: String,
        calories: Double,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        imagePath: String? = nil,
        timestamp: Date = Date(),
        mealType: String = "Meal",
        mass: Double = 0
    ) {
        // IDs and Syncing
        self.id = UUID()
        self.remoteID = nil
        self.needsSync = true
        self.lastModifiedAt = Date()
        
        // Core Properties
        self.timestamp = timestamp
        self.foodName = name
        self.mealType = mealType
        self.mass = mass
        self.imagePath = imagePath
        
        // Macros
        self.Calories = calories
        self.Protein = protein
        self.Carbohydrate = carbs
        self.Fat = fat
        
        // Default everything else to 0 so we don't have a giant list every time
        self.Fiber = 0
        self.Calcium = 0
        self.Iron = 0
        self.Potassium = 0
        self.Sodium = 0
        self.Zinc = 0
        self.VitaminA = 0
        self.VitaminC = 0
        self.VitaminD = 0
        self.VitaminB1 = 0
        self.VitaminB2 = 0
        self.VitaminB3 = 0
        self.VitaminB5 = 0
        self.VitaminB6 = 0
        self.VitaminB9 = 0
        self.VitaminB12 = 0
        self.Cholesterol = 0
        self.TransFat = 0
        self.SaturatedFat = 0
        self.MonoUnsaturatedFat = 0
        self.PolyUnsaturatedFat = 0
        self.Sugar = 0
    }
}
