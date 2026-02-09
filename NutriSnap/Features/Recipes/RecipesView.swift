import SwiftUI

struct RecipesView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    
    let filters = ["All", "Quick & Easy", "Vegetarian"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar and Filter Button
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search recipes", text: $searchText)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    Button(action: {}) {
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
                
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filters, id: \.self) { filter in
                            Button(action: { selectedFilter = filter }) {
                                Text(filter)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(selectedFilter == filter ? Color.green.opacity(0.3) : Color(.systemGray6))
                                    .foregroundColor(selectedFilter == filter ? .primary : .secondary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Results Count
                HStack {
                    Text("7594 results")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Recipe Grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        RecipeCard(
                            imageName: "spaghetti",
                            title: "Authentic Spaghetti",
                            difficulty: "Easy"
                        )
                        
                        RecipeCard(
                            imageName: "ramen",
                            title: "Saucy Ramen Noodles",
                            difficulty: "Easy"
                        )
                        
                        RecipeCard(
                            imageName: "steak",
                            title: "Bavette Steak & Roasted Garlic Pan Sauce",
                            difficulty: "Normal"
                        )
                        
                        RecipeCard(
                            imageName: "salad",
                            title: "Chickpea Feta Avocado Salad",
                            difficulty: "Easy"
                        )
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
    }
}

struct RecipeCard: View {
    let imageName: String
    let title: String
    let difficulty: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Image
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 140)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
            
            // Recipe Title
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // Difficulty
            Text(difficulty)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
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
