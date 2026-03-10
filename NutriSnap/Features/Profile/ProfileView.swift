import SwiftUI
import SwiftData

enum ProfileEditType: Identifiable {
    case cuisine, mealType, diet, allergens
    var id: Int { hashValue }
}

struct ProfileView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var activeSheet: ProfileEditType? = nil
    
    // Shared ViewModel just for its static filter arrays
    @State private var recipesViewModel = RecipesViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 12) {
                        if let imageURL = appStateManager.authManager.userProfileImageURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image("profile_otter").resizable().scaledToFill()
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        } else {
                            Image("profile_otter")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        }

                        HStack(spacing: 8) {
                            Text(appStateManager.currentUser?.name ?? appStateManager.authManager.userName)
                                .font(.title)
                                .fontWeight(.bold)
                            Button(action: {}) {
                                Image(systemName: "pencil")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                        }

                        let email = appStateManager.currentUser?.email ?? appStateManager.authManager.userEmail
                        if !email.isEmpty {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text("Premium Member")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 20)

                    // Dietary Preferences
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Dietary Preferences")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.bottom, 16)

                        VStack(spacing: 0) {
                            Button(action: { activeSheet = .cuisine }) {
                                let cText = appStateManager.currentUser?.preferredCuisines.joined(separator: ", ") ?? ""
                                PreferenceRow(icon: "fork.knife", title: "Cuisine",
                                             subtitle: cText.isEmpty ? "None" : cText, iconColor: .pink)
                            }
                            
                            Divider().padding(.leading, 80)
                            
                            Button(action: { activeSheet = .mealType }) {
                                let mText = appStateManager.currentUser?.preferredMealTypes.joined(separator: ", ") ?? ""
                                PreferenceRow(icon: "takeoutbag.and.cup.and.straw", title: "Meal Type",
                                             subtitle: mText.isEmpty ? "None" : mText, iconColor: .pink)
                            }
                            
                            Divider().padding(.leading, 80)
                            
                            Button(action: { activeSheet = .diet }) {
                                let dText = appStateManager.currentUser?.preferredDiets.joined(separator: ", ") ?? ""
                                PreferenceRow(icon: "leaf", title: "Diet",
                                             subtitle: dText.isEmpty ? "None" : dText, iconColor: .pink)
                            }
                            
                            Divider().padding(.leading, 80)

                            Button(action: { activeSheet = .allergens }) {
                                let aText = appStateManager.currentUser?.allergens.joined(separator: ", ") ?? ""
                                PreferenceRow(icon: "exclamationmark.triangle", title: "Allergens",
                                             subtitle: aText.isEmpty ? "None" : aText, iconColor: .pink)
                            }
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                    }

                    // Sign Out
                    Button {
                        appStateManager.signOut(modelContext: modelContext)
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right").font(.body)
                            Text("Sign Out").font(.body).fontWeight(.medium)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            if let user = appStateManager.currentUser {
                switch sheetType {
                case .cuisine:
                    let binding = Binding(
                        get: { user.preferredCuisines },
                        set: { user.preferredCuisines = $0 }
                    )
                    DietaryPreferenceEditView(title: "Cuisine", options: recipesViewModel.cuisines, selectedOptions: binding) {
                        saveProfile(user: user)
                    }
                    
                case .mealType:
                    let binding = Binding(
                        get: { user.preferredMealTypes },
                        set: { user.preferredMealTypes = $0 }
                    )
                    DietaryPreferenceEditView(title: "Meal Type", options: recipesViewModel.mealTypes, selectedOptions: binding) {
                        saveProfile(user: user)
                    }
                    
                case .diet:
                    let binding = Binding(
                        get: { user.preferredDiets },
                        set: { user.preferredDiets = $0 }
                    )
                    DietaryPreferenceEditView(title: "Diet", options: recipesViewModel.diets, selectedOptions: binding) {
                        saveProfile(user: user)
                    }
                    
                case .allergens:
                    let binding = Binding(
                        get: { user.allergens },
                        set: { user.allergens = $0 }
                    )
                    DietaryPreferenceEditView(title: "Allergens", options: recipesViewModel.allergens, selectedOptions: binding) {
                        saveProfile(user: user)
                    }
                }
            }
        }
    }
    
    private func saveProfile(user: User) {
        guard let token = KeychainManager.shared.retrieveToken() else { return }
        
        let dto = OnboardingProfileDTO(
            dateOfBirth: user.dateOfBirth ?? Date(),
            weightKg: user.weight ?? 70,
            heightCm: user.height ?? 170,
            gender: user.gender ?? "Other",
            primaryGoal: user.primaryGoal ?? "Maintain Weight",
            exerciseHoursPerWeek: user.exerciseHoursPerWeek ?? 3,
            allergens: user.allergens,
            preferredCuisines: user.preferredCuisines,
            preferredMealTypes: user.preferredMealTypes,
            preferredDiets: user.preferredDiets
        )
        
        Task {
            do {
                _ = try await UserProfileService().updateProfile(dto, token: token)
                print("Profile preferences saved successfully")
            } catch {
                print("Failed to save profile preferences: \(error)")
            }
        }
    }
}

struct PreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
                .padding(12)
                .background(iconColor.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body).fontWeight(.semibold)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environment(AppStateManager())
}
