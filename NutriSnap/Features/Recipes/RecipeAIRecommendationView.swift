import SwiftUI

struct RecipeAIRecommendationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppStateManager.self) private var appStateManager
    
    @StateObject private var viewModel = RecipeAIRecommendationViewModel()
    
    @State private var promptText: String = ""
    
    // Form selections
    @State private var cuisine = "Select"
    @State private var mealType = "Select"
    @State private var diet = "Select"
    @State private var allergen = "Select"
    @State private var mainIngredient = "Select"
    @State private var difficulty = ""
    
    // Theme Colors
    let blueBackground = Color(red: 0.45, green: 0.73, blue: 1.0)
    let darkBlue = Color(red: 0.25, green: 0.55, blue: 0.85)
    let pillGreen = Color(red: 0.65, green: 0.9, blue: 0.75)
    
    // Static lists for Dropdowns matching RecipesViewModel
    let cuisines = ["Select", "Chinese", "Japanese", "Korean", "Southern US", "Italian", "Mexican", "French", "Indian", "British", "Russian", "Greek", "Cajun Creole", "Filipino", "Irish", "Jamaican", "Thai", "Spanish", "Moroccan", "Brazilian", "Vietnamese"]
    let mealTypes = ["Select", "Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]
    let diets = ["Select", "High Protein", "Gluten Free", "Low Fat", "Vegetarian", "Vegan", "Low Carb", "Diabetic", "Paleo", "Low Calorie", "Keto"]
    let allergens = ["Select", "Soy", "Sesame", "Peanut", "Milk", "Egg", "Wheat", "Tree Nut", "Shellfish", "Fish"]
    let mainIngredients = ["Select", "Chicken", "Beef", "Pork", "Fish", "Tofu", "Rice", "Pasta", "Potato", "Tomato", "Cheese"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    if !viewModel.recommendationText.isEmpty {
                        withAnimation { 
                            // Go back to input
                            viewModel.recommendationText = "" 
                        }
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.headline)
                    Text("AI Recommendation")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                // Invisible placeholder to center title
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding()
            .background(Color.white)
            
            if viewModel.isTyping {
                loadingView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Top Blue Banner
                        if viewModel.recommendationText.isEmpty {
                            inputBannerView
                        } else {
                            resultBannerView
                        }
                        
                        // Error message
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        if viewModel.recommendationText.isEmpty {
                            // Find by Preference Section
                            Text("Find by Preference")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                            
                            VStack(spacing: 16) {
                                FormDropdown(label: "Cuisine", selection: $cuisine, options: cuisines)
                                FormDropdown(label: "Meal Type", selection: $mealType, options: mealTypes)
                                FormDropdown(label: "Diet", selection: $diet, options: diets)
                                FormDropdown(label: "Allergen", selection: $allergen, options: allergens)
                                FormDropdown(label: "Main Ingredient", selection: $mainIngredient, options: mainIngredients)
                            }
                            
                            // Difficulty Pills
                            HStack(spacing: 16) {
                                Spacer()
                                DifficultyPill(title: "Easy", selected: $difficulty)
                                DifficultyPill(title: "Medium", selected: $difficulty)
                                DifficultyPill(title: "Hard", selected: $difficulty)
                                Spacer()
                            }
                            .padding(.top, 8)
                            
                            // Search Button
                            Button(action: {
                                performSearch()
                            }) {
                                Text("Search")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 10)
                            
                        } else {
                            // Recipes Recommended Section
                            if !viewModel.recommendedRecipes.isEmpty {
                                Text("Recipes Recommended")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.top, 8)
                                
                                VStack(spacing: 12) {
                                    ForEach(viewModel.recommendedRecipes) { recipe in
                                        let caloriesNutrient = recipe.recipeNutrients?.first(where: {
                                            $0.nutrient.name.lowercased() == "calories"
                                        })
                                        let caloriesString = caloriesNutrient != nil ? String(format: "%.0f kcal", caloriesNutrient!.amount) : "N/A"
                                        
                                        NavigationLink(destination: RecipeDetailView(recipeId: recipe.id)) {
                                            RecipeCard(
                                                title: recipe.title,
                                                cuisine: recipe.cuisine?.name ?? "Unknown",
                                                difficulty: recipe.difficulty?.name ?? "Unknown",
                                                calories: caloriesString
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(red: 0.95, green: 0.98, blue: 0.93)) // Light greenish-yellow background
            }
        }
        .navigationBarHidden(true)
    }
    
    private func performSearch() {
        // Compile preferences to assist the AI
        var queryStr = promptText
        var preferences: [String] = []
        
        if cuisine != "Select" { preferences.append("Cuisine is \(cuisine)") }
        if mealType != "Select" { preferences.append("Meal Type is \(mealType)") }
        if diet != "Select" { preferences.append("Diet is \(diet)") }
        if allergen != "Select" { preferences.append("Must exclude \(allergen)") }
        if mainIngredient != "Select" { preferences.append("Main Ingredient is \(mainIngredient)") }
        if !difficulty.isEmpty { preferences.append("Difficulty should be \(difficulty)") }
        
        if !preferences.isEmpty {
            queryStr += " (Preferences: " + preferences.joined(separator: ", ") + ")"
        }
        
        Task {
            await viewModel.fetchRecommendation(
                query: queryStr,
                currentUser: appStateManager.currentUser
            )
        }
    }
    
    // MARK: - Banner Views
    
    private var inputBannerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's in your mind?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Get a recipe in seconds.")
                .font(.subheadline)
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                TextField("E.g. I want a high protein fine dining", text: $promptText)
                    .padding()
                    .background(darkBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .onSubmit {
                        performSearch()
                    }
                
                Button(action: {
                    performSearch()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(darkBlue)
                        .clipShape(Circle())
                }
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blueBackground)
        .cornerRadius(16)
    }
    
    private var resultBannerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text(viewModel.recommendationText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
            
            Button(action: {
                withAnimation { 
                    viewModel.recommendationText = "" 
                }
            }) {
                Text("Tell AI what you would like to adjust")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(darkBlue)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(blueBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(Color.gray).frame(width: 8, height: 8)
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                Image(systemName: "sparkles")
                    .foregroundColor(.primary)
            }
            
            Text("Finding recipe only for you")
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
        }
    }
}

// MARK: - Helper Components

struct FormDropdown: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option, action: { selection = option })
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundColor(selection == "Select" ? .gray : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
            }
        }
    }
}

struct DifficultyPill: View {
    let title: String
    @Binding var selected: String
    
    // Green used in reference
    let activeGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
    let inactiveGreen = Color(red: 0.65, green: 0.9, blue: 0.8)
    
    var body: some View {
        Button(action: {
            selected = title
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(selected == title ? .white : .black)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(selected == title ? activeGreen : inactiveGreen)
                .clipShape(Capsule())
        }
    }
}

struct RecipeMock: Identifiable {
    let id = UUID()
    let title: String
    let cuisine: String
    let difficulty: String
    let calories: String
}

#Preview {
    RecipeAIRecommendationView()
}
