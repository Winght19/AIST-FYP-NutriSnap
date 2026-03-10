import SwiftUI
import SwiftData

struct LandingView: View {
    @Environment(AppStateManager.self) private var appStateManager
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.72, green: 0.88, blue: 0.72),
                        Color(red: 0.82, green: 0.93, blue: 0.82),
                        Color(red: 0.90, green: 0.96, blue: 0.90)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.08)

                    // Logo
                    VStack(spacing: 8) {
                        Image("nutrisnap_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)

                        Text("NutriSnap")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }

                    Spacer()
                        .frame(height: geometry.size.height * 0.06)

                    // Title
                    VStack(spacing: 16) {
                        Text("Your Personal\nNutritionist")
                            .font(.system(size: 34, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)

                        Text("Your pocket expert for safe,\npersonalized eating")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Sign In Button
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await appStateManager.handleGoogleSignIn(modelContext: modelContext)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if appStateManager.authManager.isLoading {
                                    ProgressView().tint(.primary)
                                } else {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.primary)
                                }
                                Text("Sign In with Google")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.78, blue: 0.55),
                                        Color(red: 0.55, green: 0.82, blue: 0.60)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(appStateManager.authManager.isLoading)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                        .frame(height: geometry.size.height * 0.06)

                    // Error message
                    if case .error(let message) = appStateManager.appState {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
}

#Preview {
    LandingView()
        .environment(AppStateManager())
}
