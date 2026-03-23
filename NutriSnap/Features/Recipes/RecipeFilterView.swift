import SwiftUI

struct RecipeFilterView: View {
    @Bindable var viewModel: RecipesViewModel
    @Environment(\.dismiss) var dismiss
    
    // Aesthetic Colors for Glass Theme
    let brandGreenLabel = Color(red: 0.1, green: 0.8, blue: 0.5)
    let brandDarkGreen = Color(red: 0.1, green: 0.7, blue: 0.4)
    
    var body: some View {
        ZStack {
            // Base Liquid Glass Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag Indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 48, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // 1. Cuisine
                        filterDropdown(title: "Cuisine", selection: $viewModel.selectedCuisine, options: viewModel.cuisines)
                        
                        // 2. Meal Type
                        filterDropdown(title: "Meal Type", selection: $viewModel.selectedMealType, options: viewModel.mealTypes)
                        
                        // 3. Diet
                        filterDropdown(title: "Diet", selection: $viewModel.selectedDiet, options: viewModel.diets)
                        
                        // 4. Allergen
                        filterDropdown(title: "Allergen", selection: $viewModel.selectedAllergen, options: viewModel.allergens)
                        
                        // 5. Main Ingredient
                        filterDropdown(title: "Main Ingredient", selection: $viewModel.selectedIngredient, options: viewModel.mainIngredients)
                        
                        // 6. Difficulty Pills
                        HStack(spacing: 16) {
                            Spacer()
                            ForEach(viewModel.difficulties, id: \.self) { diff in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        if viewModel.selectedDifficulty == diff {
                                            viewModel.selectedDifficulty = nil // Deselect
                                        } else {
                                            viewModel.selectedDifficulty = diff
                                        }
                                    }
                                }) {
                                    Text(diff)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(viewModel.selectedDifficulty == diff ? .white : .primary)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            ZStack {
                                                if viewModel.selectedDifficulty == diff {
                                                    LinearGradient(colors: [brandDarkGreen, brandGreenLabel], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                } else {
                                                    Rectangle().fill(.ultraThinMaterial)
                                                }
                                            }
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                                .blendMode(.overlay)
                                        )
                                        .shadow(color: viewModel.selectedDifficulty == diff ? brandDarkGreen.opacity(0.3) : .black.opacity(0.05), radius: 8, x: 0, y: 4)
                                }
                            }
                            Spacer()
                        }
                        .padding(.top, 16)
                        
                        // 7. Action Buttons
                        HStack(spacing: 16) {
                            Button(action: {
                                withAnimation {
                                    viewModel.clearFilters()
                                }
                                // We don't necessarily fetch here so they can rebuild filter, but they might want immediate
                                Task { await viewModel.fetchRecipes() }
                            }) {
                                Text("Clear All")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                            .blendMode(.overlay)
                                    )
                            }
                            
                            Button(action: {
                                Task { await viewModel.fetchRecipes() }
                                dismiss()
                            }) {
                                Text("Done")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(colors: [brandDarkGreen, brandGreenLabel], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                            .blendMode(.overlay)
                                    )
                                    .shadow(color: brandDarkGreen.opacity(0.4), radius: 10, x: 0, y: 5)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // Custom Glass Dropdown Helper
    @ViewBuilder
    private func filterDropdown(title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        withAnimation {
                            selection.wrappedValue = option
                        }
                    }) {
                        Text(option)
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .foregroundColor(selection.wrappedValue == "Select" ? .secondary : .primary)
                        .fontWeight(selection.wrappedValue == "Select" ? .regular : .medium)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
    }
}
