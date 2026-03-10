import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext

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
                            PreferenceRow(icon: "fork.knife", title: "Cuisine",
                                         subtitle: "Chinese, Japanese", iconColor: .pink)
                            Divider().padding(.leading, 80)
                            PreferenceRow(icon: "takeoutbag.and.cup.and.straw", title: "Meal Type",
                                         subtitle: "Breakfast, Dinner, Snack", iconColor: .pink)
                            Divider().padding(.leading, 80)
                            PreferenceRow(icon: "leaf", title: "Diet",
                                         subtitle: "Vegan", iconColor: .pink)
                            Divider().padding(.leading, 80)

                            let allergenText = appStateManager.currentUser?.allergens.joined(separator: ", ") ?? "None"
                            PreferenceRow(icon: "exclamationmark.triangle", title: "Allergens",
                                         subtitle: allergenText.isEmpty ? "None" : allergenText, iconColor: .pink)
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
