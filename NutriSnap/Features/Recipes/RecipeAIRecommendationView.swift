import SwiftUI

struct RecipeAIRecommendationView: View {
    @Environment(\.dismiss) var dismiss
    
    enum ScreenState {
        case input
        case loading
        case result
    }
    
    @State private var viewState: ScreenState = .input
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
    
    // Mock results
    let mockResults: [RecipeMock] = [
        RecipeMock(title: "Authentic Spaghetti", cuisine: "Italian", difficulty: "Easy", calories: "450 kcal"),
        RecipeMock(title: "Saucy Ramen Noodles", cuisine: "Japanese", difficulty: "Easy", calories: "520 kcal")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    if viewState == .result {
                        withAnimation { viewState = .input }
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
            
            if viewState == .loading {
                loadingView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Top Blue Banner
                        if viewState == .input {
                            inputBannerView
                        } else if viewState == .result {
                            resultBannerView
                        }
                        
                        if viewState == .input {
                            // Find by Preference Section
                            Text("Find by Preference")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                            
                            VStack(spacing: 16) {
                                FormDropdown(label: "Cuisine", selection: $cuisine)
                                FormDropdown(label: "Meal Type", selection: $mealType)
                                FormDropdown(label: "Diet", selection: $diet)
                                FormDropdown(label: "Allergen", selection: $allergen)
                                FormDropdown(label: "Main Ingredient", selection: $mainIngredient)
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
                                withAnimation {
                                    viewState = .loading
                                }
                                // Simulate network request
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        viewState = .result
                                    }
                                }
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
                            
                        } else if viewState == .result {
                            // Recipes Recommended Section
                            Text("Recipes Recommended")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.top, 8)
                            
                            VStack(spacing: 12) {
                                ForEach(mockResults) { recipe in
                                    RecipeCard(title: recipe.title, cuisine: recipe.cuisine, difficulty: recipe.difficulty, calories: recipe.calories)
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
            
            TextField("E.g. I want a high protein fine dining", text: $promptText)
                .padding()
                .background(darkBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
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
                
                Text("You're looking for a hearty dinner, and we've found some delicious options for you! We noticed you're a bit low on protein, carbs, and fiber today, and these selections are a great way to help you deliciously catch up on those nutrients.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineSpacing(4)
            }
            
            Button(action: {
                withAnimation { viewState = .input }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Menu {
                Button("Option 1", action: { selection = "Option 1" })
                Button("Option 2", action: { selection = "Option 2" })
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
