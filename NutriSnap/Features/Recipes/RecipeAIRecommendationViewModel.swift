import Foundation
import Combine

@MainActor
class RecipeAIRecommendationViewModel: ObservableObject {
    @Published var recommendationText: String = ""
    @Published var recommendedRecipes: [SupabaseRecipe] = []
    @Published var isTyping: Bool = false
    @Published var errorMessage: String? = nil
    
    // Replace with actual hosted API URL later
    private let apiUrl = URL(string: "http://localhost:8000/api/recommend")!
    
    // Fetch recommendation and subsequent recipes
    func fetchRecommendation(query: String, currentUser: User?) async {
        isTyping = true
        errorMessage = nil
        recommendationText = ""
        recommendedRecipes = []
        
        // Build payload
        let allergens = currentUser?.allergens ?? []
        let dietaryTags = currentUser?.preferredDiets ?? []
        let goals = NutrientGoals(
            caloriesMax: currentUser != nil ? Int(currentUser!.dailyCalorieGoal) : nil,
            proteinMin: currentUser != nil ? Int(currentUser!.proteinGoal) : nil
        )
        
        let requestPayload = RecommendRequest(
            userQuery: query,
            userAllergies: allergens,
            userTags: dietaryTags,
            nutrientGoals: goals,
            dailyIntake: nil // Can be extended later if needed
        )
        
        do {
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestPayload)
            
            // 1. Make the Network Call to RAG API
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                isTyping = false
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server error: \(httpResponse.statusCode)"
                isTyping = false
                return
            }
            
            // 2. Decode the Response
            let result = try JSONDecoder().decode(RecommendResponse.self, from: data)
            self.recommendationText = result.recommendation
            
            // 3. Fetch full recipe objects from Supabase if we have IDs
            if !result.recipeIds.isEmpty {
                await fetchFullRecipes(ids: result.recipeIds)
            }
            
        } catch {
            print("Failed to fetch recommendation: \(error)")
            errorMessage = "Could not connect to AI service. Ensure server is running."
        }
        
        isTyping = false
    }
    
    // Helper to fetch rich recipes from Supabase once the IDs are known
    private func fetchFullRecipes(ids: [Int]) async {
        let idsString = ids.map { String($0) }.joined(separator: ",")
        let selectQuery = "id,title,recipeNutrients:recipe_nutrients(amount,nutrient:nutrient_definitions(name,unit)),difficulty:difficulty_levels(name),cuisine:cuisines(name)"
        let endpoint = "/recipes?select=\(selectQuery)&id=in.(\(idsString))"
        
        do {
            let fetchedRecipes: [SupabaseRecipe] = try await APIClient.shared.restGet(endpoint)
            // Sort to match original returned order if needed, or just append
            self.recommendedRecipes = fetchedRecipes
        } catch {
            print("Failed to fetch rich recipes from Supabase: \(error)")
        }
    }
}
