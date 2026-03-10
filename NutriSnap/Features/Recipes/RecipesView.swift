import SwiftUI

struct RecipesView: View {
    @State private var viewModel = RecipesViewModel()
    @State private var showFilter = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar and Filter Button
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search recipes", text: $viewModel.searchText)
                            .onSubmit {
                                Task { await viewModel.fetchRecipes() }
                            }
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    Button(action: { showFilter = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Results Count
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text("\(viewModel.recipes.count) results")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Recipe Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipeId: recipe.id)) {
                                RecipeCard(
                                    title: recipe.title,
                                    cuisine: recipe.cuisine?.name ?? "Unknown",
                                    difficulty: recipe.difficulty?.name ?? "Unknown"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            RecipeFilterView(viewModel: viewModel)
                .presentationDetents([.fraction(0.85)]) // Makes it a large bottom sheet
                .presentationBackground(.clear)
        }
        .task {
            await viewModel.fetchRecipes()
        }
    }
}

struct RecipeCard: View {
    let title: String
    let cuisine: String
    let difficulty: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 44, alignment: .topLeading)
            
            // Cuisine & Difficulty
            HStack {
                Text(cuisine.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(difficulty)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// AI Assistant Button
struct AIAssistantButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.primary)
                .padding(16)
                .background(Color(.systemGray5))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

#Preview {
    RecipesView()
}
