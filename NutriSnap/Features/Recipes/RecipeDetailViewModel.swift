import Foundation
import SwiftUI

@Observable
final class RecipeDetailViewModel {
    var recipe: SupabaseRecipe?
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func fetchRecipeDetail(id: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var urlComponents = URLComponents()
            urlComponents.path = "/recipes"
            
            // Build the gigantic select query to grab all relations via REST.
            // Supabase REST makes joining tables quite easy, you just list the nested relations.
            let selectQuery = [
                "id,title",
                "cuisine:cuisines(name)",
                "difficulty:difficulty_levels(name)",
                "rawIngredients:raw_ingredients(ingredientText:ingredient_text)",
                "parsedDirections:parsed_directions(stepText:step_text)",
                "recipeAllergens:recipe_allergens(allergen:allergens(name))",
                "recipeDietaryTags:recipe_dietary_tags(tag:dietary_tags(name))",
                "recipeNutrients:recipe_nutrients(amount,nutrient:nutrient_definitions(name,unit))"
            ].joined(separator: ",")
            
            urlComponents.queryItems = [
                URLQueryItem(name: "select", value: selectQuery),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
            
            guard let query = urlComponents.query else {
                throw URLError(.badURL)
            }
            
            let endpoint = "/recipes?\(query)"
            
            // We get an array of 1 element back
            let fetchedData: [SupabaseRecipe] = try await apiClient.restGet(endpoint)
            
            await MainActor.run {
                self.recipe = fetchedData.first
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
