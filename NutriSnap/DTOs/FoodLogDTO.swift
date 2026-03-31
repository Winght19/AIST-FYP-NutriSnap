import Foundation

/// A single logged food item as it travels across the network boundary.
struct FoodLogDTO: Codable {
    let remoteID: String
    let userID: String      // owning User's remoteID — the security boundary
    let foodName: String
    let mealType: String?
    let mass: Double?
    let imageUrl: String?
    let timestamp: Date
    let lastModifiedAt: Date

    let calories: Double
    let protein: Double
    let carbohydrate: Double
    let fiber: Double
    let calcium: Double
    let iron: Double
    let potassium: Double
    let sodium: Double
    let zinc: Double
    let vitaminA: Double
    let vitaminC: Double
    let vitaminD: Double
    let vitaminB1: Double
    let vitaminB2: Double
    let vitaminB3: Double
    let vitaminB5: Double
    let vitaminB6: Double
    let vitaminB9: Double
    let vitaminB12: Double
    let cholesterol: Double
    let transFat: Double
    let saturatedFat: Double
    let monoUnsaturatedFat: Double
    let polyUnsaturatedFat: Double
    let sugar: Double

    // CodingKeys raw values use the camelCase form that convertFromSnakeCase
    // produces, not the original snake_case. Only special cases need raw values.
    private enum CodingKeys: String, CodingKey {
        case remoteID = "remoteId"
        case userID = "userId"
        case foodName, mealType, mass, imageUrl, timestamp, lastModifiedAt
        case calories, protein, carbohydrate, fiber
        case calcium, iron, potassium, sodium, zinc
        case vitaminA, vitaminC, vitaminD
        case vitaminB1, vitaminB2, vitaminB3
        case vitaminB5, vitaminB6, vitaminB9, vitaminB12
        case cholesterol, transFat, saturatedFat
        case monoUnsaturatedFat, polyUnsaturatedFat, sugar
    }
}

/// A meal with its constituent food items as it travels across the network boundary.
struct MealDTO: Codable {
    let remoteID: String
    let userID: String
    let name: String
    let mealType: String
    let timestamp: Date
    let lastModifiedAt: Date

    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let calcium: Double?
    let iron: Double?
    let potassium: Double?
    let sodium: Double?
    let zinc: Double?
    let vitaminA: Double?
    let vitaminD: Double?
    let vitaminC: Double?
    let cholesterol: Double?
    let transFat: Double?
    let saturatedFat: Double?
    let sugar: Double?

    let foods: [FoodItemDTO]

    private enum CodingKeys: String, CodingKey {
        case remoteID = "remoteId"
        case userID = "userId"
        case name, mealType, timestamp, lastModifiedAt
        case calories, protein, carbs, fat, fiber
        case calcium, iron, potassium, sodium, zinc
        case vitaminA, vitaminD, vitaminC
        case cholesterol, transFat, saturatedFat
        case sugar, foods
    }
}

/// A single food item within a meal DTO.
struct FoodItemDTO: Codable {
    let remoteID: String
    let name: String
    let servingSize: Double
    let servingUnit: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    private enum CodingKeys: String, CodingKey {
        case remoteID = "remoteId"
        case name, servingSize, servingUnit
        case calories, protein, carbs, fat
    }
}
