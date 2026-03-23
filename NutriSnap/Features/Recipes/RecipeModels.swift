import Foundation

struct SupabaseCuisine: Decodable, Hashable {
    let name: String
}

struct SupabaseDifficultyLevel: Decodable, Hashable {
    let name: String
}

struct SupabaseAllergen: Decodable, Hashable {
    let name: String
}

struct SupabaseRecipeAllergen: Decodable, Hashable {
    let allergen: SupabaseAllergen
}

struct SupabaseDietaryTag: Decodable, Hashable {
    let name: String
}

struct SupabaseRecipeDietaryTag: Decodable, Hashable {
    let tag: SupabaseDietaryTag
}

struct SupabaseNutrient: Decodable, Hashable {
    let name: String
    let unit: String
}

struct SupabaseRecipeNutrient: Decodable, Hashable {
    let amount: Double
    let nutrient: SupabaseNutrient
}

struct SupabaseRawIngredient: Decodable, Hashable {
    let ingredientText: String
}

struct SupabaseParsedDirection: Decodable, Hashable {
    let stepText: String
}

struct SupabaseRecipe: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let cuisine: SupabaseCuisine?
    let difficulty: SupabaseDifficultyLevel?
    
    // Arrays for the detailed view
    let rawIngredients: [SupabaseRawIngredient]?
    let parsedDirections: [SupabaseParsedDirection]?
    let recipeAllergens: [SupabaseRecipeAllergen]?
    let recipeDietaryTags: [SupabaseRecipeDietaryTag]?
    let recipeNutrients: [SupabaseRecipeNutrient]?
    
    // Decodable coding keys to map the nested JSON returned by Supabase
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case cuisine
        case difficulty
        case rawIngredients
        case parsedDirections
        case recipeAllergens
        case recipeDietaryTags
        case recipeNutrients
    }
}
