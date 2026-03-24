import SwiftUI

struct RecipesView: View {
    @State private var viewModel = RecipesViewModel()
    @State private var showFilter = false
    @State private var showAIPage = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Hidden NavigationLink for AI Page
                NavigationLink(destination: RecipeAIRecommendationView(), isActive: $showAIPage) {
                    EmptyView()
                }
                .hidden()
                
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
                        if viewModel.totalCount > 0 {
                            Text("\(viewModel.recipes.count) of \(viewModel.totalCount) results")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        } else if !viewModel.isLoading {
                            Text("\(viewModel.recipes.count) results")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Recipe List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.recipes) { recipe in
                                // Find 'Calories' nutrient
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
                                .onAppear {
                                    // Trigger load more when the last item appears
                                    if recipe.id == viewModel.recipes.last?.id {
                                        Task { await viewModel.loadMoreRecipes() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Skeleton cards below the recipe list while loading
                        if viewModel.isLoading || viewModel.isLoadingMore {
                            LazyVStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RecipeSkeletonCard()
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    .background(Color(red: 0.95, green: 0.98, blue: 0.93)) // Light greenish-yellow background
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
            .overlay(alignment: .bottomTrailing) {
                // Real implementation of the AI Assistant Button floating at the bottom right
                Button(action: { showAIPage = true }) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.black)
                        .padding(16)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
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

// MARK: - Skeleton Card with Shimmer

struct RecipeSkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cuisine badge placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 22)
            
            // Title placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 18)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 200, height: 18)
            
            // Difficulty & Calories placeholder
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 70, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 14)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 70, height: 14)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            shimmerOverlay
                .cornerRadius(16)
        )
        .onAppear { isAnimating = true }
    }
    
    private var shimmerOverlay: some View {
        GeometryReader { geo in
            let width = geo.size.width
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.6)
                .offset(x: isAnimating ? width : -width * 0.6)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .clipped()
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let title: String
    let cuisine: String
    let difficulty: String
    let calories: String // New property
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cuisine Badge
            HStack(alignment: .top) {
                Text(cuisine.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.2)) // Match reference rusty orange
                    .cornerRadius(6)
            }
            
            // Recipe Title
            Text(title)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            
            // Difficulty and Calories
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DIFFICULTY")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.7, green: 0.4, blue: 0.2)) // Rust color for label
                    Text(difficulty.capitalized)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CALORIES")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.7, green: 0.4, blue: 0.2)) // Rust color for label
                    Text(calories)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
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
