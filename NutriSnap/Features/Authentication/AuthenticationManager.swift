import SwiftUI
import GoogleSignIn
import Observation

/// Manages authentication state and Google Sign-In flow
@Observable
class AuthenticationManager {
    var isSignedIn: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var hasCompletedOnboarding: Bool = false
    
    // User info from Google
    var userName: String = ""
    var userEmail: String = ""
    var userProfileImageURL: URL?
    
    init() {
        // Restore onboarding state
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        // Check if user was previously signed in
        restorePreviousSignIn()
    }
    
    // MARK: - Restore Previous Sign-In
    
    /// Attempts to restore a previous Google Sign-In session
    func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                if let user = user, error == nil {
                    self?.updateUserInfo(from: user)
                    self?.isSignedIn = true
                } else {
                    self?.isSignedIn = false
                }
            }
        }
    }
    
    // MARK: - Sign In with Google
    
    /// Initiates the Google Sign-In flow
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to find root view controller."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    // Don't show error for user cancellation
                    if (error as NSError).code != GIDSignInError.canceled.rawValue {
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "Failed to get user information."
                    return
                }
                
                self?.updateUserInfo(from: user)
                self?.isSignedIn = true
            }
        }
    }
    
    // MARK: - Sign Out
    
    /// Signs the user out
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        hasCompletedOnboarding = false
        userName = ""
        userEmail = ""
        userProfileImageURL = nil
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Private Helpers
    
    private func updateUserInfo(from user: GIDGoogleUser) {
        userName = user.profile?.name ?? "User"
        userEmail = user.profile?.email ?? ""
        userProfileImageURL = user.profile?.imageURL(withDimension: 200)
    }
}
