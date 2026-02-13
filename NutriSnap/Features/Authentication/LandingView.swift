import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct LandingView: View {
    @Environment(AuthenticationManager.self) var authManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient matching the screenshot
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.72, green: 0.88, blue: 0.72),  // Soft green top
                        Color(red: 0.82, green: 0.93, blue: 0.82),  // Lighter green middle
                        Color(red: 0.90, green: 0.96, blue: 0.90)   // Very light green bottom
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.08)
                    
                    // MARK: - Logo Section
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
                    
                    // MARK: - Title Section
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
                    
                    // MARK: - Buttons Section
                    VStack(spacing: 16) {
                        // Get Started Button (Google Sign-In)
                        /*Button(action: {
                            authManager.signInWithGoogle()
                        }) {
                            HStack(spacing: 12) {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title3)
                                }
                                Text("Get Started")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
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
                        .disabled(authManager.isLoading) */
                        
                        // Sign In with Google Button
                        Button(action: {
                            authManager.signInWithGoogle()
                        }) {
                            HStack(spacing: 12) {
                                // Google "G" logo
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                                
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
                        .disabled(authManager.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                        .frame(height: geometry.size.height * 0.06)
                    
                    // Error message
                    if let error = authManager.errorMessage {
                        Text(error)
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
        .environment(AuthenticationManager())
}
