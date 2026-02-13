import SwiftUI
import Observation

/// Holds all data collected during the onboarding flow
@Observable
class OnboardingData {
    // Step 1: Gender
    var gender: String = ""
    
    // Step 2: Height & Weight
    var height: Int = 165   // cm
    var weight: Int = 70    // kg
    
    // Step 3: Primary Goal
    var primaryGoal: String = ""
    
    // Step 4: Age
    var age: Int = 22
    
    // Step 5: Exercise per week
    var exerciseHours: Int = 3
    
    // Step 6: Allergens
    var selectedAllergens: Set<String> = []
    
    static let allergenOptions = [
        "Soy", "Sesame", "Peanut", "Milk",
        "Egg", "Wheat", "Tree nut", "Shellfish", "Fish"
    ]
    
    static let goalOptions = [
        "Lose Weight", "Maintain Weight", "Gain Weight", "Gain Muscle"
    ]
}
