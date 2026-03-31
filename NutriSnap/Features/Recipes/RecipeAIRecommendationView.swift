import SwiftUI

struct RecipeAIRecommendationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppStateManager.self) private var appStateManager
    
    @ObservedObject private var viewModel = RecipeAIRecommendationViewModel.shared
    
    @State private var promptText: String = ""
    
    // Form selections (initial state)
    @State private var cuisine = "Select"
    @State private var mealType = "Select"
    @State private var diet = "Select"
    @State private var allergen = "Select"
    @State private var mainIngredient = "Select"
    @State private var difficulty = ""
    
    // Theme Colors
    let appBackground = Color(red: 0.95, green: 0.98, blue: 0.93)
    let textDarkGreen = Color(red: 0.1, green: 0.3, blue: 0.2)
    let bubbleLightGreen = Color(red: 0.82, green: 0.93, blue: 0.82)
    
    // Original Banner Colors
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
        ZStack(alignment: .top) {
            appBackground.ignoresSafeArea()
            
            if viewModel.messages.isEmpty {
                // MARK: - Initial Form State
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        inputBannerView
                        
                        if let error = viewModel.errorMessage {
                            Text(error).font(.caption).foregroundColor(.red).frame(maxWidth: .infinity, alignment: .center)
                        }
                        
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
                        
                        // Big Search Button
                        Button(action: {
                            performInitialSearch()
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
                        
                        Spacer()
                    }
                    .padding()
                    .padding(.top, 80) // Scrolled under glass
                }
            } else {
                // MARK: - Chat UI State
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                ForEach(viewModel.messages, id: \.id) { message in
                                    if message.isUser {
                                        // User Bubble
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(message.text)
                                                .padding()
                                                .background(bubbleLightGreen)
                                                .foregroundColor(textDarkGreen)
                                                .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                                            
                                            Text("SENT \(formattedTime(message.timestamp))")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.gray)
                                                .padding(.trailing, 4)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .padding(.leading, 40)
                                        .id(message.id)
                                    } else {
                                        // AI Bubble
                                        HStack(alignment: .top, spacing: 12) {
                                            systemAvatarIcon
                                            
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("AI Recommendation")
                                                    .font(.subheadline).fontWeight(.bold).foregroundColor(textDarkGreen)
                                                
                                                VStack(alignment: .leading, spacing: 16) {
                                                    Text(message.text)
                                                        .foregroundColor(textDarkGreen)
                                                        .lineSpacing(4)
                                                    
                                                    if let recipes = message.recipes, !recipes.isEmpty {
                                                        VStack(spacing: 12) {
                                                            ForEach(recipes, id: \.id) { recipe in
                                                                NavigationLink(destination: RecipeDetailView(recipeId: recipe.id)) {
                                                                    RecipeCard(
                                                                        title: recipe.title,
                                                                        cuisine: recipe.cuisine?.name ?? "Unknown",
                                                                        difficulty: recipe.difficulty?.name ?? "Unknown",
                                                                        calories: extractCaloriesString(from: recipe)
                                                                    )
                                                                }
                                                                .buttonStyle(PlainButtonStyle())
                                                            }
                                                        }
                                                    }
                                                }
                                                .padding(16)
                                                .background(Color.white)
                                                .cornerRadius(20)
                                                .cornerRadius(4, corners: [.topLeft])
                                            }
                                            Spacer()
                                        }
                                        .padding(.trailing, 20)
                                        .id(message.id)
                                    }
                                }
                                
                                // Loading Indicator
                                if viewModel.isTyping {
                                    HStack(alignment: .top, spacing: 12) {
                                        systemAvatarIcon
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("AI Recommendation")
                                                .font(.subheadline).fontWeight(.bold).foregroundColor(textDarkGreen)
                                            
                                            HStack(spacing: 4) {
                                                Circle().fill(Color.gray).frame(width: 8, height: 8)
                                                Circle().fill(Color.gray.opacity(0.7)).frame(width: 8, height: 8)
                                                Circle().fill(Color.gray.opacity(0.4)).frame(width: 8, height: 8)
                                            }
                                            .padding()
                                            .background(Color.white)
                                            .cornerRadius(16, corners: [.topRight, .bottomLeft, .bottomRight])
                                        }
                                        Spacer()
                                    }
                                    .id("TypingBubble")
                                }
                            }
                            .padding()
                            .padding(.top, 80) // Scrolled under glass
                            .padding(.bottom, 20)
                        }
                        .onChange(of: viewModel.messages.count, perform: { _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                            }
                        })
                        .onChange(of: viewModel.isTyping, perform: { newValue in
                            if newValue {
                                withAnimation { proxy.scrollTo("TypingBubble", anchor: .bottom) }
                            } else if let lastId = viewModel.messages.last?.id {
                                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                            }
                        })
                    }
                    
                    chatBottomInputArea
                }
            }
            
            // Glass Navigation Header
            glassHeader
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Logic
    
    private var isSearchDisabled: Bool {
        return promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               cuisine == "Select" &&
               mealType == "Select" &&
               diet == "Select" &&
               allergen == "Select" &&
               mainIngredient == "Select" &&
               difficulty.isEmpty
    }
    
    private func performInitialSearch() {
        var queryStr = promptText
        var preferences: [String] = []
        
        if cuisine != "Select" { preferences.append("Cuisine is \(cuisine)") }
        if mealType != "Select" { preferences.append("Meal Type is \(mealType)") }
        if diet != "Select" { preferences.append("Diet is \(diet)") }
        if allergen != "Select" { preferences.append("Must exclude \(allergen)") }
        if mainIngredient != "Select" { preferences.append("Main Ingredient is \(mainIngredient)") }
        if !difficulty.isEmpty { preferences.append("Difficulty should be \(difficulty)") }
        
        if queryStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryStr = "Please find me a recipe."
        }
        if !preferences.isEmpty {
            queryStr += " (Preferences: " + preferences.joined(separator: ", ") + ")"
        }
        
        let finalQuery = queryStr
        promptText = ""
        
        Task {
            await viewModel.fetchRecommendation(
                query: finalQuery,
                currentUser: appStateManager.currentUser
            )
        }
    }
    
    private func performChatFollowup() {
        guard !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let finalQuery = promptText
        promptText = ""
        
        Task {
            await viewModel.fetchRecommendation(
                query: finalQuery,
                currentUser: appStateManager.currentUser
            )
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date).uppercased()
    }
    
    private func extractCaloriesString(from recipe: SupabaseRecipe) -> String {
        let caloriesNutrient = recipe.recipeNutrients?.first(where: {
            $0.nutrient.name.lowercased() == "calories"
        })
        return caloriesNutrient != nil ? String(format: "%.0f kcal", caloriesNutrient!.amount) : "N/A"
    }
    
    // MARK: - Views
    
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
                    .onSubmit { performInitialSearch() }
                
                Button(action: {
                    performInitialSearch()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(14)
                        .background(darkBlue)
                        .clipShape(Circle())
                }
                .disabled(isSearchDisabled)
                .opacity(isSearchDisabled ? 0.6 : 1.0)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blueBackground)
        .cornerRadius(16)
    }
    
    // Secondary Input View for Chat Screen (No quick action pills as requested)
    private var chatBottomInputArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.gray)
                    .font(.title3)
                
                TextField("Ask for an adjustment...", text: $promptText)
                    .foregroundColor(textDarkGreen)
                    .onSubmit { performChatFollowup() }
                
                Button(action: {
                    performChatFollowup()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(red: 0.5, green: 0.6, blue: 0.5)) // Dark greenish grey
                        .clipShape(Circle())
                }
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .padding(.top, 8)
        .background(appBackground)
    }
    
    private var glassHeader: some View {
        HStack {
            Button(action: {
                dismiss() // Always dismiss, preserving history!
            }) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).blendMode(.overlay))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("AI Recommendation")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if !viewModel.messages.isEmpty {
                // Feature to clear chat history and restart
                Button(action: {
                    withAnimation {
                        viewModel.clearHistory()
                        cuisine = "Select"
                        mealType = "Select"
                        diet = "Select"
                        allergen = "Select"
                        mainIngredient = "Select"
                        difficulty = ""
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).blendMode(.overlay))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            } else {
                Image(systemName: "chevron.left")
                    .padding(10)
                    .opacity(0)
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var systemAvatarIcon: some View {
        Image(systemName: "sparkles")
            .font(.body)
            .foregroundColor(.white)
            .padding(8)
            .background(Color(red: 0.35, green: 0.65, blue: 0.45))
            .clipShape(Circle())
    }
}

// MARK: - Components

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
    
    let activeGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
    let inactiveGreen = Color(red: 0.65, green: 0.9, blue: 0.8)
    
    var body: some View {
        Button(action: {
            selected = (selected == title) ? "" : title // Toggle
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


