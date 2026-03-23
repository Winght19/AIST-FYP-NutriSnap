import SwiftUI

struct RecipeDetailView: View {
    @Environment(AppStateManager.self) private var appStateManager
    let recipeId: Int
    @State private var viewModel = RecipeDetailViewModel()
    
    // Tab Selection State
    enum DetailTab: String, CaseIterable {
        case ingredients = "Ingredients"
        case steps = "Steps"
        case nutrition = "Nutrition"
    }
    @State private var selectedTab: DetailTab = .ingredients
    
    // Aesthetic Colors
    let brandPink = Color(red: 1.0, green: 0.4, blue: 0.5) // Approximate pink from the UI
    let brandGrayBG = Color(white: 0.95)
    let brandPillGray = Color(white: 0.9)
    let brandTextGray = Color(white: 0.4)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading {
                    ProgressView("Loading details...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let recipe = viewModel.recipe {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. Title & Badges
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recipe.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // 1. Difficulty Row
                            if let difficulty = recipe.difficulty?.name {
                                Text(difficulty.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(brandPillGray)
                                    .clipShape(Capsule())
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            
                            // 2. Allergens Row
                            if let allergens = recipe.recipeAllergens, !allergens.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(allergens, id: \.self) { allergen in
                                            let dbName = allergen.allergen.name
                                            let displayName = dbName.replacingOccurrences(of: "_allergen", with: "").capitalized
                                            let isUserAllergic = appStateManager.currentUser?.allergens.contains(displayName) ?? false
                                            
                                            HStack(spacing: 4) {
                                                if isUserAllergic {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                }
                                                Text(displayName)
                                                    .fontWeight(.semibold)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.red.opacity(0.15))
                                            .clipShape(Capsule())
                                            .fixedSize(horizontal: true, vertical: false)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 3. Dietary Tags Row
                        if let tags = recipe.recipeDietaryTags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { dietaryTag in
                                        Text(dietaryTag.tag.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(brandPillGray)
                                            .clipShape(Capsule())
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                }
                            }
                        }
                        
                        // 4. Calories Quick Badge
                        if let calories = recipe.recipeNutrients?.first(where: { $0.nutrient.name == "Calories" }) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                Text("\(Int(calories.amount)) kcal")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(brandPink)
                            .clipShape(Capsule())
                        }
                        
                        // 5. Custom Tab Picker
                        HStack {
                            ForEach(DetailTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    withAnimation {
                                        selectedTab = tab
                                    }
                                }) {
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedTab == tab ? .primary : brandTextGray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedTab == tab ? Color.white : Color.clear)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(4)
                        .background(brandGrayBG)
                        .cornerRadius(24)
                        .padding(.top, 8)
                        
                        // 6. Content Card (Pink Border)
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedTab {
                            case .ingredients:
                                ingredientsView(recipe: recipe)
                            case .steps:
                                stepsView(recipe: recipe)
                            case .nutrition:
                                nutritionView(recipe: recipe)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        // The UI mockup has a rounded rectangle pink border inside
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(brandPink.opacity(0.4), lineWidth: 1.5)
                        )
                        .padding(.top, 8)
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    Spacer(minLength: 120) // Leave room for bottom navigation bar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton()
            }
        }
        .task {
            await viewModel.fetchRecipeDetail(id: recipeId)
        }
    }
    
    // MARK: - Tab Content Views
    
    @ViewBuilder
    private func ingredientsView(recipe: SupabaseRecipe) -> some View {
        if let ingredients = recipe.rawIngredients, !ingredients.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ingredients, id: \.self) { ing in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .fontWeight(.bold)
                        Text(ing.ingredientText)
                            .font(.subheadline)
                    }
                    .foregroundColor(Color(white: 0.2))
                }
            }
        } else {
            Text("No ingredients found.")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func stepsView(recipe: SupabaseRecipe) -> some View {
        if let directions = recipe.parsedDirections, !directions.isEmpty {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(directions.enumerated()), id: \.element) { index, direction in
                    HStack(alignment: .top, spacing: 16) {
                        // Number Circle
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(brandPink)
                            .frame(width: 28, height: 28)
                            .background(brandPink.opacity(0.15))
                            .clipShape(Circle())
                        
                        // Step Text
                        Text(direction.stepText)
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.2))
                    }
                }
            }
        } else {
            Text("No instructions found.")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func nutritionView(recipe: SupabaseRecipe) -> some View {
        if let nutrients = recipe.recipeNutrients, !nutrients.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                
                let order = ["Calories", "Protein", "Carbohydrate, by difference", "Fiber", "Sugar", "Total lipid (fat)", "Fatty acids, total saturated"]
                
                let sortedNutrients = nutrients.sorted { a, b in
                    let indexA = order.firstIndex(of: a.nutrient.name) ?? 99
                    let indexB = order.firstIndex(of: b.nutrient.name) ?? 99
                    return indexA < indexB
                }
                
                ForEach(Array(sortedNutrients.enumerated()), id: \.element) { index, item in
                    HStack {
                        Text(formatNutrientName(item.nutrient.name))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color(white: 0.2))
                        
                        Spacer()
                        
                        Text(String(format: "%.1f%@", item.amount, item.nutrient.unit.lowercased()))
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.2))
                    }
                    .padding(.vertical, 16)
                    
                    if index < sortedNutrients.count - 1 {
                        Divider()
                    }
                }
            }
        } else {
            Text("No nutrition info found.")
                .foregroundColor(.secondary)
        }
    }
    
    // Clean up USDA nutrient names for the UI
    private func formatNutrientName(_ name: String) -> String {
        switch name {
        case "Carbohydrate, by difference": return "Carbohydrates"
        case "Total lipid (fat)": return "Fat"
        case "Fatty acids, total saturated": return "Saturated Fat"
        default: return name
        }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "chevron.left")
                .font(.headline)
                .foregroundColor(.black)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.8)))
        }
    }
}
