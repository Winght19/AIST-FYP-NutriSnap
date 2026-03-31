# RAG API — iOS Integration Guide

> **For the iOS Agent / Developer:** We have wrapped the powerful AI Recommendation engine (RAG pipeline) into a **FastAPI backend**. Since iOS devices cannot run heavy ML models locally, you will fetch AI recommendations by making a simple HTTP POST request.

---

## The Endpoint

**URL (Local Dev):** `http://192.168.0.110:8000/api/recommend`
*(Note: Replace `192.168.0.110:8000` with the production URL once this API is hosted on Render/Railway).*

**Method:** `POST`

**Headers:**
- `Content-Type: application/json`

---

## 1. Swift Request Model

The iOS app needs to send the user's free-text request along with their profile context (allergies, diets, and nutrient goals).

Create these `Encodable` models in Swift:

```swift
import Foundation

struct RecommendRequest: Encodable {
    let userQuery: String
    let userAllergies: [String]
    let userTags: [String]
    let nutrientGoals: [String: Any]?
    let dailyIntake: [String: NutrientInfo]?
    
    enum CodingKeys: String, CodingKey {
        case userQuery = "user_query"
        case userAllergies = "user_allergies"
        case userTags = "user_tags"
        case nutrientGoals = "nutrient_goals"
        case dailyIntake = "daily_intake"
    }
    
    // Helper to encode Any dictionary (since Encodable doesn't support Any natively)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userQuery, forKey: .userQuery)
        try container.encode(userAllergies, forKey: .userAllergies)
        try container.encode(userTags, forKey: .userTags)
        
        // Skip complex dictionary encoding here for brevity.
        // In practice, define a strict struct for NutrientGoals instead of [String: Any]
    }
}

// Recommended strict struct for Nutrient Goals (to avoid [String: Any] issues):
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
```

---

## 2. Swift Response Model

The API will return a simple JSON object containing the AI's generated response string.

```swift
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
```

---

## 3. Implementation Example (URLSession)

Here is a complete asynchronous ViewModel function to fetch the recommendation:

```swift
import Foundation

class AIChatViewModel: ObservableObject {
    @Published var recommendation: String = ""
    @Published var recommendedRecipeIds: [Int] = []
    @Published var isTyping: Bool = false
    
    // Replace with your actual hosted API URL later
    let apiUrl = URL(string: "http://192.168.0.110:8000/api/recommend")!
    
    @MainActor
    func fetchRecommendation(query: String, userProfile: UserProfile) async {
        isTyping = true
        
        // 1. Build the Request Payload
        let payload = [
            "user_query": query,
            "user_allergies": userProfile.allergies, // e.g. ["Peanut", "Milk"]
            "user_tags": userProfile.dietaryTags,    // e.g. ["veganism", "gluten-free"]
            "nutrient_goals": ["calories_max": 800]  // Add actual goals here
        ] as [String : Any]
        
        do {
            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            // 2. Make the Network Call
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Server Error")
                self.isTyping = false
                return
            }
            
            // 3. Decode the Response
            let result = try JSONDecoder().decode(RecommendResponse.self, from: data)
            
            // 4. Update the UI & Store recipe IDs to fetch from Supabase
            self.recommendation = result.recommendation
            self.recommendedRecipeIds = result.recipeIds
            
        } catch {
            print("Failed to fetch recommendation: \(error)")
        }
        
        isTyping = false
    }
}
```

### Note on RAG UI
The `recommendation` string returned by the API is pre-formatted with markdown and tailored nicely by the AI. You can display it in a typical chat-bubble UI.
Below the chat bubble, you can map over `recommendedRecipeIds` and use the **Supabase Swift SDK** (as shown in the `RECIPE_DETAIL_VIEW_GUIDE.md`) to fetch the rich details and display interactive recipe cards!
