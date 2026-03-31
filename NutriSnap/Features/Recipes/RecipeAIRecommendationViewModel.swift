import Foundation
import Combine

@MainActor
class RecipeAIRecommendationViewModel: ObservableObject {
    static let shared = RecipeAIRecommendationViewModel()
    
    @Published var messages: [AIChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var errorMessage: String? = nil
    
    private let apiUrl = URL(string: "http://192.168.0.110:8000/api/recommend")!
    
    private init() {} // Singleton
    
    func fetchRecommendation(query: String, currentUser: User?) async {
        // Append User Message to history
        let userMsg = AIChatMessage(isUser: true, text: query, recipes: nil)
        messages.append(userMsg)
        
        isTyping = true
        errorMessage = nil
        
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
            dailyIntake: nil
        )
        
        do {
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestPayload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                isTyping = false
                return
            }
            
            let result = try JSONDecoder().decode(RecommendResponse.self, from: data)
            
            var fetchedRecipes: [SupabaseRecipe]? = nil
            if !result.recipeIds.isEmpty {
                fetchedRecipes = await fetchFullRecipes(ids: result.recipeIds)
            }
            
            // Append AI Message to history
            let aiMsg = AIChatMessage(isUser: false, text: result.recommendation, recipes: fetchedRecipes)
            messages.append(aiMsg)
            
        } catch {
            print("Failed to fetch recommendation: \(error)")
            errorMessage = "Could not connect to AI service. Ensure server is running."
        }
        
        isTyping = false
    }
    
    private func fetchFullRecipes(ids: [Int]) async -> [SupabaseRecipe] {
        let idsString = ids.map { String($0) }.joined(separator: ",")
        let selectQuery = "id,title,recipeNutrients:recipe_nutrients(amount,nutrient:nutrient_definitions(name,unit)),difficulty:difficulty_levels(name),cuisine:cuisines(name)"
        let endpoint = "/recipes?select=\(selectQuery)&id=in.(\(idsString))"
        
        do {
            let fetchedRecipes: [SupabaseRecipe] = try await APIClient.shared.restGet(endpoint)
            return fetchedRecipes
        } catch {
            print("Failed to fetch rich recipes: \(error)")
            return []
        }
    }
    
    func clearHistory() {
        messages = []
        errorMessage = nil
        isTyping = false
    }
}
