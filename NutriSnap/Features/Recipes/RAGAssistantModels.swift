import Foundation

struct RecommendRequest: Encodable {
    let userQuery: String
    let userAllergies: [String]
    let userTags: [String]
    let nutrientGoals: NutrientGoals?
    let dailyIntake: [String: NutrientInfo]?
    
    enum CodingKeys: String, CodingKey {
        case userQuery = "user_query"
        case userAllergies = "user_allergies"
        case userTags = "user_tags"
        case nutrientGoals = "nutrient_goals"
        case dailyIntake = "daily_intake"
    }
}

struct NutrientGoals: Encodable {
    let caloriesMax: Int?
    let proteinMin: Int?
    
    enum CodingKeys: String, CodingKey {
        case caloriesMax = "calories_max"
        case proteinMin = "protein_min"
    }
}

struct NutrientInfo: Encodable {
    let consumed: Double
    let goal: Double
}

struct RecommendResponse: Decodable {
    let recommendation: String
    let recipeIds: [Int]
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case recommendation
        case recipeIds = "recipe_ids"
        case status
    }
}
