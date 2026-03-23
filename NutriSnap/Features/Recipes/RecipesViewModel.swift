import Foundation
import SwiftUI

@Observable
final class RecipesViewModel {
    // Search and Filter State
    var searchText: String = ""
    
    // Dropdown selections
    var selectedCuisine: String = "Select"
    var selectedMealType: String = "Select"
    var selectedDiet: String = "Select"
    var selectedAllergen: String = "Select"
    var selectedIngredient: String = "Select"
    
    // Difficulty
    var selectedDifficulty: String? = nil
    
    var recipes: [SupabaseRecipe] = []
    var isLoading: Bool = false
    var isLoadingMore: Bool = false
    var errorMessage: String? = nil
    
    // Pagination
    var totalCount: Int = 0
    private var currentOffset: Int = 0
    private let pageSize: Int = 30
    var hasMorePages: Bool { currentOffset < totalCount }
    
    // Static lists for Dropdowns
    let cuisines = ["Select", "Chinese", "Japanese", "Korean", "Southern US", "Italian", "Mexican", "French", "Indian", "British", "Russian", "Greek", "Cajun Creole", "Filipino", "Irish", "Jamaican", "Thai", "Spanish", "Moroccan", "Brazilian", "Vietnamese"]
    let mealTypes = ["Select", "Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]
    let diets = ["Select", "High Protein", "Gluten Free", "Low Fat", "Vegetarian", "Vegan", "Low Carb", "Diabetic", "Paleo", "Low Calorie", "Keto"]
    let allergens = ["Select", "Soy", "Sesame", "Peanut", "Milk", "Egg", "Wheat", "Tree Nut", "Shellfish", "Fish"]
    let mainIngredients = ["Select", "Chicken", "Beef", "Pork", "Fish", "Tofu", "Rice", "Pasta", "Potato", "Tomato", "Cheese"]
    let difficulties = ["Easy", "Medium", "Hard"]
    
    // UI to DB mappings
    private let cuisineMap: [String: String] = [
        "Chinese": "chinese", "Japanese": "japanese", "Korean": "korean", "Southern US": "southern_us",
        "Italian": "italian", "Mexican": "mexican", "French": "french", "Indian": "indian",
        "British": "british", "Russian": "russian", "Greek": "greek", "Cajun Creole": "cajun_creole",
        "Filipino": "filipino", "Irish": "irish", "Jamaican": "jamaican", "Thai": "thai",
        "Spanish": "spanish", "Moroccan": "moroccan", "Brazilian": "brazilian", "Vietnamese": "vietnamese"
    ]
    
    private let dietMap: [String: String] = [
        "High Protein": "high-protein", "Gluten Free": "gluten-free", "Low Fat": "low-fat",
        "Vegetarian": "vegetarianism", "Vegan": "veganism", "Low Carb": "low-carbohydrate",
        "Diabetic": "diabetic", "Paleo": "paleolithic", "Low Calorie": "very-low-calories", "Keto": "ketogenic"
    ]
    
    private let allergenMap: [String: String] = [
        "Soy": "soy_allergen", "Sesame": "sesame_allergen", "Peanut": "peanut_allergen",
        "Milk": "milk_allergen", "Egg": "egg_allergen", "Wheat": "wheat_allergen",
        "Tree Nut": "tree_nut_allergen", "Shellfish": "shellfish_allergen", "Fish": "fish_allergen"
    ]
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }
    
    func clearFilters() {
        selectedCuisine = "Select"
        selectedMealType = "Select"
        selectedDiet = "Select"
        selectedAllergen = "Select"
        selectedIngredient = "Select"
        selectedDifficulty = nil
    }
    
    /// Builds the query endpoint string for the current filters and given offset/limit.
    private func buildEndpoint(offset: Int, limit: Int) -> String {
        var urlComponents = URLComponents()
        urlComponents.path = "/recipes"
        urlComponents.queryItems = []
        
        var selectQuery = "id,title,recipeNutrients:recipe_nutrients(amount,nutrient:nutrient_definitions(name,unit))"
        
        // Apply text search
        if !searchText.filter({ !$0.isWhitespace }).isEmpty {
            urlComponents.queryItems?.append(URLQueryItem(name: "title", value: "ilike.%\(searchText)%"))
        }
        
        // Build complex joins for filters
        
        // 1. Difficulty
        if let diff = selectedDifficulty {
            selectQuery += ",difficulty:difficulty_levels!inner(name)"
            urlComponents.queryItems?.append(URLQueryItem(name: "difficulty.name", value: "eq.\(diff)"))
        } else {
            selectQuery += ",difficulty:difficulty_levels(name)"
        }
        
        // 2. Cuisine
        if selectedCuisine != "Select", let dbName = cuisineMap[selectedCuisine] {
            selectQuery += ",cuisine:cuisines!inner(name)"
            urlComponents.queryItems?.append(URLQueryItem(name: "cuisine.name", value: "eq.\(dbName)"))
        } else {
            selectQuery += ",cuisine:cuisines(name)"
        }
        
        // 3. Diet
        if selectedDiet != "Select", let dbName = dietMap[selectedDiet] {
            selectQuery += ",recipe_dietary_tags!inner(tag:dietary_tags!inner(name))"
            urlComponents.queryItems?.append(URLQueryItem(name: "recipe_dietary_tags.dietary_tags.name", value: "eq.\(dbName)"))
        }
        
        // 4. Allergen
        if selectedAllergen != "Select", let dbName = allergenMap[selectedAllergen] {
            selectQuery += ",recipe_allergens!inner(allergen:allergens!inner(name))"
            urlComponents.queryItems?.append(URLQueryItem(name: "recipe_allergens.allergens.name", value: "eq.\(dbName)"))
        }
        
        // 5. Main Ingredient
        if selectedIngredient != "Select" {
            selectQuery += ",raw_ingredients!inner(ingredient_text)"
            urlComponents.queryItems?.append(URLQueryItem(name: "raw_ingredients.ingredient_text", value: "ilike.%\(selectedIngredient)%"))
        }
        
        // Update the select query item
        urlComponents.queryItems?.removeAll(where: { $0.name == "select" })
        urlComponents.queryItems?.insert(URLQueryItem(name: "select", value: selectQuery), at: 0)
        
        // Pagination
        urlComponents.queryItems?.append(URLQueryItem(name: "offset", value: "\(offset)"))
        urlComponents.queryItems?.append(URLQueryItem(name: "limit", value: "\(limit)"))
        
        let query = urlComponents.query ?? ""
        return "/recipes?\(query)"
    }
    
    /// Initial fetch — resets pagination and loads the first page.
    func fetchRecipes() async {
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        totalCount = 0
        
        let endpoint = buildEndpoint(offset: 0, limit: pageSize)
        print("Recipes Query Endpoint: \(endpoint)")
        
        do {
            let (fetchedRecipes, count): ([SupabaseRecipe], Int?) = try await apiClient.restGetWithCount(endpoint)
            
            await MainActor.run {
                self.recipes = fetchedRecipes
                self.totalCount = count ?? fetchedRecipes.count
                self.currentOffset = fetchedRecipes.count
                self.isLoading = false
            }
        } catch {
            print("Fetch Recipes Error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Loads the next page and appends results.
    func loadMoreRecipes() async {
        guard hasMorePages, !isLoading, !isLoadingMore else { return }
        isLoadingMore = true
        
        let endpoint = buildEndpoint(offset: currentOffset, limit: pageSize)
        print("Load More Endpoint: \(endpoint)")
        
        do {
            let (fetchedRecipes, count): ([SupabaseRecipe], Int?) = try await apiClient.restGetWithCount(endpoint)
            
            await MainActor.run {
                self.recipes.append(contentsOf: fetchedRecipes)
                if let count { self.totalCount = count }
                self.currentOffset += fetchedRecipes.count
                self.isLoadingMore = false
            }
        } catch {
            print("Load More Recipes Error: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingMore = false
            }
        }
    }
}
